---
name: security-crypto-patterns
description: >
  在 .NET 应用中使用 NewLife.Core 的安全扩展 SecurityHelper 实现哈希（MD5/SHA/CRC/Murmur128）、
  对称加密（AES/DES/3DES/RC4）、非对称加密与签名（RSA）以及 JWT 令牌构建。
  适用于密码哈希、数据完整性校验、内容加密传输、API 签名验证与代码安全审查任务。
argument-hint: >
  说明你的安全场景：密码存储哈希（SHA256+盐）、数据完整性校验（CRC/MD5）、
  内容加密传输（AES）、证书签名验证（RSA）、还是 API 鉴权（JWT）。
  若涉及跨语言对接，请说明对端技术栈（如 Java 默认 ECB，需要特别注意 CBC/ECB 对齐）。
---

# 安全加密模式技能

## 适用场景

- 密码存储：将用户密码哈希（SHA256 + 随机盐）后存库，禁止明文存储。
- 数据完整性：计算文件或消息的 MD5/CRC32，校验传输完整性。
- 内容加密：用 AES 加密敏感配置（数据库密码、密钥等），静态存储或传输。
- API 签名：HMAC-SHA256 对请求参数签名，防篡改。
- 跨语言互通：与 Java 服务对接时，注意 AES 默认 CBC vs ECB 差异。
- 非对称加密：RSA 公钥加密 + 私钥解密；私钥签名 + 公钥验签。
- 代码审查：识别弱哈希（MD5/SHA1 单独做密码哈希）、不安全的加密模式（ECB）。

## 核心原则

1. **密码哈希必须加盐**：裸 MD5/SHA1 容易被彩虹表攻击；密码存储应使用 SHA256 + 随机盐，或使用 BCrypt/Argon2（更推荐）。
2. **对称加密选 AES-CBC**：DES/3DES 已不安全（密钥太短）；AES-CBC 是当前最实用的对称加密标准；ECB 模式存在模式泄露，仅用于与旧系统对接。
3. **哈希与加密用途区分**：MD5/SHA/CRC 是单向哈希，无法逆向解密，用于完整性校验；AES/RSA 是可逆加密，用于机密性保护。
4. **RC4 已不推荐**：RC4 存在已知弱点，不应用于新系统；若遗留系统必须兼容，则只用于非安全关键路径。
5. **`pass` 参数自动填充**：`Encrypt(data, pass)` 中的 `pass` 会被自动截断/填充到算法所需的密钥长度（AES 需 16/24/32 字节）；跨系统对接时确认两端使用相同填充方式。

## OWASP 安全提醒

- **A02 加密失败**：不要用 MD5/SHA1 作为密码哈希；不要用 ECB 模式加密结构化数据；密钥不要硬编码在源码中。
- **A03 注入**：加密/哈希结果不要直接拼接到 SQL；Base64/Hex 编码结果也需注意长度限制。

## 执行步骤

### 一、哈希：完整性校验与密码存储

```csharp
using NewLife;    // SecurityHelper 扩展方法所在命名空间
using NewLife.Security;  // RSAHelper

// MD5（适合文件完整性，不适合密码）
string md5Hex = "content".MD5();           // 32位十六进制字符串
string md5_16 = "content".MD5_16();        // 16位（取中间8字节）
byte[] fileHash = new FileInfo("f.zip").MD5();

// SHA256（推荐用于 API 签名和数据完整性）
byte[] hash256 = data.SHA256();

// HMAC-SHA256（API 签名：带密钥的哈希，防伪造）
byte[] key    = Encoding.UTF8.GetBytes("my-secret");
string hmacHex = data.SHA256(key).ToHex();

// CRC（协议校验，非安全场景）
uint crc32  = data.Crc();     // 32位
ushort crc16 = data.Crc16();  // 16位

// Murmur128（哈希表/布隆过滤器，速度> MD5，非加密用途）
byte[] murmur = data.Murmur128(seed: 0);
```

### 二、对称加密 AES

```csharp
var data = Encoding.UTF8.GetBytes("敏感数据");
var key  = Encoding.UTF8.GetBytes("my-16byte-keyXXX");  // 16/24/32 字节

// AES CBC（推荐，.NET 默认）
var encrypted = Aes.Create().Encrypt(data, key);
var decrypted = Aes.Create().Decrypt(encrypted, key);
Console.WriteLine(Encoding.UTF8.GetString(decrypted));  // → "敏感数据"

// AES ECB（只在对接 Java 默认模式时使用）
var encEcb = Aes.Create().Encrypt(data, key, CipherMode.ECB);
var decEcb = Aes.Create().Decrypt(encEcb, key, CipherMode.ECB);

// 大文件/流式加密
using var input  = File.OpenRead("large.bin");
using var output = File.Create("large.enc");
var aes = Aes.Create();
aes.Key = key;
aes.IV  = iv;             // 需提前生成随机 IV 并在密文前携带
aes.Encrypt(input, output);
```

### 三、RSA 非对称加密与签名

```csharp
using NewLife.Security;

// 生成密钥对（应用启动时一次性生成，私钥安全保存）
var (publicKey, privateKey) = RSAHelper.GenerateKey(2048);

// 加密（用接收方公钥加密，只有私钥持有者能解密）
var encrypted = RSAHelper.Encrypt(data, publicKey);
var decrypted = RSAHelper.Decrypt(encrypted, privateKey);

// 数字签名（用私钥签名，公钥验证）
var signature = RSAHelper.Sign(data, privateKey, "SHA256");
bool isValid  = RSAHelper.Verify(data, signature, publicKey, "SHA256");
```

### 四、JWT 令牌（JwtBuilder）

```csharp
using NewLife.Web;

// ——— 签发 ———
var issuer = new JwtBuilder
{
    Secret  = configuration["Jwt:Secret"],   // 至少 32 字节，从配置读取
    Expire  = DateTime.Now.AddHours(24),     // 过期时间（exp 声明）
    Subject = user.Id.ToString(),             // 主体（sub 声明，通常是用户ID）
    Issuer  = "MyApp",                        // 签发方（iss 声明）
};

// 附加自定义声明
issuer["role"] = user.Role;
issuer["name"] = user.Name;

var token = issuer.Encode(new { });           // payload 中的额外属性可在此传入
```

```csharp
// ——— 验证 ———
var verifier = new JwtBuilder
{
    Secret = configuration["Jwt:Secret"],
};

if (verifier.TryDecode(token, out var message))
{
    var userId = verifier.Subject;                // "sub" 声明
    var role   = (string?)verifier["role"];       // 自定义声明
    var expire = verifier.Expire;                 // "exp" 声明
}
else
{
    // message: "JWT格式不正确" / "令牌已过期" / "令牌未生效" / "未设置密钥"
    return Unauthorized(message);
}
```

```csharp
// ——— 不验证签名，仅解析结构（用于获取算法等元数据）———
var parts = new JwtBuilder().Parse(token);   // 返回 [header, payload, signature]
if (parts != null)
{
    var builder2 = new JwtBuilder { Secret = GetSecretByAlgorithm(builder2.Algorithm) };
    builder2.TryDecode(token, out _);
}
```

#### RS256（RSA 非对称签发）

```csharp
// 服务端用私钥签发
var issuer = new JwtBuilder
{
    Algorithm = "RS256",
    Secret    = rsaPrivateKeyPem,     // PEM 格式私钥
    Subject   = userId,
    Expire    = DateTime.Now.AddHours(1),
};
var token = issuer.Encode(new { });

// 客户端/验签方用公钥验证（不需要私钥）
var verifier = new JwtBuilder
{
    Algorithm = "RS256",
    Secret    = rsaPublicKeyPem,      // PEM 格式公钥
};
verifier.TryDecode(token, out _);
```

#### 算法选型速查

| 算法 | 类型 | 密钥要求 | 适用场景 |
|------|------|---------|---------|
| `HS256` | HMAC | 对称密钥（≥32字节）| 单服务/内部 API，**默认推荐** |
| `HS384/512` | HMAC | 对称密钥 | 更高哈希强度 |
| `RS256` | RSA | 公/私钥对 | 多服务/公开验签，公钥可公开分发 |
| `RS384/512` | RSA | 公/私钥对 | 更高哈希强度 |

### 五、ICryptoTransform 直接转换

```csharp
// 当需要复用 AES 实例，避免反复创建
var aes = Aes.Create();
aes.Key = key;
aes.IV  = iv;

using var enc = aes.CreateEncryptor();
byte[] result = enc.Transform(plaintext);

using var dec = aes.CreateDecryptor();
byte[] plain  = dec.Transform(result);
```

### 五、模式选择总结

| 需求 | 推荐方案 | 说明 |
|------|---------|------|
| 文件完整性 | `MD5().ToHex()` | 快速，非安全用途 |
| 密码存储 | SHA256 + 盐（或 BCrypt）| 单纯 MD5/SHA1 不安全 |
| API 签名 | HMAC-SHA256（`SHA256(key)`）| 双方共享密钥 |
| 数据加密传输 | AES-CBC | .NET 默认，推荐 |
| Java 对接 | AES-ECB | 需两端协商一致 |
| 公开加密私解密 | RSA 2048 | 适合密钥协商/小数据 |
| 签名验证 | RSA Sign/Verify | 防伪造，公钥公开 |
| 单服务 JWT | `JwtBuilder`（HS256）| 对称密钥，内部 API |
| 多服务 JWT 验签 | `JwtBuilder`（RS256）| 公钥可公开分发 |

## 重点检查项

- [ ] 密码是否使用裸 MD5/SHA1 哈希（应加盐或用 BCrypt/Argon2）？
- [ ] AES 密钥是否硬编码在源码中（应从配置中心/环境变量读取）？
- [ ] AES 初始化向量（IV）是否与每次加密独立生成并一起存储/传输（相同 IV 重复使用会泄露信息）？
- [ ] 与 Java 对接时，加/解密模式（CBC vs ECB）和 padding（PKCS7/PKCS5）是否两端一致？
- [ ] RSA 私钥是否妥善保护（不能出现在日志/错误消息/版本控制中）？
- [ ] JWT `Secret` 是否从配置中心/环境变量读取（不能硬编码），长度是否满足算法要求（HS256 至少 32 字节）？
- [ ] JWT `Expire` 是否设置了合理的过期时间（不要过长；也不要使用 `DateTime.MaxValue`）？
- [ ] RS256 验签时是否使用了公钥（不是私钥），私钥仅在签发服务保存？
- [ ] 是否在使用已知不安全的 RC4 或 DES？

## 输出要求

- **哈希**：`SecurityHelper` 扩展方法（`MD5`/`SHA256`/`Crc`/`Murmur128`），位于 `NewLife` 命名空间。
- **对称加密**：`SymmetricAlgorithm` 扩展方法（`Encrypt`/`Decrypt`/`Transform`），同命名空间。
- **非对称加密**：`RSAHelper` 静态类，位于 `NewLife.Security` 命名空间。
- **JWT**：`JwtBuilder`（`NewLife.Web`）—— `Encode(payload)`/`TryDecode(token, out msg)`/`Parse(token)`；支持 HS256/RS256；自定义声明通过索引器 `builder["key"] = value` 设置。

## 参考资料

参考示例与模式证据见 `references/newlife-security-patterns.md`。
