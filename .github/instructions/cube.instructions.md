# Cube 协作指令

本指令面向新生命团队（NewLife）开源 Web 快速开发框架 Cube（魔方），帮助 Copilot 在 .NET 项目中正确使用 Cube 进行 Web 管理后台开发。

---

## 1. Cube 定位与边界

### 1.1 技术栈定位

```
NewLife.Core（基础库）
       ↓
   NewLife.XCode（数据中间件）→ xcode.instructions.md
       ↓
   NewLife.Cube（Web 快速开发框架）← 本指令
```

### 1.2 职责边界

| 层级 | 职责 | 指令文件 |
|------|------|---------|
| **NewLife.XCode** | 数据建模、ORM、实体增删改查 | `xcode.instructions.md` |
| **NewLife.Cube** | Web 管理后台、控制器、视图、权限、菜单 | 本指令 |

### 1.3 本指令覆盖范围

**包含**：
- Web 控制器开发与定制
- 列表页、表单页、详情页配置
- 菜单与权限管理
- 魔方区域（Area）管理

**不包含**（由 xcode.instructions.md 负责）：
- 数据模型设计（Model.xml）
- 实体类生成
- 数据库 CRUD 底层操作

---

## 2. 快速开始

### 2.1 创建 Cube 项目

```powershell
# 安装模板
dotnet new install NewLife.Templates

# 创建 Web 项目
dotnet new cube -n {系统名}Web

# 添加数据类库引用
dotnet add reference ../Zero.Data/Zero.Data.csproj
```

### 2.2 自动生成控制器

在 Model.xml 中配置 `CubeOutput` 后，执行 `xcode` 会自动生成区域类和控制器：

```xml
<Option>
  <DisplayName>订单管理</DisplayName>
  <CubeOutput>../../OrderWeb/Areas/Order</CubeOutput>
</Option>
```

---

## 3. 控制器开发

### 3.1 控制器基类

| 基类 | 用途 |
|------|------|
| `EntityController<T>` | 标准 CRUD 控制器 |
| `ReadOnlyEntityController<T>` | 只读控制器（日志表等） |
| `ConfigController<T>` | 配置类查看与编辑控制器 |

### 3.2 控制器结构

```csharp
[Menu(100, true, Icon = "fa-table")]
[OrderArea]
public class OrderController : EntityController<Order>
{
    static OrderController()
    {
        // 列表字段配置
        ListFields.RemoveCreateField().RemoveRemarkField();

        // 添加自定义链接列（注意：防御性注释不得删除）
        //{
        //    var df = ListFields.AddListField("details", null, "Remark");
        //    df.DisplayName = "查看明细";
        //    df.Url = "OrderDetail?orderId={Id}";
        //}
    }

    /// <summary>高级搜索</summary>
    protected override IEnumerable<Order> Search(Pager p)
    {
        var start = p["dtStart"].ToDateTime();
        var end = p["dtEnd"].ToDateTime();
        var key = p["Q"] + "";

        return Order.Search(start, end, key, p);
    }
}
```

### 3.3 菜单配置

```csharp
[Menu(100, true, Icon = "fa-table")]
```

| 参数 | 说明 |
|------|------|
| 第一个参数 | 菜单排序（数字越大越靠前） |
| 第二个参数 | 是否可见 |
| `Icon` | Font Awesome 图标 |
| `LastUpdate` | 日期字符串，菜单结构有改动时更新以触发重建 |

---

## 4. 列表页配置

### 4.1 ListFields 配置

```csharp
static OrderController()
{
    // 移除字段
    ListFields.RemoveCreateField();   // 移除创建者/创建时间
    ListFields.RemoveUpdateField();   // 移除更新者/更新时间
    ListFields.RemoveRemarkField();   // 移除备注
    ListFields.RemoveField("Secret"); // 移除指定字段

    // 添加链接列
    {
        var df = ListFields.GetField("OrderNo") as ListField;
        df.Url = "Order/Detail?id={Id}";
        df.Target = "_blank";
    }

    // 添加操作列（带可见性判断）
    {
        var df = ListFields.AddListField("details", null, "Remark");
        df.DisplayName = "查看明细";
        df.Url = "OrderDetail?orderId={Id}";
        df.DataVisible = e => (e as Order).Details > 0;
    }
}
```

### 4.2 ListField 扩展属性

| 属性 | 说明 |
|------|------|
| `Header` | 列头文字（覆盖 DisplayName） |
| `Url` | 单元格链接，`{属性名}` 自动插值 |
| `Target` | 链接目标（`_blank` 等） |
| `DataAction` | `"action"` = ajax 调用，`null` = 普通跳转 |
| `GetValue` | 自定义单元格值（委托） |
| `GetClass` | 动态 CSS 类（委托） |
| `DataVisible` | 动态控制是否显示（委托） |
| `TextAlign` | 对齐方式 |

---

## 5. 表单页配置

### 5.1 FormFields 配置

```csharp
static OrderController()
{
    // 新增表单
    AddFormFields.RemoveField("Id,CreateTime,CreateUser,UpdateTime,UpdateUser");
    AddFormFields.GetField("Title").Required = true;

    // 编辑表单
    EditFormFields.RemoveField("CreateTime,CreateUser");
    EditFormFields.AddField("AuditTime");
}
```

---

## 6. 区域（Area）管理

### 6.1 区域类

```csharp
[DisplayName("订单管理")]
[Menu(50, true, Icon = "fa-shopping-cart", LastUpdate = "20240601")]
public class OrderArea : AreaBase
{
    public OrderArea() : base(nameof(OrderArea).TrimEnd("Area")) { }
}
```

### 6.2 目录结构

```
Areas/
└── Order/
    ├── OrderArea.cs
    └── Controllers/
        ├── OrderController.cs
        └── OrderDetailController.cs
```

---

## 7. 权限管理

### 7.1 PermissionFlags

| 值 | 含义 |
|----|------|
| `Detail` (0x01) | 查看 |
| `Insert` (0x02) | 新增 |
| `Update` (0x04) | 编辑 |
| `Delete` (0x08) | 删除 |
| `Approve` (0x10) | 审批 |
| `Export` (0x20) | 导出 |

### 7.2 权限标注

```csharp
// 自定义 Action 需手动标注
[EntityAuthorize(PermissionFlags.Approve)]
public ActionResult Approve(Int32 id) { ... }

// 允许匿名
[AllowAnonymous]
public ActionResult Public() { ... }
```

---

## 8. CRUD 钩子

```csharp
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

protected override void OnDelete(Order entity)
{
    if (entity.Status == 2) throw new Exception("已完成订单不允许删除");
    base.OnDelete(entity);
}
```

---

## 9. 与 XCode 的协作

1. **数据模型**：在 `xcode.instructions.md` 指导下设计 Model.xml
2. **控制器生成**：配置 `CubeOutput` 后执行 `xcode` 自动生成区域类和控制器
3. **定制开发**：在生成的控制器基础上进行业务定制
4. **字段显示**：通过 Model.xml 的 `ShowIn`、`ItemType`、`Category` 控制

深度定制（ConfigController、视图覆盖、搜索扩展）参见 `cube-mvc-backend` skill。

---

## 10. Copilot 行为指引

1. 继承正确的基类（`EntityController` 或 `ReadOnlyEntityController`）
2. 在静态构造函数中配置 `ListFields`
3. 重写 `Search` 方法实现高级搜索
4. 数据模型和实体操作 → `xcode.instructions.md`；Web 控制器和界面 → 本指令
5. 生成代码后：检查控制器是否正确引用实体类、区域类是否正确注册
