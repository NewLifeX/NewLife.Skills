---
name: cube-oauth-sso
description: >
  使用 NewLife.Cube 的 OAuth/SSO 体系实现第三方登录和单点登录，
  涵盖 OAuthClient 基类（14+ 内置提供者）、OAuthConfig 数据库配置、
  SsoController 回调处理、OAuthServer 作为 SSO 服务端（Authorize/Token/UserInfo 端点），
  以及 SsoClient 作为 SSO 客户端（密码模式/客户端凭证模式）。
  适用于微信/钉钉/企业微信等第三方登录接入、自建 SSO 中心、跨系统统一认证等场景。
argument-hint: >
  说明场景：是接入第三方平台（微信/钉钉等）、使用魔方作为 SSO 服务端，
  还是作为 SSO 客户端接入外部 SSO？需要的授权模式（授权码/密码/客户端凭证）？
---

# Cube OAuth / SSO 单点登录

## 适用场景

- 为应用添加微信公众号、微信小程序、企业微信、钉钉、QQ、GitHub 等第三方登录。
- 将魔方作为 OAuth2 SSO 服务端，向子系统统一提供用户认证。
- 通过 `SsoClient` 在服务间以密码模式或客户端凭证模式进行用户身份验证。
- 管理后台配置第三方 OAuth 应用，无需修改代码。

---

## 内置 OAuth 提供者

| 名称（Name） | 类 | 说明 |
|----|----|----|
| `Weixin` | `WeixinClient` | 微信公众号网页授权 |
| `WxApp` | `WxAppClient` | 微信小程序 code 换 openid |
| `WxOpen` | `WxOpenClient` | 微信开放平台 |
| `QyWeixin` / `QyWeiXin` | `QyWeiXin` | 企业微信应用授权 |
| `DingTalk` | `DingTalkClient` | 钉钉企业应用免登 |
| `Alipay` | `AlipayClient` | 支付宝授权 |
| `QQ` | `QQClient` | QQ 互联 |
| `Github` | `GithubClient` | GitHub Developer OAuth |
| `Weibo` | `WeiboClient` | 微博登录 |
| `Baidu` | `BaiduClient` | 百度账号 |
| `Microsoft` | `MicrosoftClient` | 微软账号 |
| `Id4` | `Id4Client` | IdentityServer4 自建 OAuth |
| `Taobao` | `TaobaoClient` | 淘宝开放平台 |
| `NewLife` | `OAuthClient`（基类） | 魔方自身 SSO 服务端 |

---

## OAuthConfig — 数据库配置

所有 OAuth 配置存储在 `OAuthConfig` 表，通过管理后台（**系统管理 → OAuth配置**）维护，无需硬编码。

### 核心字段

```csharp
public class OAuthConfig
{
    public String Name { get; set; }           // 提供者唯一名，与 OAuthClient 子类绑定
    public String NickName { get; set; }       // 登录页显示名（如"微信公众号"）
    public String Logo { get; set; }           // 登录按钮图标 URL

    // 应用凭证
    public String AppId { get; set; }          // 第三方 AppId / ClientId
    public String Secret { get; set; }         // 第三方 AppSecret / ClientSecret
    public String Scope { get; set; }          // 授权范围（snsapi_userinfo/user_info 等）

    // 服务端点（使用内置客户端时无需填写，已内置）
    public String Server { get; set; }         // OAuth 服务基地址
    public String AuthUrl { get; set; }        // 授权端点 URL
    public String AccessUrl { get; set; }      // 令牌端点 URL
    public String UserUrl { get; set; }        // 用户信息端点 URL
    public String AppUrl { get; set; }         // 本应用外部地址（反向代理时使用）

    // 授权类型
    public GrantTypes GrantType { get; set; }  // AuthorizationCode/Password/ClientCredentials
    public String FieldMap { get; set; }       // 字段映射 JSON：{"openid":"user_id"}

    // 功能开关
    public Boolean Enable { get; set; }        // 是否启用
    public Boolean Visible { get; set; }       // 登录页是否展示此方式
    public Boolean AutoRegister { get; set; }  // 是否自动注册新用户
    public Boolean FetchAvatar { get; set; }   // 是否下载第三方头像到本地
    public Boolean Debug { get; set; }         // 输出调试日志
}
```

### 枚举值

```csharp
public enum GrantTypes
{
    AuthorizationCode = 0,  // 授权码模式（网页登录，最常用）
    Implicit,               // 隐式模式（已弃用）
    Password,               // 密码模式（服务端直接验证）
    ClientCredentials,      // 客户端凭证（机器对机器）
}
```

---

## 第三方登录流程（以微信为例）

### 1. 配置 OAuthConfig（管理后台一次性操作）

```
系统管理 → OAuth配置 → 添加
  Name:        Weixin
  NickName:    微信公众号
  AppId:       wx1234567890abcdef
  Secret:      你的-app-secret
  Scope:       snsapi_userinfo
  Enable:      ✓
  Visible:     ✓
  AutoRegister:✓
```

### 2. 用户点击"微信登录"

浏览器访问 `/Sso/Login?name=Weixin&r=/dashboard`（其中 `r` 是登录成功后跳转地址）。

### 3. SsoController 处理回调

魔方内置 `SsoController` 自动处理整个 OAuth 流程：

```
1. GET /Sso/Login?name=Weixin&r=/dashboard
      → 创建 WeixinClient，Authorize() 构建授权 URL
      → 重定向到微信授权页

2. 微信回调 GET /Sso/LoginInfo/Weixin?code=xxx&state=yyy
      → GetAccessToken(code) 换 access_token
      → GetUserInfo() 获取 openid/nickname/avatar
      → 查找或自动注册本地 User（通过 UserConnect 绑定）
      → ManageProvider.Login(userId) 写入 Session + Cookie
      → 重定向到 /dashboard
```

### 4. OAuthClient API（自定义流程时使用）

```csharp
// 在自定义控制器中手动控制 OAuth 流程
public class CustomSsoController : ControllerBaseX
{
    [AllowAnonymous]
    public IActionResult LoginByWeixin()
    {
        // 1. 创建客户端（自动从 OAuthConfig 加载配置）
        var client = OAuthHelper.Create(TenantContext.CurrentId, "Weixin");

        // 2. 构建授权 URL（state 存到 Session 用于防 CSRF）
        var redirectUri = $"{Request.Scheme}://{Request.Host}/callback/Weixin";
        var authUrl = client.Authorize(redirectUri, state: "random-state", Request.GetUri()....)；
        return Redirect(authUrl);
    }

    [AllowAnonymous]
    public async Task<IActionResult> CallbackWeixin(String code, String state)
    {
        var client = OAuthHelper.Create(TenantContext.CurrentId, "Weixin");

        // 3. 用 code 换 access_token
        await client.GetAccessToken(code);              // 填充 AccessToken

        // 4. 用 access_token 获取用户信息
        await client.GetUserInfo();                     // 填充 OpenID/NickName/Avatar/Mail 等

        // 5. 通过 OpenID 查找绑定关系
        var uc = UserConnect.FindByProviderAndOpenID("Weixin", client.OpenID);
        if (uc == null)
        {
            // 首次登录：自动注册本地用户
            uc = new UserConnect { Provider = "Weixin", OpenID = client.OpenID };
            var user = new User { Name = client.NickName, DisplayName = client.NickName };
            user.Insert();
            uc.UserID = user.ID;
            uc.Insert();
        }

        // 6. 登录
        ManageProvider.Provider.SetCurrent(User.FindByKey(uc.UserID));
        return Redirect("/");
    }
}
```

---

## 魔方作为 SSO 服务端（OAuthServer）

魔方可对外提供标准 OAuth2 授权码模式，让子系统通过魔方统一登录。

### 端点列表（SsoController 提供）

| 端点 | 方法 | 说明 |
|------|------|------|
| `/Sso/Authorize` | GET | 子系统重定向到此处，魔方显示登录界面 |
| `/Sso/Auth2` | GET | 用户登录后内部跳转，生成 code |
| `/Sso/Access_Token` | GET/POST | 子系统用 code 换 access_token |
| `/Sso/Token` | GET/POST | 密码模式/客户端凭证模式 |
| `/Sso/UserInfo` | GET/POST | 子系统用 token 获取用户信息 |
| `/Sso/Logout` | GET | 注销（可传 `redirect_uri` 参数） |

### 子系统接入步骤

**第一步：在魔方管理后台注册子系统应用**

```
系统管理 → 应用系统（App）→ 添加
  Name:    OrderWeb
  Secret:  app-secret-key
  Enable:  ✓
  允许IP:  （留空=不限，或填写子系统 IP）
```

**第二步：子系统配置 SsoClient**

```csharp
// 子系统 appsettings.json（或 Cube 配置文件）
{
  "SsoServer": "https://sso.company.com",
  "AppId": "OrderWeb",
  "AppSecret": "app-secret-key",
  "JwtKey": "main$-----BEGIN PUBLIC KEY-----\nMIIBIjAN...\n-----END PUBLIC KEY-----"
}

// 子系统代码中创建 SsoClient
var sso = SsoClient.Create("NewLife");  // Name 对应 OAuthConfig 中 NewLife 提供者

// 也可以直接实例化
var sso = new SsoClient
{
    Server = "https://sso.company.com",
    AppId = "OrderWeb",
    Secret = "app-secret-key",
    SecurityKey = "main$-----BEGIN PUBLIC KEY-----\nMII..."
};
```

**第三步：子系统密码模式登录（服务端直连）**

```csharp
// 密码模式（密码会被 RSA 公钥加密后传输）
var token = await sso.GetToken("alice@company.com", "user-password");
var user = await sso.GetUser(token.AccessToken);
Console.WriteLine($"用户 {user.Name}，角色：{user.Roles}");

// 刷新令牌
var newToken = await sso.RefreshToken(token.AccessToken);

// 一体化验证（直接返回用户信息）
var userInfo = await sso.UserAuth("alice@company.com", "user-password");
```

**第四步：客户端凭证模式（应用间 API 调用）**

```csharp
// 用应用凭证换取应用级令牌
var appToken = await sso.GetToken(deviceId: "server-app-001");
// 用于机器间 API 调用，不关联最终用户
```

---

## SsoClient API 速查

| 方法 | 说明 |
|------|------|
| `GetToken(username, password)` | 密码模式：用户名密码换令牌（密码 RSA 公钥加密） |
| `GetToken(deviceId)` | 客户端凭证模式：设备 ID 换令牌 |
| `RefreshToken(accessToken)` | 刷新已有令牌，获取新 AccessToken |
| `GetUserInfo(accessToken)` | 用令牌获取用户信息（原始字典） |
| `GetUser(accessToken)` | 用令牌获取强类型用户对象 |
| `UserAuth(username, password)` | 一体化：验证并直接返回用户信息 |
| `GetKey(client_id, client_secret)` | 获取 JWT 验证公钥 |

---

## OAuthClient 基类 — 可扩展属性

自定义 OAuth 提供者时继承 `OAuthClient`：

```csharp
public class MyOAuthClient : OAuthClient
{
    public MyOAuthClient()
    {
        Name = "MyProvider";
        Server = "https://auth.example.com";
        AuthUrl = "/oauth/authorize";
        AccessUrl = "/oauth/token";
        UserUrl = "/api/userinfo";
        Scope = "read:user";

        // 字段映射（第三方字段名 → 魔方标准字段名）
        FieldMap = new Dictionary<String, Object>
        {
            ["login"]      = "UserName",  // GitHub 的 login 映射到 UserName
            ["avatar_url"] = "Avatar",
            ["email"]      = "Mail",
        };
    }
}
```

---

## 常见例外与注意事项

- 微信公众号在**非微信内置浏览器**中无法使用 `snsapi_userinfo` scope，需改为 `snsapi_base`（仅获取 OpenID）。
- `OAuthConfig.AppUrl` 在反向代理（Nginx/网关）场景下必须填写应用的**外网地址**，否则 `redirect_uri` 会被构建为内网地址导致回调失败。
- `SsoClient.SecurityKey` 格式为 `"keyName$PEM-PUBLIC-KEY"`，其中 `keyName` 为公钥名（固定 `"main"`），`$` 后为 PEM 格式 RSA 公钥（Base64 encoded）。
- `OAuthConfig.FieldMap` 是 JSON 字符串，格式为 `{"第三方字段名":"标准字段名"}`，用于适配非标准第三方接口的字段命名。
- 同一 `Provider`（如 `"Weixin"`）在同一租户内只能有一条 `OAuthConfig`，多租户按 `TenantId` 隔离。

## 推荐检查项

- [ ] `OAuthConfig.Enable` 和 `OAuthConfig.Visible` 是否均已启用（二者独立控制）
- [ ] 第三方平台上 OAuth 应用回调地址是否与应用实际地址一致（`AppUrl` 配置正确）
- [ ] `SsoClient.SecurityKey` 是否配置了 RSA 公钥（密码模式必须，避免明文传输密码）
- [ ] 子系统（App 实体）是否在魔方管理后台注册并启用
- [ ] `AutoRegister = true` 时是否已考虑自动注册用户的默认角色（由 `CubeSetting.DefaultRole` 决定）
