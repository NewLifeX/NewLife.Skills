---
name: distributed-id
description: >
  使用 NewLife.Core 的 Snowflake 雪花算法生成器生成 64 位趋势递增分布式唯一 ID。
  涵盖单例约束、WorkerId 分配策略（显式/Redis 集群自增/默认 IP 派生）、
  时间指定/业务 ID 嵌入等变体方法，以及范围查询辅助方法 GetId。
  适用于分布式系统主键、IoT 设备采集记录、时间序列写入等场景。
argument-hint: >
  说明你的场景：单机还是多节点（用 Redis 集群分配 WorkerId）；
  是否需要把业务时间嵌入 ID（用 NewId(DateTime)）；
  IoT 传感器采集（用 NewId22 每毫秒一个去重 ID）；
  还是时间范围查询（用 GetId 构造区间边界）。
---

# 分布式 ID 技能（Snowflake 雪花算法）

## 适用场景

- 分布式系统数据库主键：趋势递增，无需数据库自增，支持分库分表。
- IoT 设备数据采集入库：`NewId(time, uid)` 将采集时间和传感器 ID 嵌入主键；`NewId22` 用于同一传感器同一毫秒去重（upsert 场景）。
- 时间范围查询：`GetId(time)` 将时间转为 ID 边界，在雪花 ID 列上做范围扫描，无需时间索引。
- 代码审查：确认应用内 `Snowflake` 为单例（同 `WorkerId` 多实例会产生重复 ID）；分布式部署时 `WorkerId` 必须全局唯一（推荐 Redis 自增分配）。

## 核心原则

1. **一个应用一个实例**：`Snowflake` 只保证"本实例"内唯一；同 `WorkerId` 多实例并发即可产生重复。**必须保持全局单例**。
2. **`WorkerId=0` 被视为"未设置"**：初始化时若 `WorkerId <= 0`，会走自动分配逻辑（GlobalWorkerId → Cluster → IP 派生）。若要固定为 0，需显式赋值后在初始化前调用 `Initialize()`，或将 WorkerId 改为 1。
3. **`StartTimestamp` 必须在首次 `NewId()` 前设置**：初始化只做一次，运行期修改无效。默认 `UTC 1970-01-01` 转本地时间（兼容按本地日期分表场景）。
4. **时间回拨处理**：小幅回拨沿用上次时间戳（保证单实例唯一）；超过 `MaxClockBack`（约 1 小时）抛异常。
5. **生产环境推荐 Redis 集群分配 WorkerId**：IP 派生策略在容器/NAT 环境下不可靠。

## 执行步骤

### 一、单机最简用法

```csharp
using NewLife.Data;

// 全局单例（静态字段，贯穿应用生命周期）
public static class IdGen
{
    public static readonly Snowflake Instance = new Snowflake
    {
        WorkerId = 1,  // 显式指定，避免默认 IP 派生不稳定
        // StartTimestamp = new DateTime(2020, 1, 1, 0, 0, 0, DateTimeKind.Local),
    };
}

// 生成 ID
long id = IdGen.Instance.NewId();
```

### 二、分布式 — Redis 集群自增分配 WorkerId（推荐）

```csharp
using NewLife.Caching;
using NewLife.Data;

// 应用启动时配置一次（Set once globally）
Snowflake.Cluster = new FullRedis("127.0.0.1:6379", "", 0);

// 各模块直接 new Snowflake()，初始化时自动从 Redis 获取唯一 WorkerId
public static readonly Snowflake Snow = new Snowflake();
long id = Snow.NewId();
// 内部：workerId = cache.Increment("SnowflakeWorkerId", 1) & 1023
```

多环境隔离（dev/test/prod 各用不同 key）：

```csharp
Snow.JoinCluster(redisCache, key: "Snow_Prod_WorkerId");
```

### 三、显式 WorkerId（容器/K8s 环境，从环境变量注入）

```csharp
var workerId = int.Parse(Environment.GetEnvironmentVariable("WORKER_ID") ?? "1");
var snow = new Snowflake { WorkerId = workerId };
```

### 四、携带业务时间的 ID（IoT / 时间序列）

```csharp
// 场景：采集事件携带采集时间而非当前时间
long id = snow.NewId(sensorData.CollectedAt);

// 同一传感器（uid=传感器编号），每毫秒最多 4096 个 ID
long id2 = snow.NewId(sensorData.CollectedAt, sensorId);   // uid 低10位为 WorkerId

// 同一传感器每毫秒唯一（upsert 去重），无序列号，22位业务ID
long id3 = snow.NewId22(sensorData.CollectedAt, sensorId); // uid 低22位嵌入 ID
```

### 五、时间范围查询

```csharp
// 查询今天 0:00 ~ 23:59:59 之间产生的所有记录
var start  = snow.GetId(DateTime.Today);
var end    = snow.GetId(DateTime.Today.AddDays(1)) - 1;

// 在数据库时使用范围查询（雪花 ID 趋势递增，可用 BETWEEN）
var sql = $"SELECT * FROM Orders WHERE Id BETWEEN {start} AND {end}";
```

### 六、解析 ID

```csharp
if (snow.TryParse(id, out var time, out var workerId, out var sequence))
{
    Console.WriteLine($"时间={time}, WorkerId={workerId}, 序列号={sequence}");
}
```

### 七、属性速查

| 属性/成员 | 说明 |
|----------|------|
| `WorkerId` | 工作节点 ID（0~1023，**生产必须显式设置**） |
| `StartTimestamp` | 起始时间，默认 `1970-01-01 Local`，首次 `NewId()` 前设置 |
| `Sequence` | 当前序列号（只读，0~4095） |
| `Snowflake.Cluster` | 静态，Redis 等缓存实例，用于集群分配 WorkerId |
| `Snowflake.GlobalWorkerId` | 静态，全局 WorkerId，优先于自动派生但低于实例属性 |
| `NewId()` | 基于 `DateTime.Now` 生成（最常用） |
| `NewId(DateTime)` | 指定业务时间 |
| `NewId(DateTime, Int32 uid)` | 指定时间 + uid 低10位作 WorkerId |
| `NewId22(DateTime, Int32 uid)` | 指定时间 + uid 低22位，无序列号（upsert 去重）|
| `GetId(DateTime)` | 仅时间位，用于范围查询边界 |
| `TryParse` | 解析 ID → 时间 + WorkerId + 序列号 |

## 重点检查项

- [ ] `Snowflake` 实例是否为全局单例（静态字段或 DI 单例注册）？多实例+同 WorkerId = 重复 ID。
- [ ] 分布式部署时 `WorkerId` 是否通过环境变量/Redis 集群保证跨节点唯一？
- [ ] `StartTimestamp` 是否在首次调用 `NewId()` 之前设置（运行期修改无效）？
- [ ] 使用 `NewId22` 时是否确认同一传感器同一毫秒只生成一个 ID（无序列号，多次调用会重复）？
- [ ] 使用 `GetId` 构造范围查询时，结束边界是否用 `GetId(endTime) - 1`（确保不跨毫秒）？

## 输出要求

- **ID 生成**：`Snowflake`（`NewLife.Data`）—— 64位 `Int64`，`1+41+10+12` 位结构。
- **单例策略**：静态字段 + 显式 `WorkerId` 或 `Snowflake.Cluster = RedisCache`。
- **变体方法**：`NewId()`/`NewId(DateTime)`/`NewId(DateTime, uid)`/`NewId22(DateTime, uid)`/`GetId(DateTime)`/`TryParse`。

## 参考资料

- `NewLife.Core/Data/Snowflake.cs`
- 相关技能：`cache-provider-architecture`（Redis ICache，用于集群 WorkerId 分配）
