---
name: redis-client
description: >
  使用 NewLife.Redis（FullRedis/Redis）通过 ICache 接口进行高性能 Redis 操作，
  涵盖连接池配置、基础 KV 操作、四种队列（Queue/Reliable/Delay/Stream）、
  数据结构（List/Hash/Set/SortedSet/Geo/HyperLogLog）、发布订阅、Pipeline 管道，
  以及集群（Cluster/Sentinel/Replication）接入。
  适用于缓存加速、可靠消息队列、发布订阅、分布式锁等场景。
argument-hint: >
  说明你的 Redis 场景：缓存读写、消息队列（简单/可靠/延迟/Stream）、发布订阅、
  数据结构操作；是否需要集群/哨兵/主从；是否需要 Pipeline 批量提交。
---

# Redis 客户端技能（NewLife.Redis）

## 适用场景

- 应用缓存层对接 Redis，需要面向 `ICache` 接口，在开发/生产环境自由切换。
- 分布式消息队列：简单队列（至多一次）、可靠队列（至少一次 + Ack 确认）、延迟队列、Stream 消费组。
- 各类 Redis 数据结构操作：`RedisList`、`RedisHash`、`RedisSet`、`RedisSortedSet`、`RedisGeo`、`HyperLogLog`。
- 发布订阅（Pub/Sub）实时推送。
- 高并发场景下使用 Pipeline 合并命令，降低网络 RTT。
- 集群/哨兵/主从模式接入。

## 核心原则

1. **优先用 `FullRedis`，而非基础 `Redis`**：`FullRedis` 支持集群自动检测（`Mode` 属性：`cluster`/`sentinel`/`standalone`）、数据结构工厂方法（`GetList<T>`/`GetStream<T>` 等），向下兼容基础 `Redis` 所有能力。
2. **通过连接字符串工厂创建**：`FullRedis.Create("server=127.0.0.1:6379;password=xxx;db=0")` 是最简洁的创建方式；连接字符串中多路地址用逗号分隔可实现多节点故障切换。
3. **`Redis` 实现 `ICache` 接口**：过期时间语义与 `MemoryCache` 一致：`expire < 0` 使用默认值，`expire = 0` 永不过期，`expire > 0` 为相对秒数。不要用 `0` 表示默认。
4. **队列选型**：简单 `RedisQueue` 无确认（至多一次，不丢不行的场景不适用）；`RedisReliableQueue` 基于 `RPOPLPUSH` + Ack 确认（适合订单/支付消息）；`RedisDelayQueue` 基于有序集合实现延迟投递；`RedisStream` 支持消费组多消费者（大吞吐）。
5. **Pipeline 减少 RTT**：高频批量写操作启用 `AutoPipeline`（达到指定命令数自动提交）或手动 `StartPipeline`/`StopPipeline`；注意 Pipeline 内命令结果不可立即读取。
6. **连接池默认参数合理，不要随意缩小**：最小连接 `MinPool=10`，最大连接 `MaxPool=100000`；读写超时默认 `3000ms`，生产环境根据 P99 调整，不要设得太小。
7. **集群模式无需手动配置**：`FullRedis.InitCluster()` 自动检测服务端模式；哨兵模式在 `Server` 地址中包含 `sentinel://` 前缀；原生集群自动路由分片。

## 执行步骤

### 一、创建连接

```csharp
using NewLife.Caching;

// 方式 1：连接字符串（推荐）
var redis = FullRedis.Create("server=127.0.0.1:6379;password=;db=0");

// 方式 2：属性配置
var redis = new FullRedis
{
    Server   = "127.0.0.1:6379",
    Password = "",
    Db       = 0,
    Timeout  = 3000,   // 读写超时 ms
};
redis.Init(null);

// 方式 3：DI 注册（ASP.NET Core）
services.AddSingleton<ICache>(sp =>
    FullRedis.Create("server=127.0.0.1:6379;db=1"));
```

### 二、基础 KV 操作

```csharp
// 写入（60 秒过期）
redis.Set("user:1", user, expire: 60);

// 读取（区分不存在与默认值）
if (redis.TryGetValue<User>("user:1", out var user))
    return user;

// 批量读写（减少 RTT）
redis.SetAll(dict, expire: 300);
var map = redis.GetAll<User>(new[] { "user:1", "user:2" });

// 原子递增（计数、限流）
var count = redis.Increment("page:views", 1);

// 分布式锁（配合 using 确保释放）
using var locker = redis.AcquireLock("lock:order:42", 30_000);
if (locker == null) throw new Exception("获取锁失败");
// 互斥操作...
```

### 三、四种队列

```csharp
// 1. 简单队列（LPUSH/RPOP，无确认，至多一次）
var queue = redis.GetQueue<String>("tasks");
queue.Add("task1", "task2");
var task = queue.TakeOne(timeout: 5);  // 阻塞等待 5 秒

// 2. 可靠队列（RPOPLPUSH + Ack，至少一次）
var reliable = redis.GetReliableQueue<Order>("orders");
reliable.Add(order);
var msg = reliable.TakeOne(timeout: 5);
if (msg != null)
{
    Process(msg);
    reliable.Acknowledge(msg);  // 确认消费
}
// 后台启动死信恢复：把超时未 Ack 的消息重新入队
reliable.RetryDeadDelay = 60;

// 3. 延迟队列（基于 ZADD，指定延迟秒数）
var delay = redis.GetDelayQueue<String>("delayed-tasks");
delay.Add("send-email", delaySeconds: 300);  // 5 分钟后可消费

// 4. Redis Stream（消费组，高吞吐）
var stream = redis.GetStream<Event>("events");
stream.Group = "group1";
stream.Add(new Event { ... });
var events = stream.Read(count: 100);  // 消费组拉取
stream.Acknowledge(events.Select(e => e.Id));
```

### 四、数据结构

```csharp
// List（有序列表）
var list = redis.GetList<String>("my-list");
list.Add("a", "b", "c");
var all = list.GetAll();

// Hash（字典）
var hash = redis.GetDictionary<String, Int32>("scores");
hash["alice"] = 100;
hash["bob"]   = 200;
var score = hash["alice"];

// Set（去重集合）
var set = redis.GetSet<String>("tags");
set.Add("redis", "cache");
var contains = set.Contains("redis");

// SortedSet（排行榜）
var sorted = redis.GetSortedSet<String>("rank");
sorted.Add("alice", 100.0);
sorted.Add("bob",   200.0);
var top10 = sorted.GetRange(0, 9);  // 前 10 名

// Geo（地理位置）
var geo = redis.GetGeo("locations");
geo.Add("beijing", 116.4074, 39.9042);
var dist = geo.Distance("beijing", "shanghai");  // 单位：米

// HyperLogLog（基数统计，去重计数）
var hll = redis.GetHyperLogLog("uv:2024-01-01");
hll.Add("user:1", "user:2", "user:3");
var count = hll.Count();
```

### 五、发布订阅

```csharp
// 订阅（异步，独立后台线程）
var sub = redis.GetPubSub("events");
_ = sub.SubscribeAsync(async (topic, msg) =>
{
    Console.WriteLine($"[{topic}] {msg}");
}, cancellationToken);

// 发布
sub.Publish("hello from producer");
```

### 六、Pipeline 管道

```csharp
// 自动管道（命令数达阈值自动提交）
redis.AutoPipeline = 100;

// 手动管道（精确控制）
var client = redis.StartPipeline();
client.Set("k1", "v1");
client.Set("k2", "v2");
client.Increment("counter", 1);
var results = redis.StopPipeline(requireResult: true);
```

### 七、集群 / 哨兵 / 主从

```csharp
// 原生集群（多节点逗号分隔，自动路由）
var cluster = FullRedis.Create("server=node1:7001,node2:7002,node3:7003");
cluster.InitCluster();  // 自动检测 cluster 模式

// 哨兵模式（sentinel:// 前缀）
var sentinel = FullRedis.Create(
    "server=sentinel://sentinel1:26379,sentinel2:26380;masterName=mymaster");

// SSL/TLS
var tls = new FullRedis
{
    Server      = "redis.example.com:6380",
    SslProtocol = System.Security.Authentication.SslProtocols.Tls12,
};
```

## 配置参数速查

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `Server` | — | Redis 地址，多地址逗号分隔 |
| `Password` | — | 认证密码 |
| `Db` | `0` | 数据库索引 |
| `Timeout` | `3000` | 读写超时（ms） |
| `MinPool` | `2` | 连接池最小连接数 |
| `MaxPool` | `100000` | 连接池最大连接数 |
| `Retry` | `3` | 失败重试次数 |
| `AutoPipeline` | `0` | 自动管道命令阈值（0=关闭） |
| `Encoder` | `RedisJsonEncoder` | 序列化编码器 |

## 常见错误与注意事项

- **`expire=0` 永不过期**，不代表使用默认值。使用默认值应传 `expire=-1`。
- **可靠队列消费后必须 Ack**，否则消息长期在备份队列中，触发死信堆积。
- **Stream 消费组需先创建 Group**：第一次消费前调用 `stream.SetGroup(groupName)`。
- **Pipeline 内不能立即读取结果**：`StartPipeline` 期间所有 `Get` 返回值为空，需 `StopPipeline` 后从返回数组读取。
- **集群模式下 `Db` 只能为 0**：Redis Cluster 不支持多数据库。
- **不要在高并发下用 `Keys` 扫描全库**：`redis.Keys` 在 Redis Cluster 下遍历全部 slot，性能极低，仅适合调试。
