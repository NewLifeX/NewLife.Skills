# NewLife.Core ICache 模式证据

> 来源：`Caching/ICache.cs` + `Caching/ICacheProvider.cs` + `caching.instructions.md`
> 缓存文档（`Doc/缓存系统ICache.md`）存在编码损坏，以源码为准。

---

## 1. 接口层次（源码校验）

```text
ICache
├── 基本属性：Name / Expire / Count / Keys / this[key]
├── CRUD: ContainsKey / Set<T> / Get<T> / TryGetValue<T> / Remove / Clear
├── 过期：SetExpire / GetExpire
├── 批量：GetAll<T> / SetAll<T>
├── 高级：Add<T>（不覆盖）/ Replace<T>（原子替换）/ GetOrAdd<T>
├── 原子：Increment / Decrement（Int64 + Double）
└── 分布式锁：AcquireLock (via ICacheProvider)

ICacheProvider
├── Cache          跨进程缓存（可替换 Redis）
├── InnerCache     进程内缓存（始终 MemoryCache）
├── GetQueue<T>(topic, group?)   → IProducerConsumer<T>
├── GetInnerQueue<T>(topic)      → 进程内队列
└── AcquireLock(key, msTimeout)  → IDisposable?（失败抛异常）
```

---

## 2. `ICache` 过期时间语义（源码注释）

```csharp
// expire < 0 → 采用 ICache.Expire 默认值
// expire = 0 → 永不过期  ← 最常误用！
// expire > 0 → 相对过期秒数（从现在起）
Boolean Set<T>(String key, T value, Int32 expire = -1);
```

**常见误用**：
```csharp
// ❌ 误以为 0 是默认：
cache.Set(key, value, expire: 0);  // → 实际是永不过期！

// ✅ 应该用 -1 表示"使用默认":
cache.Set(key, value, expire: -1);
```

---

## 3. `TryGetValue` vs `Get` 防穿透

```csharp
// Get<T>：无法区分"键不存在"与"值是默认值"
var user = cache.Get<User>("user:0");  // 值为 null → 不存在还是值本身就是 null？

// TryGetValue：准确区分
if (cache.TryGetValue<User>("user:0", out var user))
{
    return user;  // 确实命中（即使 user 是 null）
}
// 未命中 → 穿透到数据库
```

源码注释（直接引用）：
> *"返回 true 表示键存在，但不保证反序列化成功；反序列化失败时 value 通常为默认值。解决缓存穿透问题的重要方法。"*

---

## 4. `ICacheProvider` 两级缓存设计原则（源码注释）

> *"根据实际开发经验，即使在分布式系统中，也有大量的数据是不需要跨进程共享的，因此本接口提供了两级缓存。"*

| 属性 | 类型 | 用途 |
|------|------|------|
| `InnerCache` | 始终 `MemoryCache` | 进程内字典/配置，无序列化开销 |
| `Cache` | 可配置（默认 MemoryCache，生产换 Redis）| 跨进程共享、用户会话、分布式锁 |

---

## 5. 队列选择策略（源码注释）

> *"可根据是否设置消费组来决定使用简单队列还是完整队列"*

| group 参数 | 返回队列类型 | 适用场景 |
|-----------|-------------|---------|
| `null` | 简单队列（如 `RedisQueue`）| Topic 多但消息量少（命令分发）|
| 非空字符串 | 完整队列（如 `RedisStream`）| Topic 少但消息量大（可靠消息，支持 ACK）|

---

## 6. 分布式锁行为（源码注释）

```csharp
// AcquireLock：锁维持时间 = msTimeout；等待时间 = msTimeout
// 成功：返回 IDisposable → using 块结束自动释放
// 失败（等待超时）：抛出异常
using var lockObj = cache.AcquireLock("order:1001", msTimeout: 3000);
```

**注意**：不同 `ICache` 实现对分布式锁的支持不同；`MemoryCache` 提供进程内互斥锁，`Redis` 提供跨进程分布式锁。

---

## 7. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| `ICache` 接口优先 | ✅ 通用 | 与 `IDistributedCache` 思路一致 |
| 过期三段语义（<0/-0/>0）| ⚠️ NewLife 特有 | 通用替代：`TimeSpan?` nullable |
| `TryGetValue` 防穿透 | ✅ 通用 | 任何缓存系统均适用 |
| `GetAll`/`SetAll` 批量 | ✅ 通用 | Redis Pipeline 等均支持 |
| 两级缓存（Inner + Cache）| ✅ 通用 | 本地缓冲 + 远端分布式，通用架构 |
| 队列 group 决定类型 | ⚠️ NewLife 特有 | 通用替代：显式指定队列类型 |
| `Cache` 基类继承规范 | ⚠️ NewLife 特有 | 扩展实现时特有约束 |
