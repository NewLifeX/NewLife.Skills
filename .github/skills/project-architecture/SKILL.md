---
name: project-architecture
description: >
  NewLife 项目架构分层指南：从两层起步、按需渐进到三层的务实架构哲学。
  涵盖表现层（Controller）/服务层（Service）/数据层（XCode 实体）的职责划分，
  项目演进路径（单项目两层 → 数据层独立 → 按需引入服务层），
  充血模型下的跨模块数据访问规则，以及禁止薄包装等反模式。
  适用于新建项目结构选型、Service 是否需要抽取的判断、架构分层审查任务。
  包含测试策略：利用 XCode 多数据库抽象实现 SQLite 轻量集成测试，
  零架构侵入地测试 Service 和实体 Biz 方法，避免为测试而包装虚方法。
  详细测试指南参见 `testing-strategy` 技能。
argument-hint: >
  说明项目阶段：新建项目/项目增长需要拆分/需要判断是否引入 Service 层；
  描述当前项目规模（数据表数量、入口应用数量）。
---

# NewLife 项目架构分层

## 适用场景

- 新建项目时选择合适的分层结构（两层 or 三层）。
- 项目增长后判断何时拆分数据层、何时引入服务层。
- 审查现有项目的架构分层是否合理。
- 判断某段业务逻辑应该放在 Controller 还是 Service 中。
- 评估是否需要为实体查询方法创建 Service 包装。

## 核心理念

**务实渐进，按需分层。** NewLife 体系不追求"标准三层"的形式完整，而是根据项目实际复杂度选择最简分层：

1. **两层起步**：小项目从接口层 + 数据层开始，不提前创建服务层。
2. **按需演进**：业务逻辑变复杂、需要跨 Controller 共用时，才抽取 Service。
3. **混合分层是常态**：同一项目内，简单模块保持两层，复杂模块升级三层，完全正常。
4. **充血模型**：XCode 实体类 = 数据层，Biz 文件封装查询、增删改及实体业务方法，不需要 Repository 层。
5. **跨模块直接访问**：任意代码可直接调用任何实体的查询方法，不必经过目标模块的 Service 中转。

## 三层定义

| 层级 | 传统术语 | NewLife 对应 | 代码位置 | 职责 |
|------|---------|------------|---------|------|
| **接口层** / 表现层 | Presentation Layer | Controller（WebAPI / MVC） | `Controllers/` 或 `Areas/` | 接收请求、参数校验、调用业务逻辑、返回响应 |
| **服务层** / 业务逻辑层 | Business Logic Layer | XxxService | `Services/` | 复杂业务编排、跨实体协调、需要共用的业务逻辑 |
| **数据层** / 数据访问层 | Data Access Layer | XCode 实体类 + Biz 文件 | `Entities/` 或独立 `.Data` 项目 | 增删改查、查询封装、实体级业务方法 |

**关键区别**：在传统三层架构中，数据层通常是轻量 Repository + DAO；而在 NewLife 体系中，XCode 实体类是**充血模型**，实体的 Biz 文件封装了查询方法（`FindByXxx`/`FindAllByXxx`/`Search`）、增删改操作以及实体级业务方法（如 `Refresh`/`Fix`），数据层本身就具备完整的数据访问和实体业务能力，不需要再包一层 Repository。

## 项目演进路径

### 阶段 1：单项目两层（起步）

适用于：新项目、小型项目、原型验证、数据表较少（≤ 20 张）。

```
MyApp/
├── Controllers/           # 接口层：Controller 直接调用实体方法
│   ├── UserController.cs
│   └── OrderController.cs
├── Entities/              # 数据层：model.xml + 实体类
│   ├── Model.xml
│   ├── 用户.cs            # 自动生成（勿手动修改）
│   ├── 用户.Biz.cs        # 业务查询方法
│   ├── 订单.cs
│   └── 订单.Biz.cs
├── Program.cs
└── appsettings.json
```

此阶段 Controller 直接调用实体类的静态查询方法，简单的业务逻辑也直接写在 Controller 中：

```csharp
[ApiController]
[Route("[controller]")]
public class OrderController : ControllerBase
{
    [HttpGet]
    public IList<Order> Search(Int32 userId, String? key, [FromQuery] PageParameter page)
    {
        // ✅ 接口层直接调用数据层，两层结构
        return Order.Search(userId, key, page);
    }

    [HttpPost]
    public Order Create([FromBody] Order model)
    {
        // ✅ 简单业务逻辑直接在 Controller 中处理
        model.Status = OrderStatus.Created;
        model.Insert();
        return model;
    }
}
```

### 阶段 2：数据层独立（增长期）

以下任一条件满足时，将实体类拆到独立的 `.Data` 类库项目：

- **数据表增多**：实体文件占据了主项目大量空间，影响关注点分离。
- **多入口应用**：需要多个应用程序（Web、Server、Jobs）访问同一数据库。
- **团队协作**：多人开发时，数据层独立便于并行工作。

数据层项目内部的**模块划分方式**取决于数据表数量和业务复杂度，从简单到复杂有以下几种组织形式：

**形式 A：单 xml + 子目录分类实体（小型项目，≤ 30 张表）**

```
MyApp.Data/
├── Model.xml              # 单个 xml 管理所有表
├── Users/                 # 按模块子目录存放实体类
│   ├── 用户.cs / 用户.Biz.cs
│   └── 角色.cs / 角色.Biz.cs
├── Orders/
│   ├── 订单.cs / 订单.Biz.cs
│   └── 订单明细.cs / 订单明细.Biz.cs
└── MyApp.Data.csproj
```

**形式 B：每个模块子目录有独立 xml（中型项目，30-100 张表）**

```
MyApp.Data/
├── Users/
│   ├── Model.xml          # 用户模块自己的模型文件
│   ├── 用户.cs / 用户.Biz.cs
│   └── 角色.cs / 角色.Biz.cs
├── Orders/
│   ├── Model.xml          # 订单模块自己的模型文件
│   ├── 订单.cs / 订单.Biz.cs
│   └── 订单明细.cs / 订单明细.Biz.cs
└── MyApp.Data.csproj
```

**形式 C：模块子目录 + 多 xml + 二级子目录（大型项目，100+ 张表）**

```
MyApp.Data/
├── Device/
│   ├── Device.xml         # 设备核心表
│   ├── DeviceLog.xml      # 设备日志表（表多时拆分 xml）
│   ├── Core/              # 二级子目录：设备核心实体
│   │   ├── 设备.cs / 设备.Biz.cs
│   │   └── 产品.cs / 产品.Biz.cs
│   └── Log/               # 二级子目录：设备日志实体
│       ├── 设备日志.cs / 设备日志.Biz.cs
│       └── 设备数据.cs / 设备数据.Biz.cs
├── Trade/
│   ├── Model.xml
│   └── ...
└── MyApp.Data.csproj
```

**选择原则**：具体分几层取决于数据表的数量规模和模块划分粒度。小项目甚至可以不分子目录，所有实体平铺在 `.Data` 根目录下。随着表增多逐步调整，不必一开始就设计复杂目录。

**多入口应用共享数据层**：

```
MyApp.Data/                # 数据层独立类库（多入口共享）

MyApp.Web/                 # Web 应用 → 引用 MyApp.Data
├── Controllers/
├── Program.cs
└── MyApp.Web.csproj

MyApp.Server/              # 设备服务 → 引用 MyApp.Data
├── Handlers/
├── Program.cs
└── MyApp.Server.csproj

MyApp.Jobs/                # 后台任务 → 引用 MyApp.Data
├── Services/
├── Program.cs
└── MyApp.Jobs.csproj
```

**项目命名约定**：

| 项目类型 | 命名格式 | 示例 |
|---------|---------|------|
| 数据层类库 | `{Project}.Data` | `Zero.Data`、`IoT.Data` |
| Web 应用 | `{Project}.Web` | `Zero.Web`、`IoT.Web` |
| 设备/网络服务 | `{Project}.Server` | `IoT.Server` |
| 后台任务服务 | `{Project}.Jobs` | `Zero.Jobs` |

### 阶段 3：按需引入服务层

当以下条件出现时，**逐步**抽取 Service：

- 多个 Controller 需要**共用同一段业务逻辑**。
- 业务逻辑涉及**跨实体编排**（如创建订单同时扣减库存、发送通知）。
- 单个 Controller Action 的业务逻辑**过于复杂**（超过 30-50 行），影响可读性。
- 需要对业务逻辑进行**单元测试**，而 Controller 难以隔离测试。

```
MyApp.Web/
├── Controllers/
│   ├── UserController.cs      # 简单模块：直接调用实体（两层）
│   └── OrderController.cs     # 复杂模块：调用 OrderService（三层）
├── Services/
│   └── OrderService.cs        # 仅复杂模块才有 Service
├── Program.cs
└── MyApp.Web.csproj
```

**服务层 DI 注册**：

```csharp
// Program.cs 或 AddXxx 扩展方法中注册
builder.Services.AddSingleton<OrderService>();
builder.Services.AddSingleton<NotificationService>();
```

**Service 示例**（有实际业务编排价值）：

```csharp
/// <summary>订单服务。处理订单创建、支付、取消等复杂业务流程</summary>
public class OrderService
{
    private readonly NotificationService _notification;

    /// <summary>实例化</summary>
    /// <param name="notification">通知服务</param>
    public OrderService(NotificationService notification) => _notification = notification;

    /// <summary>创建订单。校验库存、生成订单、扣减库存、发送通知</summary>
    /// <param name="userId">用户编号</param>
    /// <param name="items">商品项列表</param>
    /// <returns>创建成功的订单</returns>
    public Order CreateOrder(Int32 userId, IList<OrderItem> items)
    {
        // 校验库存
        foreach (var item in items)
        {
            var product = Product.FindByKey(item.ProductId);
            if (product == null) throw new ArgumentException($"商品 {item.ProductId} 不存在");
            if (product.Stock < item.Quantity) throw new InvalidOperationException($"商品 {product.Name} 库存不足");
        }

        // 创建订单
        var order = new Order
        {
            UserId = userId,
            Status = OrderStatus.Created,
            TotalAmount = items.Sum(e => e.Price * e.Quantity),
        };
        order.Insert();

        // 创建明细并扣减库存
        foreach (var item in items)
        {
            item.OrderId = order.Id;
            item.Insert();

            var product = Product.FindByKey(item.ProductId);
            product.Stock -= item.Quantity;
            product.Update();
        }

        // 发送通知
        _notification.SendOrderCreated(order);

        return order;
    }
}
```

## 混合分层是常态

在同一个项目中，不同模块可以有不同的分层深度，这是**正常且推荐**的状态：

```csharp
// ========== 简单模块：两层（Controller → 实体）==========

/// <summary>用户标签管理。简单 CRUD，无复杂业务逻辑</summary>
[ApiController]
[Route("[controller]")]
public class TagController : ControllerBase
{
    [HttpGet]
    public IList<Tag> GetByUser(Int32 userId) => Tag.FindAllByUserId(userId);

    [HttpDelete("{id}")]
    public Boolean Delete(Int32 id)
    {
        var tag = Tag.FindByKey(id);
        return tag?.Delete() > 0;
    }
}

// ========== 复杂模块：三层（Controller → Service → 实体）==========

/// <summary>订单管理。涉及库存、支付、通知等多实体编排</summary>
[ApiController]
[Route("[controller]")]
public class OrderController : ControllerBase
{
    private readonly OrderService _orderService;

    public OrderController(OrderService orderService) => _orderService = orderService;

    [HttpPost]
    public Order Create(Int32 userId, [FromBody] IList<OrderItem> items)
        => _orderService.CreateOrder(userId, items);
}
```

**判断标准**：如果一个模块的 Controller Action 只需要调用一两个实体方法就能完成，就保持两层；如果需要协调多个实体、包含复杂流程，就抽取 Service。

## 跨模块数据访问规则

**核心原则：任意层的代码都可以直接访问任何模块的数据层（实体类），不需要经过目标模块的 Service 中转。**

```csharp
// ✅ 订单 Service 直接访问用户模块的实体
public class OrderService
{
    public Order CreateOrder(Int32 userId, ...)
    {
        // 直接调用 User 实体的查询方法，不需要 UserService 中转
        var user = User.FindByKey(userId);
        if (user == null) throw new ArgumentException("用户不存在");
        // ...
    }
}

// ✅ 用户 Controller 直接访问订单模块的实体
[HttpGet("orders")]
public IList<Order> GetMyOrders()
{
    var userId = GetCurrentUserId();
    return Order.FindAllByUserId(userId);
}
```

**原因**：XCode 实体类是充血模型，查询方法已经封装在 Biz 文件中，调用 `Entity.FindByXxx()` 就是最简洁最直接的数据访问方式。如果强制要求"通过目标模块的 Service 访问"，只会多一层无意义的中转。

## 反模式清单

### ❌ 薄包装 Service

Service 方法只是简单透传到数据层，没有附加任何业务逻辑：

```csharp
// ❌ 多此一举：Service 方法只是转发到实体查询
public class QueueService
{
    public IList<CuriosityQueue> GetQueueByUserId(Int32 userId)
        => CuriosityQueue.FindAllByUserId(userId);

    public CuriosityQueue? GetById(Int32 id)
        => CuriosityQueue.FindByKey(id);
}

// ❌ 同样多余：用 virtual 方法包装数据层调用
protected virtual IList<CuriosityQueue> GetQueueByUserId(Int32 userId)
    => CuriosityQueue.FindAllByUserId(userId);
```

**正确做法**：直接在调用处使用实体查询方法。

```csharp
// ✅ 直接调用
var queues = CuriosityQueue.FindAllByUserId(userId);
var queue = CuriosityQueue.FindByKey(id);
```

**判断标准**：如果一个 Service 方法的实现是 `return Entity.FindXxx(...)` 一行代码，且没有附加校验、转换、缓存等逻辑，那就不需要这个 Service 方法。

### ❌ 强制三层

项目刚起步就创建完整的三层目录和空 Service 类：

```
// ❌ 新项目就搞出这种结构
MyApp/
├── Controllers/
│   └── UserController.cs
├── Services/
│   ├── IUserService.cs       # 接口只有 2 个方法
│   └── UserService.cs        # 实现只是转发到实体
├── Repositories/             # 完全多余
│   ├── IUserRepository.cs
│   └── UserRepository.cs
└── Entities/
```

**正确做法**：从两层开始，等确实需要时才创建 `Services/` 目录。

### ❌ "数据服务层" 二次封装

在实体查询方法之上再包一层"数据服务"：

```csharp
// ❌ 在 Service 和 Entity 之间又加了一层
public class UserDataService
{
    public User? GetById(Int32 id) => User.FindByKey(id);
    public IList<User> GetAll() => User.FindAll();
    public IList<User> Search(String key, PageParameter page) 
        => User.Search(key, page);
}

public class UserService
{
    private readonly UserDataService _dataService;  // 通过"数据服务"访问
    // ...
}
```

**原因**：XCode 实体 Biz 文件已经是数据层，它既是"数据服务"也是"Repository"。再包一层只是制造冗余。

### ❌ 强制跨模块通过 Service 中转

```csharp
// ❌ 为了"解耦"而绕路
public class OrderService
{
    private readonly UserService _userService;  // 注入 UserService

    public Order CreateOrder(Int32 userId, ...)
    {
        var user = _userService.GetById(userId);  // 通过 Service 间接访问
        // ...
    }
}

// UserService 内部只是转发
public User? GetById(Int32 id) => User.FindByKey(id);
```

```csharp
// ✅ 直接调用目标模块的实体
public class OrderService
{
    public Order CreateOrder(Int32 userId, ...)
    {
        var user = User.FindByKey(userId);  // 直接访问
        // ...
    }
}
```

### ❌ 为测试而包装数据访问

在 Service 中将所有实体调用包装为 virtual 方法，仅为方便单元测试时 override：

```csharp
// ❌ 为测试而改架构
public class OrderService
{
    protected virtual Product? FindProduct(Int32 id) => Product.FindByKey(id);
    protected virtual void InsertOrder(Order order) => order.Insert();
    protected virtual void UpdateProduct(Product product) => product.Update();

    public Order CreateOrder(Int32 userId, IList<OrderItem> items)
    {
        var product = FindProduct(items[0].ProductId);  // 间接调用
        // ...
    }
}

// 测试时 override
public class TestOrderService : OrderService
{
    private readonly Dictionary<Int32, Product> _fakeProducts = new();
    protected override Product? FindProduct(Int32 id) => _fakeProducts.GetValueOrDefault(id);
    // ... 每个数据访问都要 override
}
```

**问题**：本质是薄包装反模式的变体。每新增一个数据访问点就要加一个 virtual 方法，测试类也要同步扩展。而且 mock 出来的测试无法验证真实的查询逻辑（条件拼错、排序错误、分页 Bug 全部发现不了）。

**正确做法**：使用 SQLite 集成测试，零架构侵入。详见 `testing-strategy` 技能。

## 何时创建 Service

符合以下**任一**条件时，才需要创建 XxxService：

| 条件 | 示例 |
|------|------|
| **跨实体编排** | 创建订单同时扣库存、记日志、发通知 |
| **多处共用** | 多个 Controller 或多个入口项目都需要同一段逻辑 |
| **复杂流程** | 状态机、审批流、多步骤事务 |
| **外部集成** | 调用第三方 API、消息队列发送 |
| **需要注入依赖** | 依赖 ICache、ITracer、其他 Service |
| **单元测试需求** | 业务逻辑需要独立于 HTTP 上下文进行测试 |

**不需要创建 Service 的场景**：

| 场景 | 做法 |
|------|------|
| 简单 CRUD | Controller 直接调用实体方法 |
| 单实体查询 + 返回 | Controller 直接调用 `Entity.FindXxx` / `Entity.Search` |
| 简单字段校验 | 写在实体的 `Valid` 钩子中 |
| 数据格式转换 | 写在 Controller 的 Action 方法中 |
| 为了单元测试 mock | 用 SQLite 集成测试代替 mock，不需要 Service 包装 |

## Service 层独立类库（进阶）

当多个入口应用需要共用同一套复杂业务逻辑时，可以将 Service 层拆成独立类库：

```
MyApp.Data/                # 数据层
MyApp.Service/             # 服务层（独立类库，引用 MyApp.Data）
MyApp.Web/                 # Web 应用（引用 MyApp.Service）
MyApp.Server/              # 设备服务（引用 MyApp.Service）
```

**注意**：这种情况比较少见。大多数时候，各入口项目直接引用 `.Data`，各自在自己项目内创建所需的 Service 就够了。只有当多个入口项目确实有大量共用的复杂业务逻辑时，才需要独立服务层类库。

## AI 编码指引

AI 在为 NewLife 项目编写代码时，应遵循以下决策流程：

### 决策流程

```
收到编码任务
    │
    ├─ 是否需要查询/操作数据库？
    │   ├─ 是 → 检查实体 Biz 文件是否已有对应方法
    │   │   ├─ 已有 → 直接调用
    │   │   └─ 没有 → 在 Biz 文件中新增查询方法（参见 xcode-entity-orm 技能）
    │   └─ 否 → 继续
    │
    ├─ 业务逻辑是否简单（≤ 15 行，单实体操作）？
    │   ├─ 是 → 直接写在 Controller 中
    │   └─ 否 → 继续
    │
    ├─ 是否涉及跨实体编排 / 多处共用 / 外部集成？
    │   ├─ 是 → 创建或使用 XxxService
    │   └─ 否 → 逻辑虽长但是单模块内部的，可以写在 Controller 中
    │
    └─ 是否需要访问其他模块的数据？
        └─ 直接调用目标实体的查询方法，不要创建中转 Service
```

### 禁止事项

- **禁止**为每个实体自动创建对应的 IXxxService / XxxService。
- **禁止**创建只有一行 `return Entity.FindXxx()` 的 Service 方法。
- **禁止**为"解耦"而强制跨模块通过 Service 中转访问数据层。
- **禁止**在新项目中预创建空的 `Services/` 目录和空 Service 类。
- **禁止**在实体查询方法之上再包一层"数据服务" / "Repository"。

### 推荐做法

- **优先**让 Controller 直接调用实体查询方法。
- **优先**在实体 Biz 文件中封装新的查询方法，而不是在 Service 中拼 `WhereExpression`。
- Service 有实际业务编排价值时才创建，创建后通过 DI 注册供 Controller 使用。
- 多个入口项目共享数据时，优先拆分 `.Data` 类库；共享业务逻辑时，才考虑拆分 `.Service` 类库。

## 与主流架构的对比

| 主流做法 | NewLife 做法 | 原因 |
|---------|------------|------|
| Repository + Service + Controller | Entity（Biz）+ Controller，需要时加 Service | XCode 实体充血模型已涵盖 Repository 职责 |
| 完整三层从项目初始就创建 | 两层起步，按需引入 Service | 避免过度设计，保持代码简洁 |
| Service 层封装所有数据访问 | 接口层和服务层都可直接调用实体 | 充血模型下薄包装是冗余 |
| 跨模块通过接口调用 | 直接调用目标实体的查询方法 | 实体查询方法本身就是稳定的公共 API |
| 数据层 ↔ 服务层 ↔ 接口层单向依赖 | 接口层和服务层都直接依赖数据层 | 简化调用链，减少不必要的间接层 |
| 每个模块严格封装、只暴露 Service | 任意代码可访问任意实体 | NewLife 实体是全局可用的充血模型 |
| 为测试而包装虚方法/注入接口 | SQLite 集成测试，零架构侵入 | XCode 多数据库抽象天然支持测试库切换 |

**NewLife 的选择不是"偷懒"，而是基于 XCode 充血模型的务实决策**。当数据层本身就具备完整的查询封装能力时，再加一层只为转发的 Service/Repository 就是纯粹的冗余。

## 测试策略

**不为测试改架构**。XCode 未配置连接字符串时自动创建同名 SQLite 数据库（`Migration=On` 自动建表），Service/Biz 代码不改一行即可用 SQLite 跑真实查询。

| 对比维度 | 虚方法 Mock 方案 | SQLite 集成测试（推荐） |
|---------|----------------|----------------------|
| 架构侵入 | 包装所有数据访问为虚方法 | **零侵入**，代码不改 |
| 测试真实度 | 只验证调用关系 | **验证真实 SQL 执行结果** |
| Bug 发现能力 | 无法发现查询条件/排序错误 | **能发现** |
| 维护成本 | 每新增实体方法需同步 mock | **零维护** |

完整指南（代码示例、隔离方式、决策树、反模式清单）参见 `testing-strategy` 技能。

## 注意事项

- 架构分层的核心目的是**管理复杂度**，不是追求形式完整。两层够用就不要三层。
- Service 的出现应该是**自然演进**的结果，而不是提前规划的产物。
- 同一项目内不同模块分层深度不同是**正常状态**，不需要强行统一。
- 数据层查询方法的封装规范请参见 `xcode-entity-orm` 技能（Biz 文件约定）。
- 项目模板和目录创建请参见 `cube-mvc-backend` 技能（快速启动）。
- Service 的 DI 注册模式请参见 `dependency-injection` / `dependency-injection-ioc` 技能。
