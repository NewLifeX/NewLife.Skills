---
name: cube-webapi
description: >
  使用 NewLife.Cube WebAPI 版本（NewLife.Cube）开发后端 API 服务，涵盖三层控制器体系
  （ControllerBaseX/BaseController/AppControllerBase）、EntityController<T> 实体 CRUD 端点、
  统一响应格式（ApiResponse/ApiListResponse）、JWT/Token 令牌认证（TokenService）、
  中间件服务注册入口（AddCube/UseCube），以及 Swagger/OAuth/SSO 集成。
  适用于基于 Cube 框架开发 REST API、第三方应用接入、Token 认证、API 权限控制等任务。
argument-hint: >
  说明业务场景：是开发管理端 API（ControllerBaseX）、业务 API（BaseController）
  还是第三方应用 API（AppControllerBase）；是否需要 JWT 认证；是否需要 Swagger。
---

# Cube WebAPI 后端 API 服务

## 适用场景

- 基于 NewLife.Cube（WebAPI 版，无视图依赖）开发 REST API 接口。
- 为前端 SPA / 移动端 App / 第三方系统提供标准 JSON 接口。
- 使用 `EntityController<TEntity>` 快速生成标准实体 CRUD 端点。
- 使用 `TokenService` 签发和验证 JWT 令牌，实现无状态认证。
- 集成 Swagger UI 进行 API 文档展示与调试。

---

## 快速启动

### 服务注册与中间件

```csharp
var builder = WebApplication.CreateBuilder(args);

// 注册 Cube 核心服务（含认证、JWT、用户管理、缓存等）
builder.Services.AddCube();

// 可选：Swagger 文档（需引用 NewLife.Cube.Swagger 包）
builder.Services.AddCubeSwagger();

// 可选：主题 UI 模块（无视图时可省略）
// builder.Services.AddCubeUI();

var app = builder.Build();

// 激活 Cube 中间件管道（顺序固定，请勿调整）
app.UseCube(builder.Environment);

// 可选：Swagger UI
app.UseSwagger();
app.UseSwaggerUI();

app.MapControllers();
app.Run();
```

### AddCube() 注册内容速查

| 内容 | 说明 |
|------|------|
| `ManageProvider` | 用户管理提供者（当前用户、权限检查） |
| `TokenService` | JWT 令牌颁发与验证 |
| `PasswordService` | 密码加密/校验（BCrypt） |
| `UserService` | 用户 CRUD、登录、绑定 |
| `AccessService` | 访问日志记录 |
| `PageService` | 页面渲染（管理后台用） |
| `SmsService` / `MailService` | 短信/邮件服务（扩展接口） |
| `DataProtection` | 数据保护密钥（存储到数据库） |
| `DataRetentionService` | 后台服务：定期清理过期日志/令牌 |
| `JobService` | 后台服务：定时作业调度（可选） |
| `ModuleManager` | 功能插件管理（IModule 实现自动加载） |
| CORS | 根据 `CubeSetting.CorsOrigins` 自动配置 |
| Stardust | 星尘链路追踪集成（如项目引用） |

### UseCube() 中间件顺序

```
UseCube()
  ├── UseManagerProvider()       ← 用户主体解析
  ├── UseExceptionHandler()      ← 全局异常捕获
  ├── UseCors("cube_cors")       ← 跨域
  ├── UseStaticHttpContext()     ← 静态 HttpContext 访问
  ├── UseStaticFiles()           ← 头像/上传文件静态访问
  ├── UseCookiePolicy()          ← Cookie 策略
  ├── UseAuthentication()        ← 认证中间件
  ├── UseStardust()              ← 链路追踪
  ├── UseMiddleware<RunTimeMiddleware>()
  ├── UseMiddleware<DataScopeMiddleware>()  ← 数据权限上下文
  └── UseRouter()                ← 区域路由注册
```

---

## 三层控制器体系

### 选型矩阵

| 基类 | 适用场景 | 认证方式 |
|------|---------|---------|
| `ControllerBaseX` | 管理后台 API（后台操作，有会话） | Cookie / Session |
| `BaseController` | 业务 REST API（子类实现令牌验证） | 自定义 Token |
| `AppControllerBase` | 第三方应用接入（JWT 标准认证） | JWT Bearer |

### ControllerBaseX — 管理后台 API 基类

提供当前登录用户、菜单、租户等上下文，适合管理后台接口。

```csharp
[ApiController]
[Route("[area]/[controller]/[action]")]
public class ProductController : ControllerBaseX
{
    [HttpGet]
    [EntityAuthorize(PermissionFlags.Detail)]
    public IActionResult List(Pager p)
    {
        var list = Product.Search(p["key"], p);
        return Json(0, null, list);
    }

    // 可访问的上下文属性
    // ManageProvider.User   → IManageUser 当前用户
    // TenantContext.CurrentId → 当前租户 ID
    // PageSetting           → 页面渲染配置（本请求专用）
}
```

### BaseController — 业务 API 基类

子类必须实现 `OnAuthorize(token)` 验证令牌并返回用户对象。

```csharp
public class BizController : BaseController
{
    // 子类实现令牌验证
    protected override IManageUser OnAuthorize(String token)
    {
        // 自定义令牌验证逻辑
        var user = UserToken.FindByToken(token);
        return user;
    }

    // 未认证时自动返回 403，无需手动检查
    [HttpGet]
    public IActionResult GetProfile()
    {
        var user = Session["user"] as User;
        return Ok(user);
    }
}
```

### AppControllerBase — 第三方应用 API 基类

继承自 `BaseController`，令牌验证已内置（解码 JWT → 获取应用），专用于应用级接入。

```csharp
[ApiController]
[Route("api/[controller]/[action]")]
public class DataController : AppControllerBase
{
    [HttpPost]
    public IActionResult Push([FromBody] DataModel data)
    {
        // App 属性 = 当前接入应用（已通过 JWT 验证）
        var appName = App.Name;

        // WriteLog 自动关联应用和 TraceId
        WriteLog("Push", true, $"收到数据 {data.Count} 条");

        return Ok(new { count = data.Count });
    }
}
```

---

## 统一响应格式

所有接口返回均使用 `ApiResponse<T>` 结构，`ControllerBaseX` 的 `OnActionExecuted` 自动包装。

### ApiResponse<T> 结构

```csharp
// 基础响应
public class ApiResponse<T>
{
    public Int32 Code { get; set; }      // 0=成功，其他=错误
    public String Message { get; set; } // 提示信息
    public T Data { get; set; }         // 业务数据
    public String TraceId { get; set; } // 链路追踪 ID
}

// 列表响应（含分页）
public class ApiListResponse<T> : ApiResponse<IList<T>>
{
    public PageModel Page { get; set; }  // 分页信息（PageIndex/PageSize/TotalCount）
    public T Stat { get; set; }          // 统计行（合计/平均等）
}
```

### 标准状态码

| code | 含义 | 触发场景 |
|------|------|---------|
| `0` | 成功 | 正常返回 |
| `400` | 请求参数错误 | 模型验证失败 |
| `401` | 未登录 / Token 过期 | 无有效 Token |
| `403` | 无权限 | 认证通过但权限不足 |
| `500` | 服务器错误 | 未捕获异常 |

### 手动返回响应

```csharp
// 成功（有数据）
return Json(0, null, data);

// 成功（有提示信息）
return Json(0, "操作成功！", entity);

// 业务错误
return Json(500, "库存不足，无法下单");

// 抛出异常（自动被 OnActionExecuted 捕获并包装为 JSON）
throw new ApiException(400, "参数不合法：金额必须大于0");
throw new NoPermissionException("没有审批权限");
```

---

## JWT 令牌认证

### 颁发令牌（TokenService）

```csharp
// 注入 TokenService（已在 AddCube() 中注册为单例）
public class AuthController : ControllerBaseX
{
    [Inject]
    public TokenService TokenSvc { get; set; }

    [HttpPost, AllowAnonymous]
    public IActionResult Login([FromBody] LoginModel model)
    {
        var user = User.Auth(model.Username, model.Password);
        if (user == null) return Json(401, "用户名或密码错误");

        // 颁发 JWT 令牌
        var tokenModel = TokenSvc.IssueToken(user.Name, user.Secret, expire: 7200);
        return Json(0, "登录成功", tokenModel);
    }
}
```

颁发结果：

```json
{
  "code": 0,
  "data": {
    "accessToken": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "tokenType": "Bearer",
    "expireIn": 7200
  }
}
```

### 验证令牌

```csharp
// TokenService.DecodeToken() 验证 JWT 签名并返回应用信息
var (jwt, app) = TokenSvc.DecodeToken(token, CubeSetting.Current.JwtSecret);

// 获取 JWT 负载中的声明
var name = jwt.Subject;
var expire = jwt.Expire;
```

### 客户端传递令牌（三种方式，任选其一）

```http
# 方式1：Authorization Header（推荐）
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...

# 方式2：自定义 Header
X-Token: eyJhbGciOiJIUzI1NiJ9...

# 方式3：Query String
GET /api/data?token=eyJhbGciOiJIUzI1NiJ9...
```

---

## EntityController<TEntity> — 实体 CRUD 端点

继承后自动获得标准 REST 端点，无需手写 Action。

### 路由映射

```
GET    /[area]/[controller]/Search?key=&page=1&pageSize=20  → 分页查询
GET    /[area]/[controller]/Detail/{id}                     → 查询单条
POST   /[area]/[controller]                                 → 新增（JSON Body）
PUT    /[area]/[controller]                                 → 更新（JSON Body，含 Id）
DELETE /[area]/[controller]?id=1                            → 删除
```

### 继承示例

```csharp
[ApiController]
[Route("[area]/[controller]/[action]")]
[OrderArea]
public class ProductController : EntityController<Product>
{
    // 泛型二参数：实体与视图模型不同时使用
    // public class ProductController : EntityController<Product, ProductModel>
}
```

### 钩子方法

```csharp
// 字段配置（静态构造器）
static ProductController()
{
    // WebAPI 版同样支持 ListFields/SearchFields 等字段集合操作
    // 用于影响 Search 接口返回的字段范围
    ListFields.RemoveField("Remark,Secret");
}

// 查询钩子
protected override IEnumerable<Product> Search(Pager p)
{
    return Product.Search(p["key"], p["categoryId"].ToInt(), p);
}

// CRUD 钩子（同 MVC 版）
protected override void OnInsert(Product entity) { ... }
protected override void OnUpdate(Product entity) { ... }
protected override void OnDelete(Product entity) { ... }

// 验证钩子
protected override Boolean Valid(Product entity, DataObjectMethodType type, Boolean post)
{
    if (post && entity.Price < 0)
        throw new ApiException(400, "价格不能为负数");
    return base.Valid(entity, type, post);
}
```

---

## Swagger 集成

```csharp
// 安装包：dotnet add package NewLife.Cube.Swagger

// Program.cs
builder.Services.AddCube();
builder.Services.AddCubeSwagger();   // 一键集成（含 XML 注释、认证配置）

var app = builder.Build();
app.UseCube(env);
app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "API v1");
    c.RoutePrefix = "swagger";       // 访问地址：/swagger
});
```

`AddCubeSwagger()` 自动完成：
- 加载 `NewLife.Cube.xml` XML 文档注释
- 根据 `OAuthConfig` 配置优先使用 OAuth2，否则使用 JwtBearer
- 自定义 SchemaId（避免同名类冲突）

---

## OAuth / SSO 集成

### 内置 OAuth 提供者（14+）

魔方内置以下第三方 OAuth 登录提供者，通过管理后台 **系统管理 → OAuth配置** 启用：

| 提供者 | 类 | 说明 |
|--------|----|----|
| 微信公众号 | `WeixinClient` | 网页授权登录 |
| 微信小程序 | `WxAppClient` / `WxOpenClient` | code 换 openid |
| 企业微信 | `QyWeiXin` | 企业应用登录 |
| 钉钉 | `DingTalkClient` | 企业应用授权 |
| 支付宝 | `AlipayClient` | 支付宝授权 |
| QQ | `QQClient` | QQ 互联 |
| GitHub | `GithubClient` | 开发者登录 |
| 微博 | `WeiboClient` | 微博登录 |
| 百度 | `BaiduClient` | 百度账号 |
| Microsoft | `MicrosoftClient` | 微软账号 |
| IdentityServer4 | `Id4Client` | 自建 OAuth 服务器 |

### 作为 SSO 服务端（OAuthServer）

魔方自身可作为 SSO 中心，为其他系统提供授权：

```
其他系统 → 携带 client_id 重定向到 /Cube/OAuth/Authorize
         ← 魔方验证用户并返回 code
其他系统 → POST /Cube/OAuth/Token（code 换 token）
         ← 返回 access_token
其他系统 → GET /Cube/OAuth/UserInfo（token 获取用户信息）
```

`SsoClient` 封装了标准 OAuth2 Authorization Code 流程，用于接入外部 SSO：

```csharp
// 在 SsoController 中处理回调
public class SsoController : ControllerBaseX
{
    [AllowAnonymous]
    public async Task<IActionResult> Callback(String code, String state)
    {
        var client = SsoClient.Create(provider);   // 根据 provider 名创建客户端
        var info = await client.GetUserInfo(code);  // code 换取用户信息
        // 自动创建/绑定用户，写入会话
        return Redirect("/");
    }
}
```

---

## 菜单与权限（WebAPI 版）

WebAPI 版权限机制与 MVC 版一致，同样使用 `[EntityAuthorize]` 和 `PermissionFlags`。

```csharp
[EntityAuthorize(PermissionFlags.Insert)]
[HttpPost]
public IActionResult Create([FromBody] Product model) { ... }

[EntityAuthorize(PermissionFlags.Delete)]
[HttpDelete]
public IActionResult Remove(Int32 id) { ... }
```

权限检查失败（用户已登录但无权限）返回：

```json
{ "code": 403, "message": "没有权限", "traceId": "xxx" }
```

---

## 常见例外与注意事项

- `BaseController` 子类**必须重写** `OnAuthorize(token)` 方法，否则所有请求均返回 403。
- `AppControllerBase` 使用 `App.Secret` 作为 JWT 签名密钥，不使用 `CubeSetting.JwtSecret`，两者需区分。
- `ApiListResponse<T>.Stat` 统计行仅在实体 Search 方法支持时才有数据，默认为 `null`。
- 跨域配置 `CubeSetting.CorsOrigins = "*"` 允许所有来源，生产环境应改为具体域名。
- `UseCube()` 必须在 `UseAuthentication()` 之前调用（内部已处理顺序），不要在 `app.UseAuthentication()` 后再调用 `UseCube()`。
- `AddCubeSwagger()` 自动启用 `CustomSchemaIds`，若有同名但不同命名空间的类，需确保 `FullName` 不冲突。

---

## 推荐检查项

- [ ] `AddCube()` 是否在 `AddControllers()` 之前调用（确保模型绑定器注册生效）
- [ ] `UseCube()` 是否在 `UseEndpoints()` / `MapControllers()` 之前调用
- [ ] JWT 相关接口是否标注了 `[AllowAnonymous]`（登录、获取Token 接口必须允许匿名）
- [ ] `BaseController` 子类是否实现了 `OnAuthorize()` 方法
- [ ] `CubeSetting.CorsOrigins` 在生产环境不为 `"*"`
- [ ] `CubeSetting.JwtSecret` 是否已配置为随机强密钥（不使用默认空值）
- [ ] `AddCubeSwagger()` 是否只在开发/测试环境启用（避免线上暴露 API 文档）

## 待确认问题

- `ControllerBaseX` 与 `BaseController` 的响应包装逻辑是否共用同一个 `OnActionExecuted` 过滤器。
- `EntityController<TEntity>` 的 Search 端点是否支持自定义字段投影（返回部分字段）。
