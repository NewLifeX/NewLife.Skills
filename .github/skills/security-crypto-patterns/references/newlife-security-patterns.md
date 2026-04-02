# NewLife.Core 安全加密模式证据

> 来源：`Doc/安全扩展SecurityHelper.md`（GBK，代码片段可读）
> 核心 API 从文档代码块中恢复，以下内容与源码一致。

---

## 1. 哈希 API（从文档代码块恢复）

```csharp
// MD5
Byte[] MD5(this Byte[] data)
String MD5(this String data, Encoding? encoding = null)  // → 32位十六进制
String MD5_16(this String data, Encoding? encoding = null) // → 16位（中8字节）
Byte[] MD5(this FileInfo file)

// SHA 族（带 key 参数时为 HMAC，不传或 null 为普通哈希）
Byte[] SHA1(this Byte[] data, Byte[]? key)
Byte[] SHA256(this Byte[] data, Byte[]? key = null)
Byte[] SHA384(this Byte[] data, Byte[]? key)
Byte[] SHA512(this Byte[] data, Byte[]? key)

// CRC
UInt32 Crc(this Byte[] data)
UInt16 Crc16(this Byte[] data)

// Murmur128（非加密，适合哈希表）
Byte[] Murmur128(this Byte[] data, UInt32 seed = 0)
```

**命名空间**：`using NewLife;`（扩展方法全部在此命名空间）

---

## 2. 对称加密 API（从文档代码块恢复）

```csharp
// 内存版（pass 自动填充到算法所需密钥长度）
Byte[] Encrypt(this SymmetricAlgorithm sa, Byte[] data,
    Byte[]? pass = null,
    CipherMode mode = CipherMode.CBC,
    PaddingMode padding = PaddingMode.PKCS7)

Byte[] Decrypt(this SymmetricAlgorithm sa, Byte[] data,
    Byte[]? pass = null,
    CipherMode mode = CipherMode.CBC,
    PaddingMode padding = PaddingMode.PKCS7)

// 流式版（大文件）
SymmetricAlgorithm Encrypt(this SymmetricAlgorithm sa, Stream instream, Stream outstream)
SymmetricAlgorithm Decrypt(this SymmetricAlgorithm sa, Stream instream, Stream outstream)

// 直接转换（低层）
Byte[] Transform(this ICryptoTransform transform, Byte[] data)
```

---

## 3. 跨语言对接注意（文档说明）

> `.NET 默认 CBC 模式；Java 默认 ECB 模式`——跨语言对接时需两端协商对齐。
> `PaddingMode.PKCS7` 等同于 Java 的 `PKCS5Padding`。

---

## 4. RC4 API（文档完整恢复）

```csharp
Byte[] RC4(this Byte[] data, Byte[] pass)
// 加密和解密使用相同函数（对称流加密）
```

> RC4 存在已知密码分析漏洞，不应用于新系统安全需求。

---

## 5. RSA API（`NewLife.Security` 命名空间）

```csharp
using NewLife.Security;

// 生成 RSA 密钥对
(String publicKey, String privateKey) = RSAHelper.GenerateKey(2048);

// 使用公钥加密
Byte[] RSAHelper.Encrypt(Byte[] data, String publicKey)

// 使用私钥解密
Byte[] RSAHelper.Decrypt(Byte[] data, String privateKey)

// 私钥签名
Byte[] RSAHelper.Sign(Byte[] data, String privateKey, String algorithm = "SHA256")

// 公钥验签
Boolean RSAHelper.Verify(Byte[] data, Byte[] signature, String publicKey, String algorithm = "SHA256")
```

---

## 6. 安全强度对比

| 算法 | 类别 | 当前安全评级 | 推荐用途 |
|------|------|------------|---------|
| MD5 | 哈希 | ⚠️ 弱（密码场景）| 文件校验（非密码）|
| SHA1 | 哈希 | ⚠️ 弱（密码场景）| 遗留校验 |
| SHA256 | 哈希 | ✅ 安全 | 完整性/HMAC/API签名 |
| SHA512 | 哈希 | ✅ 安全 | 高安全需求 |
| CRC32 | 校验 | ⚠️ 非加密 | 协议完整性 |
| Murmur128 | 哈希 | ⚠️ 非加密 | 哈希表/布隆过滤器 |
| DES | 对称 | ❌ 不安全 | 禁止新场景 |
| 3DES | 对称 | ⚠️ 弱 | 仅旧系统兼容 |
| AES-CBC | 对称 | ✅ 安全 | 推荐标准 |
| AES-ECB | 对称 | ⚠️ 模式弱 | 仅跨语言兼容 |
| RC4 | 对称流 | ❌ 不安全 | 禁止新场景 |
| RSA 2048 | 非对称 | ✅ 安全 | 密钥协商/签名 |

---

## 7. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| MD5/CRC 完整性校验 | ✅ 通用 | 普遍规律 |
| HMAC-SHA256 API 签名 | ✅ 通用 | 行业标准 |
| AES-CBC 推荐 | ✅ 通用 | 普遍安全建议 |
| `pass` 自动填充密钥长度 | ⚠️ NewLife 特有 | 通用实现需手动 Pad |
| 扩展方法形式 (`data.MD5()`) | ⚠️ NewLife 特有 | 通用替代：`MD5.HashData(data)` |
| `RSAHelper` 封装 | ⚠️ NewLife 特有 | 封装 `RSACryptoServiceProvider` |
