---
name: testing-strategy
description: >
  NewLife/XCode 项目的测试策略指南：利用 XCode 多数据库抽象实现 SQLite 轻量集成测试，
  零架构侵入地测试 Service 和实体 Biz 方法，避免为测试而包装虚方法。
  涵盖 SQLite 自动建表机制、事务回滚隔离、独立数据库文件隔离、纯业务逻辑单元测试，
  以及测试策略决策树和测试反模式清单。
  适用于为 XCode 实体或 Service 编写测试、评估测试方案选型、审查测试代码质量等任务。
argument-hint: >
  说明测试目标：测试 Service 方法 / 测试实体 Biz 查询 / 测试纯业务逻辑；
  描述当前困难（如静态方法无法 mock、不想改架构等）。
---

# NewLife/XCode 测试策略

## 适用场景

- 为 Service 或实体 Biz 方法编写测试，不知道如何处理 XCode 静态方法。
- 评估是否需要为测试而引入 mock 框架或包装虚方法。
- 审查现有测试代码是否符合 NewLife 体系的最佳实践。
- 需要在 CI 环境中运行测试，不依赖外部数据库。

## 核心原则

**不为测试改架构。** 利用 XCode 的多数据库抽象能力，用 SQLite 做"轻量集成测试"——Service/Biz 代码不改一行，真实执行数据库查询，比 mock 测试质量更高。

## 问题：静态方法如何测试？

XCode 实体类的查询方法是**静态方法**（`User.FindByKey(id)`、`Order.Search(...)`），Service 也直接调用这些静态方法。传统做法是将所有数据访问包装为虚方法或接口，以便在测试中 mock/override。**在 NewLife 体系中不推荐这种做法**，原因：

1. **包装虚方法 = 薄包装反模式**，架构为测试服务而非为业务服务。
2. **Mock 测试只验证调用关系**，无法发现真实的查询 Bug（条件拼错、字段遗漏、排序错误）。
3. **维护成本递增**，每新增一个实体方法就要同步更新 mock。

### ❌ 反模式：为测试而包装数据访问

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

## 推荐方案：SQLite 轻量集成测试

XCode 天然支持多数据库切换，且**未配置连接字符串时自动创建同名 SQLite 数据库**（`Migration=On` 自动建表）。利用这一点，测试时无需 mock，直接用 SQLite 运行真实查询：

```csharp
/// <summary>订单服务测试</summary>
public class OrderServiceTests
{
    [Fact]
    [DisplayName("创建订单扣减库存")]
    public void CreateOrder_StockDecreased()
    {
        // Arrange — 准备测试数据（SQLite 自动建表）
        var product = new Product { Name = "测试商品", Stock = 100, Price = 50 };
        product.Insert();

        var service = new OrderService(new NotificationService());
        var items = new List<OrderItem>
        {
            new() { ProductId = product.Id, Quantity = 3, Price = 50 }
        };

        // Act — 直接调用 Service，走真实数据路径
        var order = service.CreateOrder(1, items);

        // Assert
        Assert.True(order.Id > 0);
        Assert.Equal(150, order.TotalAmount);

        // 验证库存扣减（从数据库重新读取）
        var updated = Product.FindByKey(product.Id);
        Assert.Equal(97, updated.Stock);
    }
}
```

**核心优势**：Service 代码不改一行，Entity 静态方法原样工作，走真实 SQL 到 SQLite。

## 方案对比

| 对比维度 | 虚方法 Mock 方案 | SQLite 集成测试（推荐） |
|---------|----------------|----------------------|
| 架构侵入 | 需要包装所有数据访问为虚方法 | **零侵入**，代码不改 |
| 测试真实度 | 只验证调用关系，不验证查询逻辑 | **验证真实 SQL 执行结果** |
| 维护成本 | 每新增实体方法需同步 mock | **零维护**，实体变更测试自动适应 |
| Bug 发现能力 | 无法发现查询条件/排序/分页错误 | **能发现**（走真实查询路径） |
| 运行速度 | 最快（纯内存） | 快（SQLite 进程内，毫秒级） |

## 测试隔离方式

### 方式 1：事务回滚（推荐，最简单）

```csharp
[Fact]
[DisplayName("创建订单完整流程")]
public void CreateOrder_FullProcess()
{
    using var et = new EntityTransaction<Order>();
    try
    {
        // 准备数据
        var product = new Product { Name = "测试商品", Stock = 100, Price = 50 };
        product.Insert();

        // 执行业务
        var service = new OrderService(new NotificationService());
        var order = service.CreateOrder(1, [new() { ProductId = product.Id, Quantity = 3, Price = 50 }]);

        // 验证
        Assert.True(order.Id > 0);
        // 不调用 et.Commit()，using 结束自动回滚
    }
    catch { throw; }
}
```

### 方式 2：每个测试类独立 SQLite 文件

```csharp
/// <summary>数据测试基类。每个测试类使用独立 SQLite 文件，避免并行冲突</summary>
public abstract class DataTestBase : IDisposable
{
    protected DataTestBase()
    {
        var dbFile = $"test_{GetType().Name}.db";
        DAL.AddConnStr("Test", $"Data Source={dbFile}", null, "SQLite");
    }

    public void Dispose()
    {
        var dbFile = $"test_{GetType().Name}.db";
        if (File.Exists(dbFile)) File.Delete(dbFile);
    }
}
```

### 方式 3：appsettings.Test.json 配置

```json
{
  "ConnectionStrings": {
    "Order": "Data Source=test_order.db",
    "Log": "Data Source=test_log.db"
  }
}
```

## 纯业务逻辑的独立测试

不涉及数据库的纯计算/校验逻辑，仍然使用经典单元测试（直接 new 对象调用）：

```csharp
// Service 中的纯业务方法
public class PriceService
{
    /// <summary>计算折扣价</summary>
    /// <param name="price">原价</param>
    /// <param name="level">会员等级</param>
    /// <returns>折扣后价格</returns>
    public Decimal CalculateDiscount(Decimal price, Int32 level) => level switch
    {
        >= 5 => price * 0.8m,
        >= 3 => price * 0.9m,
        _ => price,
    };
}

// 纯单元测试（不需要数据库）
[Theory]
[InlineData(100, 5, 80)]
[InlineData(100, 3, 90)]
[InlineData(100, 1, 100)]
[DisplayName("折扣计算")]
public void CalculateDiscount_ByLevel(Decimal price, Int32 level, Decimal expected)
{
    var service = new PriceService();
    Assert.Equal(expected, service.CalculateDiscount(price, level));
}
```

## 测试策略决策树

```
需要测试的代码
    │
    ├─ 纯计算/校验逻辑（不访问数据库）
    │   └─ 经典单元测试（直接 new 对象调用）
    │
    ├─ 实体 Biz 方法（FindByXxx/Search/Valid）
    │   └─ SQLite 集成测试（自动建表 + 真实查询）
    │
    ├─ Service 方法（跨实体编排）
    │   └─ SQLite 集成测试（真实 Service + 真实数据层）
    │
    └─ Controller Action（HTTP 级别）
        └─ 通常不需要单独测试，业务逻辑已在 Service/Biz 中覆盖
```

## 测试反模式

| 反模式 | 问题 | 正确做法 |
|--------|------|---------|
| 为测试包装虚方法 | 架构侵入，薄包装反模式 | SQLite 集成测试 |
| Mock 所有实体调用 | 无法验证真实查询，维护成本高 | 直接用 SQLite 跑真实查询 |
| 测试数据硬编码 ID | 自增 ID 不可预测 | 先 Insert 再用返回对象的 Id |
| 所有测试共用一个数据库 | 并行执行时数据冲突 | 每个测试类独立 SQLite 文件或事务回滚 |
| 跳过数据层测试 | Biz 查询方法是核心资产 | 对关键查询方法编写集成测试 |

## AI 编码指引

AI 在为 NewLife 项目编写测试时，应遵循以下规则：

### 禁止事项

- **禁止**为了方便测试而在 Service 中包装 virtual 数据访问方法。
- **禁止**引入 Moq/NSubstitute 等 mock 框架来 mock XCode 实体静态方法。
- **禁止**在测试中硬编码自增 ID（应先 Insert 再使用返回的 Id）。
- **禁止**多个测试类共用同一个 SQLite 文件而不做隔离。

### 推荐做法

- **优先**使用 SQLite 集成测试，让 XCode 自动建表。
- **优先**使用事务回滚做测试隔离。
- 纯计算逻辑用经典单元测试，不需要数据库。
- 测试类名 `{ClassName}Tests`，测试方法加 `[DisplayName("中文描述意图")]`。
- 网络端口用 `0`/随机，IO 用临时目录。

## 相关技能

- 项目架构分层（两层 vs 三层、何时需要 Service 层），参见 `project-architecture` 技能。
- 实体 Biz 文件约定（FindByXxx/Search/Valid），参见 `xcode-entity-orm` 技能。
- DI 容器隔离测试，参见 `dependency-injection-ioc` 技能。
