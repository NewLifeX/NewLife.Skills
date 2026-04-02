---
name: xcode-sharding-etl
description: >
  使用 NewLife.XCode 实现分库分表和数据 ETL/同步，涵盖 TimeShardPolicy 时间分片策略配置
  （TablePolicy/ConnPolicy/Step）、Meta.ShardPolicy 挂载、AutoShard 跨分片查询、
  EntitySplit 手动切换分片，以及 ETL<TSource> 数据抽取框架（IExtracter 五种实现）
  和 SyncManager 四阶段数据同步。
  适用于大数据分表存储、跨分片聚合查询、数据迁移、增量同步等场景。
argument-hint: >
  说明数据规模和分表策略（按天/月/年）；是否需要雪花 ID 路由；
  是否需要跨分片聚合查询；ETL 抽取是增量还是全量；数据同步的源端和目标端类型。
---

# XCode 分表分库与 ETL

## 分表分库（Shards）

### 适用场景

- 单表数据量超过千万，需要按时间维度（天/月/年）分表。
- 需要跨分片查询历史数据并汇总结果。
- 使用雪花 ID（Int64）作为主键，通过 ID 内嵌的时间偏移路由到正确分片。

### TimeShardPolicy 配置

```csharp
// 实体静态构造函数中挂载分片策略
static AccessLog()
{
    // 按天分表（单库）
    Meta.ShardPolicy = new TimeShardPolicy(nameof(CreateTime), Meta.Factory)
    {
        TablePolicy = "{0}_{1:yyyyMMdd}",   // 表名格式：AccessLog_20250101
        Step = TimeSpan.FromDays(1),         // 每 1 天一张表
    };
}

static Order()
{
    // 按月分库分表（分库 + 分表）
    Meta.ShardPolicy = new TimeShardPolicy(nameof(Id), Meta.Factory)
    {
        ConnPolicy  = "{0}_{1:yyyy}",        // 库名格式：Order_2025
        TablePolicy = "{0}_{1:yyyyMM}",      // 表名格式：Order_202501
        Step = TimeSpan.FromDays(30),        // 每 30 天（约一月）一张表
    };
}

static EventLog()
{
    // 按年分表
    Meta.ShardPolicy = new TimeShardPolicy(nameof(CreateTime), Meta.Factory)
    {
        TablePolicy = "{0}_{1:yyyy}",
        Step = TimeSpan.FromDays(365),
    };
}
```

**`TimeShardPolicy` 参数说明**：

| 参数 | 说明 |
|------|------|
| 第一参数（字段名）| 分片依据字段：`DateTime` 字段名 或 雪花 `Int64` 字段名 |
| `Factory` | 实体工厂（`Meta.Factory`）|
| `TablePolicy` | 表名格式，`{0}` = 实体表名，`{1}` = 时间 |
| `ConnPolicy` | 库名格式（分库时配置），`{0}` = 连接名，`{1}` = 时间 |
| `Step` | 每个分片的时间跨度 |

### 数据写入（自动路由）

框架根据实体的分片字段值自动路由到正确的表/库：

```csharp
// 自动路由写入对应分片（无需手动指定）
var log = new AccessLog { CreateTime = DateTime.Now, ... };
log.Insert();   // 自动写入 AccessLog_20250402 表

// 批量 Insert 自动按分片分组写入
var logs = batchLogs;
logs.Insert();  // 自动分组，每组写入对应分片
```

### AutoShard — 跨分片查询

跨多个分片自动执行查询并汇总结果：

```csharp
// 按时间区间跨分片查询（自动推导涉及的分片）
var start = new DateTime(2025, 1, 1);
var end = new DateTime(2025, 3, 31);

var list = AccessLog.Meta.AutoShard(start, end, (session) =>
{
    // 在每个分片 session 中执行的查询
    return AccessLog.FindAll(AccessLog._.CreateTime.Between(start, end));
});

// 跨分片统计
var total = AccessLog.Meta.AutoShard(start, end, session =>
    (Int64)AccessLog.FindCount()
).Sum();
```

**自动条件裁剪**：单分片命中时自动移除冗余时间条件，减少 SQL 扫描范围。

### EntitySplit — 手动切换分片

精准指定连接和表名（运维迁移、手动归档场景）：

```csharp
// 手动切换到指定分片（using 块内的查询都针对该分片）
using (Order.Meta.CreateSplit("Order_2024", "Order_202412"))
{
    var orders = Order.FindAll(Order._.Status == 1);
}

// 按策略路由（输入时间，让策略计算目标分片）
using (Order.Meta.CreateShard(new DateTime(2024, 12, 15)))
{
    var order = Order.FindByKey(orderId);
}
```

---

## ETL 数据抽取框架

### 适用场景

- 大表增量同步（按时间字段滑动窗口分批抽取）。
- 历史数据全量迁移（分页或按 ID 区间）。
- 跨库数据转换处理（源端 ≠ 目标端格式）。

### ETL<TSource> 基类

```csharp
// 继承 ETL 实现自定义处理
public class OrderETL : ETL<Order>
{
    /// <summary>处理一批数据</summary>
    protected override Int32 Process(IList<Order> list, DataContext ctx)
    {
        foreach (var order in list)
        {
            // 转换并写入目标
            var stat = BuildStat(order);
            stat.Save();
        }
        return list.Count;
    }
}

// 配置并启动
var etl = new OrderETL
{
    Setting = new ExtractSetting
    {
        Start = new DateTime(2025, 1, 1),  // 抽取起始时间
        End = DateTime.Today,              // 抽取截止时间
        BatchSize = 1000,                  // 每批数量
        Step = TimeSpan.FromMinutes(10),   // 时间窗口步长（TimeExtracter）
    }
};
etl.Start();
```

### IExtracter 抽取器族谱

| 抽取器 | 场景 | 特点 |
|-------|------|------|
| `TimeExtracter` | **增量同步**（默认）| 按时间字段递增，游标滑动 |
| `TimeSpanExtracter` | 补跑历史 | 固定时间步长循环，可重复执行 |
| `PagingExtracter` | 全量表（无时间字段）| Row 偏移分页 |
| `IdExtracter` | 自增主键 | 按连续 ID 区间分批 |
| `EntityIdExtracter` | 复合主键 | 按实体主键分批 |

```csharp
// 默认使用 TimeExtracter（推荐增量场景）
var etl = new OrderETL();

// 指定抽取器
var etl2 = new OrderETL
{
    Extracter = new PagingExtracter { BatchSize = 500 }
};

// IdExtracter（适合自增 ID 表）
var etl3 = new OrderETL
{
    Extracter = new IdExtracter { BatchSize = 1000 }
};
```

### ExtractSetting 配置

```csharp
var setting = new ExtractSetting
{
    Start = new DateTime(2024, 1, 1),    // 抽取起始时间/ID
    End = DateTime.Now,                  // 抽取截止
    Offset = TimeSpan.FromMinutes(-5),   // 安全偏移（避免抽取未完成写入的数据）
    BatchSize = 1000,                    // 每批记录数
    Step = TimeSpan.FromHours(1),        // 每步时间跨度（TimeExtracter）
};
```

### IETLModule 生命周期钩子

```csharp
public class MyModule : IETLModule
{
    public void OnInit(ETL etl) { /* 初始化资源 */ }

    public void OnProcessing(ETL etl, DataContext ctx)
    {
        // 每批数据处理前后的逻辑（统计/日志/报警）
        ctx.TotalCount  // 累计处理总数
        ctx.Speed       // 当前处理速度（条/秒）
    }

    public void OnStop(ETL etl) { /* 释放资源 */ }
}

etl.Modules.Add(new MyModule());
```

---

## SyncManager — 数据同步框架

### 适用场景

- 主从库数据双向同步（如主数据中心 → 分支机构）。
- 业务系统间数据同步（保持多个数据库中某张表的一致性）。
- 需要冲突检测和解决策略的场景。

### 四阶段同步流程

```
ProcessNew     从方新增处理（避免主键冲突，先同步主方还没有的新数据）
    ↓
ProcessDelete  从方删除处理（清理已在主方删除的数据）
    ↓
ProcessItems   主方增量数据（分批拉取，更新从方）
    ↓
ProcessOthers  检查本地未涉及的数据在主方是否仍存在
```

### ISyncMaster / ISyncSlave

```csharp
// 主方：实现 ISyncMaster（数据提供者）
public class OrderMaster : ISyncMaster
{
    // 获取指定时间后修改的主键集合
    public IList<Object> GetAdd(DateTime last, Int32 count) =>
        Order.FindAll(Order._.UpdateTime >= last, Order._.Id, "Id", 0, count)
             .Select(e => (Object)e.Id).ToList();

    // 获取已删除的主键集合（需要额外的删除日志表）
    public IList<Object> GetDelete(DateTime last) => [];

    // 获取一批完整数据
    public IList<IEntity> GetItems(IList<Object> keys) =>
        Order.FindAll(Order._.Id.In(keys)).Cast<IEntity>().ToList();
}

// 从方：实现 ISyncSlave（数据消费者）
// 通常用泛型适配器，处理 LastSync / SyncStatus 字段
```

### SyncManager 配置与启动

```csharp
var sync = new SyncManager
{
    Master = new OrderMaster(),         // 主方
    BatchSize = 200,                    // 每批处理数
    UpdateConflictByLastUpdate = true,  // 冲突时比较 UpdateTime（true=本地时间新则不覆盖）
    Names = new[] { "Status", "Amount", "UpdateTime" },  // 参与同步的字段
};

sync.Start();   // 开始同步
// sync.Stop(); // 停止
```

### 冲突解决策略

| 场景 | `UpdateConflictByLastUpdate=false`（默认主覆盖）| `=true`（按时间戳）|
|------|------|------|
| 从方改、主方不变 | 主方覆盖从方 | 从方推送到主方 |
| 从方不变、主方改 | 主方更新从方 | 主方更新从方 |
| 双方同时修改 | 主方覆盖从方 | 比较时间戳，较新者胜 |

### 从方辅助字段

```xml
<!-- 同步框架使用的辅助字段（在 Model.xml 中添加） -->
<Column Name="LastSync"   DataType="DateTime" Description="最近同步时间" />
<Column Name="SyncStatus" DataType="Int32"    Description="同步状态。1=新增待同步 2=删除待同步" />
```

## 注意事项

- 分表实体的 `InitData` 不执行建表检查（分片表由运行时按策略创建），不要在分片实体中做数据初始化。
- `AutoShard` 跨分片查询是串行执行的（默认），大量分片时性能随分片数线性增加；适合查询范围确定的场景。
- `TimeExtracter` 使用滑动游标，断点续跑时从 `ExtractSetting.Start` 的上次位置继续，注意持久化游标位置。
- ETL `Process` 方法应做幂等处理（同一批数据重复处理不产生副作用），以应对失败重试。
