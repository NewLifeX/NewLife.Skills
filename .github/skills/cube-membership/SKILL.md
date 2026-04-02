---
name: cube-membership
description: >
  使用 NewLife.Cube 的用户认证与权限管理体系，涵盖 ManageProvider 用户上下文管理、
  UserService 登录/注册/验证码（密码/短信/邮件三模式）、PasswordService 密码强度验证、
  TokenService JWT 颁发与验证（HS256/RS256 算法格式）、AccessService 访问日志，
  以及 User/Role/UserToken/UserOnline/UserConnect 核心实体操作。
  适用于用户登录、注册、密码策略、令牌颁发、在线会话统计、权限检查等场景。
argument-hint: >
  说明场景：是登录鉴权（密码/短信/邮件）、注册流程、密码策略、
  还是 JWT 颁发与验证？是否需要在线会话或访问日志？
---

# Cube Membership 用户认证与权限

## 适用场景

- 实现用户密码登录、短信验证码登录、邮件验证码登录。
- 发送短信/邮件验证码（含防刷限流机制）。
- 配置密码强度正则策略，强制密码复杂度要求。
- 颁发和验证 JWT 令牌（应用级 Token）。
- 获取当前登录用户、当前租户，管理会话生命周期。
- 记录和查询用户访问日志与在线状态统计。

---

## ManageProvider — 用户上下文

### 获取当前用户

```csharp
// 方式1：通过静态属性（推荐，已绑定到当前请求上下文）
var user = ManageProvider.User as User;

// 方式2：从控制器基类属性
// ControllerBaseX 中直接可用：
var user = CurrentUser as User;

// 方式3：通过提供者实例
var user = ManageProvider.Provider.GetCurrent();
```

### 登录与注销

```csharp
// 密码登录（基础接口，推荐通过 UserService.Login()）
var provider = ManageProvider.Provider;
provider.Login(username, password, remember: true);

// 注销（清理 Session + Cookie）
provider.Logout();

// 手动设置当前用户（如 OAuth 回调后）
provider.SetCurrent(user);
```

### 委托代理（Identity Delegation）

```csharp
// 检查是否有可用的身份委托（用于代理另一用户身份）
// Login() 内部自动调用，无需手动触发
provider.CheckAgent(user);   // 若存在有效代理，返回被代理用户

// 查询某用户的所有有效代理
var agents = PrincipalAgent.GetAllValidByAgentId(userId);
```

### ManageProvider 关键属性

| 属性 | 说明 |
|------|------|
| `ManageProvider.User` | 当前请求的登录用户（静态，绑定到 AsyncLocal） |
| `ManageProvider.Provider` | 当前提供者实例（根据租户上下文切换） |
| `ManageProvider.Menu` | 菜单管理器（用于菜单权限查找） |
| `TenantContext.CurrentId` | 当前租户 ID |

---

## UserService — 统一登录服务

### 三种登录模式

```csharp
// 注入方式
[Inject] public UserService UserSvc { get; set; }

// 构建登录请求模型
var model = new LoginModel
{
    Username = "alice",
    Password = "MyPassword123",
    LoginCategory = LoginCategory.Password,   // 必填：密码/手机/邮件
    Remember = true,
    Pkey = "rsa-key-id",                      // 用于解密前端 RSA 加密密码
};

// 统一登录入口（自动分发到对应模式）
ServiceResult<IToken> result = UserSvc.Login(model, HttpContext);
if (result.IsSuccess)
{
    var token = result.Data;      // IToken: AccessToken + RefreshToken + ExpireIn
    return Json(0, "登录成功", token);
}
else
{
    return Json(401, result.Message);
}
```

**LoginCategory 枚举：**

| 值 | 说明 |
|----|------|
| `Password` | 账号密码登录（支持前端 RSA 加密密码） |
| `Phone` | 手机验证码登录（自动注册新用户） |
| `Email` | 邮箱验证码登录（自动注册新用户） |

### 发送验证码

```csharp
// 发送短信验证码（自动防刷：60秒间隔 + IP限5次/10分）
var record = await UserSvc.SendVerifyCode(new VerifyCodeModel
{
    Username = "13800138000",          // 手机号
    Channel  = "Sms",                  // "Sms" 或 "Mail"
    Action   = "login",                // "login" / "bind" / "reset" / "notify"
}, ip: UserHost);

// 发送邮件验证码
var record = await UserSvc.SendVerifyCode(new VerifyCodeModel
{
    Username = "alice@example.com",
    Channel  = "Mail",
    Action   = "reset",                // 重置密码场景
}, ip: UserHost);
```

**Action 类型说明：**

| Action | 场景 | 缓存前缀隔离 |
|--------|------|-------------|
| `login` | 验证码登录 | 独立计数器 |
| `bind` | 绑定手机/邮件 | 独立计数器 |
| `reset` | 重置密码 | 独立计数器 |
| `notify` | 通知（默认） | 独立计数器 |

### 在线会话管理

```csharp
// 更新用户在线记录（RunTimeMiddleware 自动调用）
var online = UserSvc.SetWebStatus(
    online:    existing,
    sessionId: HttpContext.Session?.Id,
    deviceId:  Request.Cookies["deviceId"],
    page:      Request.Path,
    status:    "ok",
    userAgent: new UserAgentParser(Request.Headers["User-Agent"]),
    user:      ManageProvider.User,
    ip:        UserHost
);

// 清理20分钟无活动的过期会话（DataRetentionService 自动调用）
var expired = UserSvc.ClearExpire(secTimeout: 20 * 60);
```

---

## PasswordService — 密码强度验证

```csharp
// 注入或通过 DI 获取
[Inject] public PasswordService PwdSvc { get; set; }

// 验证密码是否符合强度要求（基于 CubeSetting.PaswordStrength 正则）
var valid = PwdSvc.Valid("MyPassword123");
if (!valid)
    throw new Exception("密码不符合要求：需包含大小写字母和数字，至少8位");
```

**配置密码强度（appsettings.json）：**

```json
{
  "Cube": {
    "PaswordStrength": "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$"
  }
}
```

| 正则示例 | 要求 |
|---------|------|
| `*` 或空 | 无要求（默认） |
| `^.{6,}$` | 至少6位 |
| `^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d).{8,}$` | 大小写+数字+8位 |
| `^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[^\\w]).{10,}$` | 大小写+数字+特殊字符+10位 |

---

## TokenService — JWT 令牌

### 颁发令牌

```csharp
// 注入
[Inject] public TokenService TokenSvc { get; set; }

// 颁发（name=用户名或应用名，secret 格式："算法:密钥"）
var token = TokenSvc.IssueToken(
    name:   user.Name,
    secret: CubeSetting.Current.JwtSecret,   // "HS256:MySecretKey..."
    expire: 7200,                            // 有效期（秒）
    id:     Rand.NextString(8)               // 可选：令牌 ID
);
// 返回 IToken { AccessToken, TokenType="JWT", ExpireIn=7200, RefreshToken }
```

### 验证令牌

```csharp
// 验证并解码（含异常）
var (jwt, app) = TokenSvc.DecodeToken(token, CubeSetting.Current.JwtSecret);
var username  = jwt.Subject;    // 令牌中的用户名
var expireAt  = jwt.Expire;     // 过期时间

// 验证并返回异常对象（不抛出）
var (jwt, ex) = TokenSvc.DecodeTokenWithError(token, jwtSecret);
if (ex != null) return Json(403, "令牌无效：" + ex.Message);
```

### 自动续签

```csharp
// 过期前 10 分钟内返回新令牌，其余时间返回 null
var newToken = TokenSvc.ValidAndIssueToken(user.Name, oldToken, jwtSecret, expire: 7200);
if (newToken != null) Response.Headers["X-Token"] = newToken.AccessToken;
```

### JWT 密钥格式

```
"算法:密钥"
```

| 格式示例 | 算法 | 说明 |
|---------|------|------|
| `HS256:MySecretKey123456` | HMAC-SHA256 | 对称密钥，推荐长度 ≥ 32 字符 |
| `RS256:-----BEGIN RSA PRIVATE KEY-----...` | RSA-SHA256 | 非对称，验证时用公钥 |

---

## 应用授权（TokenService.Authorize）

用于验证接入应用（App 实体）的身份，支持 IP 白名单。

```csharp
// 验证应用凭证（不存在时根据 autoRegister 决定是否自动创建）
var app = TokenSvc.Authorize(
    username:     "OrderWeb",          // 应用名
    password:     "app-secret-key",    // 应用密钥
    autoRegister: false,               // 是否允许自动注册新应用
    ip:           UserHost             // 请求来源 IP（用于白名单检查）
);
```

---

## 核心实体速查

### User（用户）

```csharp
// 常用查找方法
User.FindByName(username)
User.FindByMobile(mobile)
User.FindByMail(mail)
User.FindByKey(id)
User.Find(User._.Code == code)

// 密码验证（基于 Membership.User 基类）
var user = User.FindByName(username);
if (user.Password != PasswordService.Hash(password, user.Name))
    throw new Exception("密码错误");

// 常用字段
user.Name        // 登录名
user.DisplayName // 显示名/昵称
user.Mail        // 邮箱
user.Mobile      // 手机号
user.Avatar      // 头像 URL
user.Enable      // 是否启用
user.Roles       // 角色列表（IRole[]）
user.IsAdmin     // 是否超级管理员
```

### Role（角色）

```csharp
Role.FindByName(roleName)
Role.FindAllByNames(roleNames)

// 判断用户是否有某角色
user.Roles.Any(r => r.Name == "Admin");

// 检查权限
user.Has(menu, PermissionFlags.Update)
```

### UserToken（用户令牌记录）

```csharp
// 查找有效 Token 记录（可用于实现 Token 黑名单/刷新）
UserToken.FindByToken(accessToken)
UserToken.FindAllByUserId(userId)

// 核心字段
token.Token        // AccessToken 字符串
token.RefreshToken // 刷新令牌
token.Expire       // 过期时间
token.DeviceId     // 设备 ID
token.Enable       // 是否有效
```

### UserConnect（第三方账号绑定）

```csharp
// 通过第三方账号查找binding
UserConnect.FindByProviderAndOpenID("Weixin", openID)
UserConnect.FindAllByUserId(userId)

// 核心字段
uc.Provider  // "Weixin" / "DingTalk" / "QQ" 等
uc.OpenID    // 第三方 OpenID
uc.UnionID   // 第三方 UnionID（跨应用）
uc.UserID    // 本地用户 ID
uc.NickName  // 第三方昵称
uc.Avatar    // 第三方头像 URL
```

### UserOnline（在线会话）

```csharp
UserOnline.FindBySessionID(sessionId)
UserOnline.FindAllByUserId(userId)

// 核心字段
online.SessionID   // Session 标识
online.DeviceId    // 设备 ID
online.Page        // 当前页面路径
online.Platform    // 操作系统平台
online.Brower      // 浏览器
online.NetType     // 网络类型（Wifi/4G 等）
online.OnlineTime  // 在线时长（秒）
online.Address     // IP 归属地
```

---

## AccessService — 访问日志

```csharp
// AccessService 由 RunTimeMiddleware 自动调用，无需手动使用。
// 管理后台查看日志：系统管理 → 访问日志

// 若需手动记录
var access = new UserVisit
{
    UserId   = ManageProvider.User?.ID ?? 0,
    Page     = Request.Path,
    Action   = "API调用",
    Ip       = UserHost,
    TraceId  = DefaultSpan.Current?.TraceId,
};
access.Insert();
```

---

## 限流与安全配置（CubeSetting）

```csharp
var set = CubeSetting.Current;

// 登录安全
set.MaxLoginError        // 最大错误次数（默认5），超出后封禁
set.LoginForbiddenTime   // 封禁时长（秒，默认300）

// 密码策略
set.PaswordStrength      // 正则表达式，空或"*"=不限制

// 令牌配置
set.JwtSecret            // "算法:密钥" 格式（必须配置！）
set.TokenExpire          // Token 有效期（秒，默认7200）

// 注册策略
set.AllowRegister        // 是否允许新用户注册
set.AutoRegister         // OAuth 登录后是否自动注册
set.DefaultRole          // 新注册用户的默认角色名（默认"普通用户"）

// 会话策略
set.SessionTimeout       // 会话超时（秒，0=浏览器关闭时过期）
set.RefreshUserPeriod    // 刷新用户信息周期（秒，默认600）
```

---

## 常见例外与注意事项

- `CubeSetting.JwtSecret` **不能为空**，否则 `TokenService.IssueToken()` 会抛出解析异常；生产环境应通过 Secret 管理工具注入，不要写入版本控制。
- `ManageProvider.User` 基于 `AsyncLocal<T>` 实现，跨线程传递时需注意 `AsyncLocal` 的值捕获行为。
- `UserService.Login()` 会自动调用 `ManageProvider.SaveCookie()`，无需在控制器层再次写入 Cookie。
- `MaxLoginError` 的错误计数存储在 **缓存（ICache）** 中，服务重启后会重置；若需持久化可自定义 `ICacheProvider` 使用 Redis。
- `SendVerifyCode()` 中的 IP 限流（5次/10分钟）基于请求 IP，内容分发网络（CDN）场景需确保传入真实客户端 IP（`X-Forwarded-For`）。

## 推荐检查项

- [ ] `CubeSetting.JwtSecret` 是否已配置（非空、非默认值）
- [ ] 短信/邮件验证码功能是否已在 `CubeSetting` 中启用，对应服务商配置是否完整
- [ ] `MaxLoginError` 和 `LoginForbiddenTime` 是否根据业务安全要求调整
- [ ] `PasswordService.Valid()` 在用户注册/重置密码时是否已调用
- [ ] Token 响应中的 `ExpireIn` 是否已告知前端用于实现自动续签逻辑
- [ ] `UserConnect` 表是否为第三方登录提供了唯一索引（Provider + OpenID）
