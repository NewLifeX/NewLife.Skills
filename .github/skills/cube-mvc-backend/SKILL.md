---
name: cube-mvc-backend
description: >
  使用 NewLife.Cube MVC 版本（NewLife.CubeNC）开发后台管理系统，涵盖 Area 区域注册、
  EntityController<T> 实体控制器CRUD、字段定制机制（ListFields/FormFields/SearchFields/DetailFields）、
  视图重载覆盖机制（ThemeViewLocationExpander + CubeEmbeddedFileProvider）、
  菜单与权限体系（MenuAttribute/EntityAuthorizeAttribute/PermissionFlags），
  以及 AddCube()/UseCube() 启动配置入口。
  适用于基于 Cube MVC 框架开发后台管理系统、控制器扩展、视图覆盖、字段定制等任务。
argument-hint: >
  说明业务场景：是新建 Area 区域、扩展控制器、还是定制字段/视图；
  如涉及权限，说明需要哪类权限检查（查看/新增/编辑/删除）。
---

# Cube MVC 后台管理系统

## 适用场景

- 基于 NewLife.CubeNC（含 `#if MVC` 编译符的项目）开发管理后台。
- 新建 Area 区域并自动注册菜单与权限。
- 继承 `EntityController<T>` 开发实体 CRUD 页面并定制字段显示。
- 覆盖魔方内置视图（通过本地物理文件优先机制）。
- 配置菜单特性、权限过滤器、数据权限中间件。
- 继承 `ConfigController<T>` 为配置类提供 Web 查看和编辑页面。

---

## 快速启动

### 1. 服务注册（Program.cs / Startup.cs）

```csharp
var builder = WebApplication.CreateBuilder(args);

// 添加魔方核心服务（包含认证、模型绑定、菜单、权限、缓存等）
builder.Services.AddCube();

// 添加 Razor Pages 和 MVC
builder.Services.AddControllersWithViews();

var app = builder.Build();

// 激活魔方中间件管道（认证、静态文件、路由、数据权限等）
app.UseCube(builder.Environment);

// 映射控制器路由
app.MapControllerRoute(
    name: "default",
    pattern: "{area:exists}/{controller=Index}/{action=Index}/{id?}");

app.Run();
```

### 2. 项目模板方式

```powershell
# 安装模板
dotnet new install NewLife.Templates

# 创建带魔方的 Web 项目
dotnet new cube -n MyCompanyWeb

# 添加数据层引用
dotnet add reference ../MyCompany.Data/MyCompany.Data.csproj
```

> 📌 项目分层策略（两层起步、何时拆分数据层、何时引入服务层），参见 `project-architecture` 技能。

---

## Area 区域注册

每个业务模块对应一个 Area，Area 注册时会自动扫描控制器、创建菜单树、绑定权限。

### AreaBase 继承规范

```csharp
// Areas/Order/OrderAreaRegistration.cs
[DisplayName("订单管理")]                          // 菜单显示名
[Menu(50, true, Icon = "fa-shopping-cart",         // Order=50，可见=true
      LastUpdate = "20240601")]                     // 有新菜单项时触发重建
public class OrderArea : AreaBase
{
    public OrderArea() : base("Order") { }         // 必须传入与文件夹同名的区域名
}
```

**命名约定**：类名必须以 `Area` 结尾，去掉 `Area` 后缀即为区域名（`OrderArea` → `Order`）。

**`AreaBase` 做了什么**：
1. 自动调用 `MenuHelper.ScanController()` 反射扫描本区域所有控制器。
2. 依据 `[MenuAttribute]` 和 `[DisplayName]` 创建或更新数据库菜单记录。
3. 将菜单ID写入 `CubeService.AreaNames`，供权限过滤器判断。

### Menu 特性参数

| 参数 | 说明 |
|------|------|
| `Order`（第1参数） | 排序值，**越大越靠前**（Admin=-1，Cube=-2） |
| `Visible`（第2参数） | 是否在导航中显示 |
| `Icon` | FontAwesome 图标名，如 `fa-table` |
| `LastUpdate` | 日期字符串，内置菜单有改动时需更新此值以触发重建 |

---
## ConfigController\<T\> 配置控制器

为 `Config<T>` 配置类提供 Web 查看和编辑页面。当业务应用定义了配置类（如 `OrderSetting : Config<OrderSetting>`），可在 Web 项目中添加一个控制器来提供配置管理页面。

### 最简用法（零代码控制器）

大多数情况下，配置控制器**不需要编写任何成员代码**，继承即可：

```csharp
using System.ComponentModel;
using Microsoft.AspNetCore.Mvc;

/// <summary>订单设置控制器</summary>
[DisplayName("订单设置")]                         // 菜单显示名
[OrderArea]                                         // 声明所属区域
[Menu(0, false, Icon = "fa-cog")]                    // 菜单排序与可见性
public class OrderSettingController : ConfigController<OrderSetting>
{
}
```

配置控制器自动提供：
- **查看页**：按 `[Category]` 分组展示所有配置项，显示 `[Description]` 作为说明
- **编辑页**：表单修改配置值，保存时通过 `Copy + Save` 确保线程安全更新

### 进阶用法（自定义字段与保存逻辑）

参考 `CubeController`，可通过重写方法实现业务定制：

```csharp
[DisplayName("支付设置")]
[OrderArea]
[Menu(0, false, Icon = "fa-credit-card")]
public class PaySettingController : ConfigController<PaySetting>
{
    /// <summary>执行前。可用于定制字段展示</summary>
    public override void OnActionExecuting(ActionExecutingContext filterContext)
    {
        // 动态设置下拉选项
        var list = GetMembers(typeof(PaySetting));
        var df = list.FirstOrDefault(e => e.Name == "PayChannel");
        if (df != null)
        {
            df.DataSource = e => new Dictionary<String, String>
            {
                ["Alipay"] = "支付宝",
                ["WechatPay"] = "微信支付",
                ["UnionPay"] = "银联支付",
            };
        }

        base.OnActionExecuting(filterContext);

        // 自定义导航视图（可选）
        PageSetting.NavView = "_Object_Nav";
    }

    /// <summary>保存时触发。可用于保存后做业务处理</summary>
    public override ActionResult Update(PaySetting obj)
    {
        var rs = base.Update(obj);

        // 保存后的业务处理，如刷新缓存、通知其他服务等
        PayService.RefreshConfig();

        return rs;
    }
}
```

### Value 属性机制

`ConfigController<T>` 继承自 `ObjectController<T>`，通过 `Value` 属性管理配置单例：

- **get**：返回 `Config<T>.Current` 单例
- **set**：调用 `cfg.Copy(value)` + `cfg.Save()`，而非直接替换单例引用，确保线程安全

当配置类使用 `DbConfigProvider` 时，`Save()` 会将变更写回 Parameter 表，定时刷新机制确保其他实例自动同步。

### 常用重写方法

| 方法 | 用途 |
|------|------|
| `OnActionExecuting` | 定制字段描述、设置下拉数据源、控制导航视图 |
| `Update(TConfig obj)` | 保存配置后执行业务逻辑（刷新缓存、修复菜单等） |
| `GetMembers(type)` | 获取配置类的成员列表，可动态修改 `Description`/`DataSource` |

---
## EntityController<T> 实体控制器

### 继承与装饰

```csharp
// Areas/Order/Controllers/OrderController.cs
[Menu(100, true, Icon = "fa-list")]      // 控制器在菜单中的位置与可见性
[OrderArea]                              // 声明所属区域（AreaBase 子类特性）
public class OrderController : EntityController<Order>
{
    // 若实体与视图模型不同，使用泛型二参数形式
    // public class OrderController : EntityController<Order, OrderModel>
}
```

### 静态构造器字段配置（核心模式）

所有字段定制均在 **静态构造器** 中完成，仅执行一次：

```csharp
static OrderController()
{
    // ===== 列表字段 =====
    ListFields.RemoveCreateField()          // 删除 CreateUser/CreateTime
              .RemoveUpdateField()          // 删除 UpdateUser/UpdateTime
              .RemoveRemarkField();         // 删除 Remark

    ListFields.RemoveField("Secret");       // 删除指定字段（支持逗号分隔多个）

    // 在 Remark 前插入自定义链接列
    var df = ListFields.AddListField("detail", null, "Remark");
    df.DisplayName = "查看详情";
    df.Url = "OrderDetail?orderId={Id}";    // {Id} 自动替换为当前行实体的属性值
    df.Target = "_blank";                   // 在新标签打开
    df.DataAction = "action";               // 使用 ajax 方式（不跳转，执行动作）

    // 自定义单元格值（委托）
    var sf = ListFields.GetField("Status") as ListField;
    sf.GetValue = (entity) => ((Order)entity).StatusName;    // 返回值覆盖默认显示

    // ===== 添加表单字段 =====
    AddFormFields.RemoveField("Id,CreateTime,CreateUser,UpdateTime,UpdateUser");
    AddFormFields.GetField("Title").Required = true;         // 设置必填

    // ===== 编辑表单字段 =====
    EditFormFields.RemoveField("CreateTime,CreateUser");
    EditFormFields.AddField("AuditTime");   // 从 AllFields 中补充字段

    // ===== 搜索字段 =====
    SearchFields.AddField("Status").Multiple = true;         // 多选下拉
    SearchFields.AddField("CreateTime");

    // ===== 详情字段 =====
    DetailFields.AddField("Remark");
}
```

### 常用字段操作方法速查

| 方法 | 说明 |
|------|------|
| `RemoveField(params string[])` | 删除字段，支持 `*` 模糊匹配 |
| `RemoveCreateField()` | 批量删除 CreateUser/CreateTime |
| `RemoveUpdateField()` | 批量删除 UpdateUser/UpdateTime |
| `RemoveRemarkField()` | 批量删除 Remark |
| `AddField(name)` | 从实体 AllFields 添加指定字段 |
| `AddListField(name, before, after)` | 插入自定义列表列（ListField 类型） |
| `AddFormField(name, before, after)` | 插入自定义表单项（FormField 类型） |
| `GetField(name)` | 获取字段对象（可强转为 ListField/FormField 等) |
| `Replace(oriName, newName)` | 替换字段 |

### ListField 扩展属性

```csharp
var lf = ListFields.GetField("Name") as ListField;

lf.Header       = "订单编号";          // 列头文字（覆盖 DisplayName）
lf.Url          = "/Order/Detail/{Id}"; // 单元格链接，{属性名} 自动插值
lf.Target       = "_blank";            // 链接目标
lf.TextAlign    = TextAligns.Center;   // 对齐方式
lf.Class        = "text-warning";      // 单元格 CSS 类
lf.MaxWidth     = 200;                 // 超出宽度折叠
lf.DataAction   = "action";           // "action" = ajax调用，null = 普通跳转
lf.GetValue     = e => ((Order)e).FormatAmount();   // 自定义显示值
lf.GetClass     = e => ((Order)e).IsOverdue ? "text-red" : "";  // 动态样式
```

### 搜索与数据加载钩子

```csharp
// 重载搜索逻辑（调用实体 Search 方法）
protected override IEnumerable<Order> Search(Pager p)
{
    return Order.Search(p["key"], p["status"].ToInt(-1), p);
}

// 重载单条查询
protected override Order FindData(String id)
{
    return Order.FindByKey(id.ToInt());
}
```

### CRUD 钩子方法

```csharp
// 保存前验证（新增与编辑均触发）
protected override Boolean Valid(Order entity, DataObjectMethodType type, Boolean post)
{
    if (post && entity.Amount <= 0)
        throw new Exception("金额必须大于0");
    return base.Valid(entity, type, post);
}

// 新增前处理
protected override void OnInsert(Order entity)
{
    entity.CreateUserId = ManageProvider.User?.ID ?? 0;
    base.OnInsert(entity);
}

// 更新前处理
protected override void OnUpdate(Order entity)
{
    entity.UpdateTime = DateTime.Now;
    base.OnUpdate(entity);
}

// 删除前处理
protected override void OnDelete(Order entity)
{
    if (entity.Status == 2) throw new Exception("已完成订单不允许删除");
    base.OnDelete(entity);
}
```

---

## 视图覆盖机制

### 覆盖优先级（从高到低）

应用程序本地物理文件 **始终优于** 魔方嵌入式资源：

```
1. ~/Areas/{Area}/Views/{Controller}_{Theme}/{Action}.cshtml  ← 主题特定覆盖
2. ~/Areas/{Area}/Views/{Controller}/{Action}.cshtml          ← 控制器覆盖
3. ~/Areas/{Area}/Views/{Theme}/{Action}.cshtml               ← 主题共享覆盖
4. ~/Areas/{Area}/Views/Shared/{Action}.cshtml                ← 区域共享覆盖
5. ~/Views/{Theme}/{Action}.cshtml                            ← 应用级主题覆盖
6. ~/Views/Shared/{Action}.cshtml                             ← 应用级共享覆盖
7. 魔方程序集嵌入资源（fallback）
```

**`{Theme}`** 由 `CubeSetting.Current.Theme` 决定（默认 `ACE`），首页使用 `CubeSetting.Current.Skin`。

### 常见视图覆盖场景

```
# 覆盖列表页（Order 区域 Product 控制器）
Areas/Order/Views/Product/Index.cshtml

# 覆盖编辑表单（共享给该区域所有控制器）
Areas/Order/Views/Shared/EditForm.cshtml

# 覆盖特定主题下的列表页
Areas/Order/Views/Product_ACE/Index.cshtml

# 覆盖全局共享视图（影响所有区域）
Views/ACE/_LayoutAdmin.cshtml
```

### 静态资源覆盖

通过物理文件覆盖嵌入资源中的 JS/CSS/图片：

```
# 项目 wwwroot 中同路径文件会优先于魔方嵌入资源
wwwroot/js/jquery.min.js         → 覆盖嵌入的同名文件
wwwroot/css/custom.css           → 新增自定义样式
```

---

## 菜单与权限

### PermissionFlags 枚举

| 值 | 含义 | 适用 Action |
|----|------|------------|
| `Detail` (0x01) | 查看 | Index、Detail |
| `Insert` (0x02) | 新增 | Add (GET/POST) |
| `Update` (0x04) | 编辑 | Edit (GET/POST) |
| `Delete` (0x08) | 删除 | Delete |
| `Approve` (0x10) | 审批 | 自定义 Action |
| `Export` (0x20) | 导出 | Export |

### EntityAuthorize 用法

```csharp
// 方法级权限（自定义 Action）
[EntityAuthorize(PermissionFlags.Approve)]
public ActionResult Approve(Int32 id)
{
    // ...
}

// 允许匿名访问（跳过权限检查）
[AllowAnonymous]
public ActionResult Public()
{
    // ...
}
```

`EntityController<T>` 内置 5 个标准 Action 已自动配置对应权限，无需手动标注。

### 权限检查流程

```
请求到达 → EntityAuthorizeAttribute.OnAuthorization()
  ↓
检查 [AllowAnonymous] → 有则跳过
  ↓
根据控制器命名空间映射到菜单节点
  ↓
user.Has(menu, PermissionFlags) → XCode Membership 实现
  ↓
无权限 → JSON 请求返回 401/403；浏览器请求跳转登录页
```

---

## 数据权限（多租户隔离）

`DataScopeMiddleware` 在每次请求时自动设置当前用户的数据权限上下文，XCode 查询会自动附加过滤条件。

```csharp
// 中间件自动注入，无需手动调用
// UseCube() 内部已注册 UseMiddleware<DataScopeMiddleware>()

// 控制器内可读取当前租户
var tenantId = TenantContext.CurrentId;

// 若需要跳过数据权限过滤（超级管理员场景）
using (DataScopeContext.Disable())
{
    var all = Order.FindAll();  // 此处查询不带数据权限过滤
}
```

---

## CubeSetting 关键配置

`CubeSetting` 通过 `[Config("Cube")]` 绑定，会自动从 `appsettings.json` 或 Cube 配置文件读取。

```csharp
var set = CubeSetting.Current;

// 读取常用配置
var theme     = set.Theme;               // 主题名（默认 ACE）
var skin      = set.Skin;               // 首页皮肤
var uploadDir = set.UploadPath;          // 上传目录（默认 Uploads）
var avatarDir = set.AvatarPath;          // 头像目录（默认 Avatars）
var jwtSecret = set.JwtSecret;          // JWT 签名密钥
var expire    = set.TokenExpire;         // Token 有效期（秒，默认 7200）
var maxErr    = set.MaxLoginError;       // 登录失败上限（默认 5）
```

**配置文件示例（appsettings.json）：**

```json
{
  "Cube": {
    "Theme": "Tabler",
    "TokenExpire": 86400,
    "CorsOrigins": "https://app.example.com",
    "MaxLoginError": 3,
    "JwtSecret": "your-secret-key-here"
  }
}
```

---

## 常见例外与注意事项

- `ListFields.AddListField()` 返回的是 `ListField` 类型，但存在 `GetField()` 返回 `DataField`，**需要强转**才能访问 `Url`/`GetValue` 等扩展属性。
- 静态构造器中对字段集合的修改是**全局一次性**操作，不能在实例方法中修改（否则线程不安全）。
- 视图文件名含 `-` 或 `@` 时，嵌入资源中对应名称会被映射为 `_`（`CubeEmbeddedFileProvider` 自动反向映射）。
- `[Menu]` 的 `LastUpdate` 字段若不更新，新添加的控制器菜单项不会触发菜单重建；建议每次改动菜单结构时更新此值。
- 区域名大小写需与文件夹名**严格一致**（`base("Order")` vs 文件夹 `Areas/Order/`）。

---

## 推荐检查项

- [ ] `AreaBase` 子类静态构造器中是否已调用 `RegisterArea(typeof(XxxArea))`（或通过 `base()` 自动完成）
- [ ] 控制器是否标注了所属区域的特性（如 `[OrderArea]`）
- [ ] 静态构造器字段配置是否放在 `static XxxController(){}` 中（非实例构造器）
- [ ] 覆盖视图路径是否与 `ThemeViewLocationExpander` 查找顺序严格一致
- [ ] 自定义 Action 是否标注了 `[EntityAuthorize]` 或 `[AllowAnonymous]`
- [ ] `CubeSetting.JwtSecret` 在生产环境中是否已配置为强密钥
- [ ] 配置控制器是否标注了区域特性、`[DisplayName]` 和 `[Menu]`
- [ ] 服务端配置类是否已通过 `DbConfigProvider` 切换到数据库存储

## 待确认问题

- `EntityTreeController`（树形控制器）与 `EntityController` 的字段配置方式是否完全相同。
- `ReadOnlyEntityController` 是否支持 `AddListField` 等写操作相关的字段定制。
