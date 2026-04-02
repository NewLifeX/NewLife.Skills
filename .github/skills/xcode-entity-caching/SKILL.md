---
name: xcode-entity-caching
description: >
  使用 NewLife.XCode 内置多级缓存体系加速实体数据读取，涵盖四层缓存选型矩阵：
  EntityCache（整表列表缓存）、SingleCache（按键单对象字典缓存）、
  FieldCache（聚合统计/下拉枚举缓存）、DbCache（跨进程数据库键值缓存）。
  适用于字典表加速、用户高频读、统计下拉、跨服务缓存共享等场景。
argument-hint: >
  说明数据规模（小表字典 / 高频单对象读 / 统计聚合 / 跨进程共享）；
  数据更新频率（读多写少 vs 频繁变化）；是否有跨进程共享需求。
---

# XCode 实体缓存

## 四层缓存选型矩阵

| 缓存层 | 类 | 典型场景 | 数据量上限 | 更新方式 |
|--------|---|---------|-----------|---------|
| **EntityCache** | `EntityCache<T>` | 字典表、配置表、状态表 | ≤1000 条 | 过期异步刷新 |
| **SingleCache** | `SingleEntityCache<TK,TV>` | 按主键高频查单条 | 无硬限制 | TTL + 定时清理 |
| **FieldCache** | `FieldCache<T>` | 下拉选项、TopN 统计、分类汇总 | 聚合结果行 | 过期重查 |
| **DbCache** | `DbCache` | 跨进程共享、无外部缓存服务 | 受数据库限制 | Set/Get |

## EntityCache — 整表列表缓存

适用于**小表、读多写少**（如字典、角色、配置）。首次访问时阻塞加载，过期后异步刷新（不阻塞读取）。

```csharp
// 读取所有缓存实体（自动管理缓存生命周期）
var roles = Role.FindAllWithCache();

// 从缓存列表中过滤（无数据库访问）
var enabled = Role.FindAllWithCache().Where(r => r.Enable).ToList();

// 从缓存按主键查找
var role = Role.FindByKeyWithCache(roleId);

// 缓存内过滤（Biz 文件约定命名）
public static IList<Role> FindAllCachedEnabled() =>
    Meta.Cache.FindAll(_.Enable == true);

public static Role? FindCachedByName(String name) =>
    Meta.Cache.Find(_.Name == name);
```

**过期时间**：由 `XCodeSetting.EntityCacheExpire`（默认 10 秒）控制。

**写操作后自动失效**：Insert/Update/Delete 后框架自动调用 `ClearCache()`，下次读取重新加载。

## SingleCache — 单对象字典缓存

适用于**按主键或业务键高频读单条记录**（如用户信息、订单详情）。以字典形式存储，支持主键和从键两种索引。

```csharp
// 按主键读取（命中则从内存返回，未命中则查 DB 并缓存）
var user = User.Meta.SingleCache[userId];

// 按从键读取（如按用户名查用户）
var user2 = User.Meta.SingleCache.GetItemWithSlaveKey("alice");

// 手动配置（在实体静态构造函数中）
static User()
{
    // 配置从键（业务唯一键，如 Name/No）
    Meta.SingleCache.SlaveKeyName = nameof(Name);
    Meta.SingleCache.GetSlaveKey = e => e.Name;

    // 过期时间（秒），默认由 XCodeSetting.SingleCacheExpire 控制
    // Meta.SingleCache.Expire = 60;
}
```

**过期时间**：由 `XCodeSetting.SingleCacheExpire`（默认 10 秒）控制，空闲超时自动清理。

## FieldCache — 聚合统计缓存

适用于**下拉选项、TopN 统计、Group By 汇总**，避免频繁执行 GROUP BY 查询。

```csharp
// 字段枚举值（如品类名称列表）
var categories = new FieldCache<Product>("Category").FindAllName();

// 按某字段统计数量（下拉选项 + 数量）
var fieldCache = new FieldCache<Order>("Status")
{
    // 自定义显示格式：名称(数量)
    DisplayFormat = "{name}({count})",
    // 数量阈值（只显示 ≥5 条的项）
    // WhereExpression = _.CreateTime >= DateTime.Today,
};
var items = fieldCache.DataSource;  // 返回 IDictionary<Object, String>

// 在 Biz 文件中封装为属性（魔方自动识别用于下拉）
public static FieldCache<Order> StatusCache { get; } =
    new FieldCache<Order>(nameof(Status));
```

## DbCache — 跨进程数据库键值缓存

适用于**无外部 Redis 但需要跨进程共享缓存**的场景，以数据库表存储键值对。

```csharp
// 获取默认实例（使用默认连接）
var cache = DbCache.Default;

// 写入（整数秒过期，0 = 永不过期）
cache.Set("config:maxRetry", 3, 600);
cache.Set("user:token:42", tokenObj, 3600);

// 读取
var retries = cache.Get<Int32>("config:maxRetry");
var token = cache.Get<MyToken>("user:token:42");

// 判断是否存在
if (cache.ContainsKey("feature:darkmode")) { ... }

// 删除
cache.Remove("user:token:42");
```

**特点**：JSON 序列化、内置热点（高频读取时进程内二级缓存加速）、自动清理过期条目。

## 缓存失效触发

```csharp
// 手动失效（如外部修改了数据需要刷新）
User.Meta.Session.ClearCache("数据已更新", force: true);

// 强制清空单对象缓存
User.Meta.SingleCache.Clear();

// 框架自动触发（无需手动调用）：
// - Entity.Insert() / Update() / Delete() 后自动调用 ClearCache
// - EntityTransaction 回滚后强制清空
```

## 选型建议

```
数据量 ≤ 1000 条，读多写少（字典/配置/角色）
    → EntityCache（FindAllWithCache）

按 ID/Key 高频查单条（用户首页、订单详情）
    → SingleCache（Meta.SingleCache[key]）

下拉列表 / Group By 统计 / TopN
    → FieldCache（避免频繁聚合查询）

无 Redis，跨进程共享少量键值
    → DbCache（Set/Get）

超大表 + 分布式共享
    → NewLife.Redis（见 cache-provider-architecture 技能）
```

## 注意事项

- `EntityCache` 适合**千条以内**的字典表；超过 1 万条建议改用 `SingleCache` 或直接查询。
- `EntityCacheExpire`/`SingleCacheExpire` 是全局配置；单个实体需要不同过期时间时，在静态构造函数里单独设置 `Meta.Cache.Expire` / `Meta.SingleCache.Expire`。
- `FieldCache` 返回的 `DataSource` 是快照，多次调用会共享同一结果直到过期。
- 缓存读出的实体**不要修改后不 Save**；修改必须调用 `Update()`，否则下次缓存刷新后修改丢失。
