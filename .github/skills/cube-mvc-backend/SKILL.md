---
name: cube-mvc-backend
description: >
  使用 NewLife.Cube MVC 版本（NewLife.CubeNC）开发后台管理系统，涵盖 Area 区域注册、
  EntityController<T> 实体控制器 CRUD、字段定制机制（ListFields/FormFields/SearchFields/DetailFields）、
  视图重载覆盖机制（ThemeViewLocationExpander + CubeEmbeddedFileProvider）、
  菜单与权限体系（MenuAttribute/EntityAuthorizeAttribute/PermissionFlags），
  ConfigController<T> 配置管理控制器，以及 AddCube()/UseCube() 启动配置。
  适用于 Cube MVC 框架后台管理系统的深度定制：字段操作速查、视图覆盖、ConfigController。
argument-hint: >
  说明业务场景：是新建 Area 区域、扩展控制器、定制字段/视图，还是添加配置管理页面；
  如涉及权限，说明需要哪类权限检查（查看/新增/编辑/删除/审批/导出）。
---

# Cube MVC 后台管理系统（深度定制）

> 基础用法（Area 创建、控制器结构、Search 重写）参见 `cube.instructions.md`。  
> 本 skill 专注深度定制：字段操作速查、视图覆盖、ConfigController、权限体系。

---

## EntityController\<T\> 字段定制

### 静态构造器（核心模式）

所有字段定制均在**静态构造器**中完成，全局仅执行一次，不可在实例方法中修改：

```csharp
static OrderController()
{
    // ===== 列表字段 =====
    ListFields.RemoveCreateField()      // 删除 CreateUser/CreateTime
              .RemoveUpdateField()      // 删除 UpdateUser/UpdateTime
              .RemoveRemarkField();     // 删除 Remark

    ListFields.RemoveField("Secret");   // 删除指定字段（支持逗号分隔多个）

    // 在 Remark 前插入自定义链接列
    {
        var df = ListFields.AddListField("detail", null, "Remark");
        df.DisplayName = "查看详情";
        df.Url = "OrderDetail?orderId={Id}";  // {Id} 自动替换为当前行实体属性值
        df.Target = "_blank";
        df.DataAction = "action";             // ajax 调用（不跳转）
    }

    // 自定义单元格值
    {
        var sf = ListFields.GetField("Status") as ListField;
        sf.GetValue = e => ((Order)e).StatusName;
        sf.GetClass = e => ((Order)e).IsOverdue ? "text-danger" : "";
        sf.DataVisible = e => ((Order)e).Amount > 0;  // 动态控制显示
    }

    // ===== 添加表单字段 =====
    AddFormFields.RemoveField("Id,CreateTime,CreateUser,UpdateTime,UpdateUser");
    AddFormFields.GetField("Title").Required = true;

    // ===== 编辑表单字段 =====
    EditFormFields.RemoveField("CreateTime,CreateUser");
    EditFormFields.AddField("AuditTime");

    // ===== 搜索字段 =====
    SearchFields.AddField("Status").Multiple = true;  // 多选下拉
    SearchFields.AddField("CreateTime");

    // ===== 详情字段 =====
    DetailFields.AddField("Remark");
}
```

### 字段操作方法速查

| 方法 | 说明 |
|------|------|
| `RemoveField(params string[])` | 删除字段，支持 `*` 模糊匹配 |
| `RemoveCreateField()` | 批量删除 CreateUser/CreateTime |
| `RemoveUpdateField()` | 批量删除 UpdateUser/UpdateTime |
| `RemoveRemarkField()` | 批量删除 Remark |
| `AddField(name)` | 从实体 AllFields 添加指定字段 |
| `AddListField(name, before, after)` | 插入自定义列表列（返回 `ListField`） |
| `AddFormField(name, before, after)` | 插入自定义表单项（返回 `FormField`） |
| `GetField(name)` | 获取字段对象（需强转为 `ListField`/`FormField` 才能访问扩展属性） |
| `Replace(oriName, newName)` | 替换字段 |

### ListField 扩展属性完整速查

```csharp
var lf = ListFields.GetField("Name") as ListField;

lf.Header       = "订单编号";           // 列头文字（覆盖 DisplayName）
lf.Url          = "/Order/Detail/{Id}"; // 单元格链接，{属性名} 自动插值
lf.Target       = "_blank";             // 链接目标
lf.TextAlign    = TextAligns.Center;    // 对齐方式
lf.Class        = "text-warning";       // 单元格 CSS 类
lf.MaxWidth     = 200;                  // 超出宽度折叠
lf.DataAction   = "action";             // "action"=ajax 调用，null=普通跳转
lf.GetValue     = e => ((Order)e).FormatAmount();               // 自定义显示值
lf.GetClass     = e => ((Order)e).IsOverdue ? "text-red" : "";  // 动态样式
lf.DataVisible  = e => ((Order)e).Amount > 0;                   // 动态可见
```

### CRUD 钩子

```csharp
// 保存前验证（新增与编辑均触发）
protected override Boolean Valid(Order entity, DataObjectMethodType type, Boolean post)
{
    if (post && entity.Amount <= 0) throw new Exception("金额必须大于0");
    return base.Valid(entity, type, post);
}

protected override void OnInsert(Order entity)
{
    entity.CreateUserId = ManageProvider.User?.ID ?? 0;
    base.OnInsert(entity);
}

protected override void OnUpdate(Order entity)
{
    entity.UpdateTime = DateTime.Now;
    base.OnUpdate(entity);
}

protected override void OnDelete(Order entity)
{
    if (entity.Status == 2) throw new Exception("已完成订单不允许删除");
    base.OnDelete(entity);
}
```

---

## ConfigController\<T\> 配置控制器

为 `Config<T>` 配置类提供 Web 查看和编辑页面。

### 最简用法（零代码）

```csharp
/// <summary>订单设置控制器</summary>
[DisplayName("订单设置")]
[OrderArea]
[Menu(0, false, Icon = "fa-cog")]
public class OrderSettingController : ConfigController<OrderSetting>
{
}
```

自动提供：
- **查看页**：按 `[Category]` 分组展示所有配置项，显示 `[Description]` 说明
- **编辑页**：表单修改值，保存时通过 `Copy + Save` 确保线程安全

### 进阶用法（自定义字段与保存逻辑）

```csharp
[DisplayName("支付设置")]
[OrderArea]
[Menu(0, false, Icon = "fa-credit-card")]
public class PaySettingController : ConfigController<PaySetting>
{
    /// <summary>执行前。定制字段展示</summary>
    public override void OnActionExecuting(ActionExecutingContext filterContext)
    {
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
    }

    /// <summary>保存后触发业务处理</summary>
    public override ActionResult Update(PaySetting obj)
    {
        var rs = base.Update(obj);
        PayService.RefreshConfig();
        return rs;
    }
}
```

### Value 属性机制

- **get**：返回 `Config<T>.Current` 单例
- **set**：调用 `cfg.Copy(value)` + `cfg.Save()`，不直接替换单例引用，确保线程安全

| 重写方法 | 用途 |
|----------|------|
| `OnActionExecuting` | 定制字段描述、设置下拉数据源、控制导航视图 |
| `Update(TConfig obj)` | 保存后执行业务逻辑（刷新缓存、通知其他服务等） |
| `GetMembers(type)` | 获取配置类成员列表，可动态修改 `Description`/`DataSource` |

---

## 视图覆盖机制

### 覆盖优先级（从高到低）

本地物理文件**始终优于**魔方嵌入式资源：

```
1. ~/Areas/{Area}/Views/{Controller}_{Theme}/{Action}.cshtml  ← 主题特定覆盖
2. ~/Areas/{Area}/Views/{Controller}/{Action}.cshtml          ← 控制器覆盖
3. ~/Areas/{Area}/Views/{Theme}/{Action}.cshtml               ← 主题共享覆盖
4. ~/Areas/{Area}/Views/Shared/{Action}.cshtml                ← 区域共享覆盖
5. ~/Views/{Theme}/{Action}.cshtml                            ← 应用级主题覆盖
6. ~/Views/Shared/{Action}.cshtml                             ← 应用级共享覆盖
7. 魔方程序集嵌入资源（fallback）
```

`{Theme}` 由 `CubeSetting.Current.Theme` 决定（默认 `ACE`）。

### 常见覆盖路径

```
Areas/Order/Views/Product/Index.cshtml       # 覆盖列表页
Areas/Order/Views/Shared/EditForm.cshtml     # 区域共享表单
Areas/Order/Views/Product_ACE/Index.cshtml   # 主题特定覆盖
Views/ACE/_LayoutAdmin.cshtml                # 全局布局覆盖
wwwroot/css/custom.css                       # 覆盖或新增静态资源
```

> 视图文件名含 `-` 或 `@` 时，嵌入资源中对应名称映射为 `_`（`CubeEmbeddedFileProvider` 自动反向映射）。

---

## 权限体系

> 权限位枚举（PermissionFlags）定义与基础权限标注参见 `cube.instructions.md` §7。本 skill 仅补充数据权限（多租户隔离）深度用法。

### 数据权限（多租户隔离）

```csharp
// UseCube() 内部已注册 DataScopeMiddleware，无需手动调用
var tenantId = TenantContext.CurrentId;

// 跳过数据权限过滤（超级管理员场景）
using (DataScopeContext.Disable())
{
    var all = Order.FindAll();
}
```

---

## CubeSetting 关键配置

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

## 常见陷阱

- `GetField()` 返回 `DataField` 基类，访问 `Url`/`GetValue` 等**必须强转**为 `ListField`。
- 静态构造器字段配置是全局一次性操作，**禁止在实例方法中修改**（线程不安全）。
- `[Menu]` 的 `LastUpdate` 不更新时，新增控制器的菜单项**不会触发重建**；每次改动菜单结构须更新该值。
- 区域名大小写须与文件夹名**严格一致**（`base(nameof(OrderArea).TrimEnd("Area"))` 可自动推导）。

## 推荐检查项

- [ ] 控制器标注了所属区域特性（如 `[OrderArea]`）
- [ ] 字段配置在 `static XxxController(){}` 中（非实例构造器）
- [ ] 覆盖视图路径与优先级顺序严格一致
- [ ] 自定义 Action 已标注 `[EntityAuthorize]` 或 `[AllowAnonymous]`
- [ ] 生产环境 `CubeSetting.JwtSecret` 已配置为强密钥
- [ ] 配置控制器已标注区域特性、`[DisplayName]` 和 `[Menu]`
