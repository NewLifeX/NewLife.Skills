---
name: cache-provider-architecture
description: >
  设计或使用统一缓存提供者架构，涵盖 ICache 接口操作、过期语义、原子操作、两级缓存（进程内 + 跨进程）、
  分布式锁 AcquireLock、生产消费队列 IProducerConsumer，以及缓存穿透防护。
  适用于缓存系统设计、ICache 扩展实现、分布式场景数据共享与代码审查任务。
argument-hint: >
  说明你的缓存场景：单机内存还是分布式（Redis）；是否需要分布式锁；
  是否需要队列（简单队列 vs 消费组队列）；是否有缓存穿透/击穿风险。
---

# 缓存提供者架构设计技能

## 适用场景

- 为应用设计缓存层，需要在开发时用 `MemoryCache`、生产时替换为 `Redis`，业务代码零改动。
- 需要分布式锁保证多节点互斥操作（库存扣减、定时任务单点执行等）。
- 需要跨服务的轻量消息队列（命令分发用简单队列，消息可靠投递用消费组队列）。
- 审查缓存相关代码：检查是否面向 `ICache` 接口、过期时间语义是否正确、是否有批量操作优化。
- 在现有 `ICacheProvider` 框架内，判断数据应放进程内缓存（`InnerCache`）还是跨进程缓存（`Cache`）。

## 核心原则

1. **接口优先**：所有业务代码面向 `ICache` 接口，不直接依赖 `MemoryCache` 或 `Redis`；通过 DI 注入具体实现。
2. **两级缓存定位**：`ICacheProvider.InnerCache` 是进程内缓存（无序列化开销，适合频繁读的字典/配置数据）；`ICacheProvider.Cache` 是跨进程缓存（适合分布式共享、用户会话等）。
3. **过期时间语义**：`expire < 0` = 用 `ICache.Expire` 默认值；`expire = 0` = 永不过期；`expire > 0` = 相对过期秒数。**不要用 `0` 表示"默认"**——这是最常见的语义误用。
4. **用 `TryGetValue` 防穿透**：`Get<T>` 无法区分"键不存在"与"值恰好是默认值"；用 `TryGetValue` 才能准确判断是否命中，是防止缓存穿透的关键手段。
5. **批量操作优先**：循环内逐条 `Get`/`Set` 应替换为 `GetAll`/`SetAll`；远端缓存下批量操作网络往返减少数量级。
6. **分布式锁必须配对 Dispose**：`AcquireLock` 返回 `IDisposable`，配合 `using` 使用；锁获取失败时应有明确降级逻辑，而不是静默跳过。

## 执行步骤

### 一、选择缓存实现

| 场景 | 推荐 |
|------|------|
| 单机内存缓存 | `MemoryCache.Instance`（全局单例）|
| 分布式（Redis）| `NewLife.Redis`（独立包，实现 `ICache`）|
| 跨进程/单机均兼容 | `ICacheProvider.Cache`（运行时决定）|
| 进程内高频字典 | `ICacheProvider.InnerCache`（始终 MemoryCache）|

### 二、基础 CRUD 操作

```csharp
// 设置（60 秒过期）
cache.Set("user:1", user, 60);

// 读取（区分"键不存在"与"默认值"）
if (cache.TryGetValue<User>("user:1", out var user))
    return user;

// 获取或缓存（防穿透）
var data = cache.GetOrAdd("config:rules", key =>
    LoadRulesFromDb(key), expireSeconds: 300);

// 批量读（减少网络往返）
var users = cache.GetAll<User>(ids.Select(id => $"user:{id}"));

// 原子递增（统计/限流）
var count = cache.Increment("page:views", 1);

// 原子递增并同时获取 TTL（限流计数专用）
// 返回 (Int64 Value, Int32 Ttl)，Ttl < 0 表示 key 尚未设置过期
var (cnt, ttl) = cache.IncrementWithTtl("rate:user:42", 1);
if (ttl < 0) cache.SetExpire("rate:user:42", TimeSpan.FromMinutes(1));  // 首次计数时设置窗口
```

### 三、过期时间正确使用

```csharp
// ✅ 正确：60 秒过期
cache.Set(key, value, expire: 60);

// ✅ 正确：永不过期
cache.Set(key, value, expire: 0);

// ✅ 正确：使用 ICache.Expire 默认值
cache.Set(key, value, expire: -1);

// ❌ 错误：0 不代表"默认"，代表"永不过期"
cache.Set(key, value, expire: 0);  // 若本意是默认过期，应用 -1
```

### 四、分布式锁

```csharp
// 简化重载：AcquireLock(key, msTimeout) — 获取失败抛出异常
try
{
    using var lockObj = cacheProvider.Cache.AcquireLock("order:pay:1001", msTimeout: 3000);
    // 临界区业务逻辑
    await ProcessPaymentAsync(orderId);
}   // using 块结束自动释放锁
catch (Exception ex) when (ex.Message.Contains("锁"))
{
    // 降级：等待重试 / 返回"正在处理"
    return Result.Conflict("订单正在处理中，请稍后重试");
}

// 完整重载：AcquireLock(key, msTimeout, msExpire, throwOnFailure)
// msExpire：锁的最大持有时长（防止死锁），与 msTimeout 独立
// throwOnFailure=false：获取失败时返回 null 而不抛出异常
var lockObj2 = cache.AcquireLock("task:import", msTimeout: 0, msExpire: 30_000, throwOnFailure: false);
if (lockObj2 == null) return; // 已有其他节点在处理，本次跳过
try { /* 执行任务 */ }
finally { lockObj2.Dispose(); }
```

### 五、两级缓存分工

```csharp
// 进程内：字典/配置/统计数据，无需跨服务共享
var roles = provider.InnerCache.GetOrAdd("roles", _ => LoadRoles(), 600);

// 跨进程：用户会话、分布式锁、跨节点计数
provider.Cache.Set($"session:{token}", session, 1800);
```

### 六、队列选择

```csharp
// IProducerConsumer<T> 真实 API（同步入队，阻塞或异步出队）
var queue = provider.Cache.GetQueue<String>("cmd:emails");

// 入队（支持批量，返回成功入队数）
queue.Add("payload1", "payload2");

// 同步批量出队（最多取 N 条）
var batch = queue.Take(10);    // IEnumerable<String>

// 阻塞出队（适合常驻消费者循环，30 秒超时）
var item = await queue.TakeOneAsync(30);  // String?

// 带取消令牌的异步出队
var item2 = await queue.TakeOneAsync(30, cancellationToken);

// Acknowledge（仅部分实现支持，如 Redis XACK）
queue.Acknowledge(processedMsgKey);
```

> **注意**：`IProducerConsumer<T>` **没有** `AddAsync`、`TakeAsync`、`AckAsync` 方法。
> 入队是同步操作 `Add(params T[])`；出队推荐用 `TakeOneAsync` 做异步等待。

### 七、扩展实现 `ICache`

1. 继承 `Cache` 基类（提供默认的批量操作 fallback 实现）。
2. 重写 `GetAll`/`SetAll` 为原生批量 API，而不是循环调用单条。
3. `Init(string connStr)` 解析连接字符串初始化底层连接。
4. `Dispose()` 必须释放底层连接/连接池资源。

## 重点检查项

- [ ] 是否面向 `ICache` 接口，未直接依赖 `MemoryCache` 或 `Redis`？
- [ ] `expire = 0` 是否被误用为"默认"（正确语义是"永不过期"）？
- [ ] 热路径中是否有循环逐条 `Get`/`Set`（应换 `GetAll`/`SetAll`）？
- [ ] `AcquireLock` 是否配合 `using` 使用，且有锁获取失败的降级处理？
- [ ] 使用 `TryGetValue` 而非 `Get` 来防止缓存穿透？
- [ ] `MemoryCache` 是否用了 `MemoryCache.Instance`（全局单例），而不是每次 `new`？
- [ ] 缓存 key 是否包含用户输入？是否经过校验（注入风险）？

## 输出要求

- **接口**：`ICache`（基础操作）、`ICacheProvider`（两级缓存 + 队列 + 锁）、`IProducerConsumer<T>`（生产消费）。
- **实现**：`MemoryCache`（内存），`Cache` 抽象基类；Redis 放独立包不耦合 Core。
- **两级缓存配置**：`CacheProvider.Cache` 在应用启动时替换为 Redis 实例；`InnerCache` 保持默认。
- **测试**：使用 `MemoryCache` 实例（而非 mock）做集成测试；分布式锁测试覆盖超时和并发争用场景。

## 参考资料

参考示例与模式证据见 `references/newlife-icache-patterns.md`。
