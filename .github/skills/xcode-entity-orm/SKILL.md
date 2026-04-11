---
name: xcode-entity-orm
description: >
  使用 NewLife.XCode 实体 ORM 进行增删改查操作，涵盖 Entity<T> 基类 CRUD API、
  Biz 文件约定（FindByXxx/FindAllByXxx/Search 命名与参数顺序）、脏字段追踪、
  Valid 验证钩子、内置拦截器（Time/User/IP/Trace 自动填充）、实体事务、
  InitData 种子数据、EntityQueue 异步批写，以及 XCodeSetting 关键配置。
  适用于数据库 CRUD 业务逻辑开发、实体类使用、代码审查任务。
argument-hint: >
  说明业务场景：需要做哪类数据操作（查询/写入/批量/异步）；
  是否需要事务；对延迟写入（日志/统计）是否有要求。
---

# XCode 实体 ORM

## 适用场景

- 使用实体类进行增删改查（CRUD）操作。
- 在 `*.Biz.cs` 文件中封装数据层查询方法，规范命名和参数顺序。
- 配置 `Valid` 钩子做字段校验和自动填充。
- 使用内置拦截器自动填充审计字段（创建时间、操作人、IP、TraceId）。
- 日志/统计场景使用 `SaveAsync` 异步批量写入，减少 DB 压力。
- 审查实体类代码，确保遵循 Biz 文件约定。

## Entity<T> 基础 CRUD

```csharp
// 新增
var entity = new User { Name = "test", Password = "123456" };
entity.Insert();

// 查询单个（按主键）
var user = User.FindByKey(1);
// 查询单个（按条件）
var user2 = User.Find(User._.Name == "test");

// 查询列表
var list = User.FindAll();
var list2 = User.FindAll(User._.Status == 1, User._.Id.Desc(), null, 0, 10);

// 分页查询
var page = new PageParameter { PageIndex = 1, PageSize = 20 };
var list3 = User.FindAll(User._.Status == 1, page);

// 统计数量
var count = User.FindCount(User._.Status == 1);

// 更新
user.Name = "newName";
user.Update();

// 删除
user.Delete();

// 保存（自动判断 Insert/Update）
entity.Save();

// 异步保存（适合日志/高频写入，延迟 3 秒批量写入）
await entity.SaveAsync(3000);

// 批量插入
var list4 = new List<User>();
for (var i = 0; i < 100; i++)
    list4.Add(new User { Name = $"user{i}" });
list4.Insert();

// 批量更新（将 Status==1 改为 Status==2）
User.Update(User._.Status == 2, User._.Status == 1);

// 批量删除
User.Delete(User._.Status == 0);

// 异步查询（可选）
var user3 = await User.FindAsync(User._.Id == 1);
var list5 = await User.FindAllAsync(User._.Status == 1, page);
```

## Biz 文件约定

### 分部类架构

在 XCode 体系中，每个数据表生成实体类时会产生**两个文件**，例如 `用户.cs` 和 `用户.Biz.cs`，它们是**同一个实体类**，通过 `partial`（分部类）技术拆分为两个文件：

| 文件 | 别名 | 说明 | 重新生成时 |
|------|------|------|------------|
| `实体名.cs` | 数据类 | 自动生成的数据映射代码（属性、字段映射、索引定义等） | **会被覆盖** |
| `实体名.Biz.cs` | 业务类 / Biz 文件 | 用户自定义的业务逻辑（查询方法、Valid 钩子、InitData 等） | **仅首次生成，不会被覆盖** |

因此，**所有用户自定义的增删改查逻辑都应写在 Biz 文件中**，无需担心重新执行 `xcode` 生成实体类时被覆盖。

### 核心规则

所有数据层逻辑一律放在 `*.Biz.cs` 文件的 `#region 高级查询` 中。**外部调用方只传语义化参数**，不在外部拼接 `WhereExpression`。

### 方法形式选择

| 场景 | 方法形式 | 返回类型 | 说明 |
|------|---------|---------|------|
| 返回单个对象，参数 ≤2 | `FindByXxx` | `TEntity?` | 未找到返回 `null` |
| 返回列表，参数 ≤2，无模糊查询/分页 | `FindAllByXxx` | `IList<TEntity>` | 未找到返回空列表 |
| 参数较多，含模糊查询或分页 | `Search(...)` | `IList<TEntity>` | 未找到返回空列表 |
| 实体缓存内过滤 | `FindAllCachedXxx` / `FindCachedXxx` | — | 调 `Meta.Cache.FindAll(...)` |

**命名边界**：
- `FindByXxx` → 单条记录（`TEntity?`）
- `FindAllByXxx` 和 `Search` → 列表（`IList<TEntity>`，**绝不返回 null**）

### Search 方法参数顺序

```
Search(业务过滤字段..., DateTime start, DateTime end, String? key, PageParameter page)
```

- 时间区间 `(start, end)` 在 key/page 左边
- 模糊关键词 `String? key` 倒数第二
- `PageParameter page` 始终最后

### Biz 文件内的表达式简写

在 Biz 类内部，可省略类名前缀直接用 `_`，代码简洁美观；而在外部代码中必须写 `ClassName._.FieldName`，代码臃肿、可读性差。更重要的是，**类似查询逻辑如果散落在外部各处，无法合并复用**，而集中在 Biz 文件中可以统一管理和维护。

```csharp
// ✅ Biz 文件内部：简洁美观，查询逻辑集中管理
public static IList<Conversation> Search(Int32 userId, String? keyword, PageParameter page)
{
    var exp = new WhereExpression();
    if (userId > 0) exp &= _.UserId == userId;
    if (!keyword.IsNullOrEmpty()) exp &= _.Title.Contains(keyword.Trim());
    return FindAll(exp, page);
}

// ❌ 外部业务代码：臃肿、类名前缀重复、散落各处难以维护
var exp = new WhereExpression();
if (userId > 0) exp &= Conversation._.UserId == userId;
if (!keyword.IsNullOrEmpty()) exp &= Conversation._.Title.Contains(keyword.Trim());
var list = Conversation.FindAll(exp, p);
```

**对比总结**：

| 维度 | Biz 文件内部 | 外部业务代码 |
|------|-------------|-------------|
| 字段访问 | `_.Name` | `ClassName._.Name` |
| 代码量 | 简洁紧凑 | 臃肿冗余 |
| 可复用性 | 封装为方法，全局调用 | 散落各处，无法合并 |
| 可维护性 | 查询逻辑集中修改 | 修改时需全局搜索替换 |

### 完整示例

```csharp
partial class Conversation
{
    #region 高级查询

    /// <summary>根据用户编号查找最新一条会话</summary>
    /// <param name="userId">用户编号</param>
    /// <returns>会话对象，不存在时返回 null</returns>
    public static Conversation? FindByUserId(Int32 userId) => Find(_.UserId == userId);

    /// <summary>根据用户编号查找所有会话</summary>
    /// <param name="userId">用户编号</param>
    /// <returns>会话列表，不存在时返回空列表</returns>
    public static IList<Conversation> FindAllByUserId(Int32 userId) =>
        FindAll(_.UserId == userId);

    /// <summary>分页搜索会话列表</summary>
    /// <param name="userId">用户编号，0 不过滤</param>
    /// <param name="start">创建时间起始</param>
    /// <param name="end">创建时间截止</param>
    /// <param name="key">标题关键字，空时不过滤</param>
    /// <param name="page">分页参数</param>
    /// <returns>会话列表，不存在时返回空列表</returns>
    public static IList<Conversation> Search(Int32 userId, DateTime start, DateTime end,
        String? key, PageParameter page)
    {
        var exp = new WhereExpression();
        if (userId > 0) exp &= _.UserId == userId;
        if (start > DateTime.MinValue) exp &= _.CreateTime >= start;
        if (end > DateTime.MinValue) exp &= _.CreateTime < end;
        if (!key.IsNullOrEmpty()) exp &= _.Title.Contains(key.Trim());

        return FindAll(exp, page);
    }

    #endregion
}
```

### AI 编码与重构指引

**新写代码时**：所有根据字段查询数据的逻辑，都必须在 Biz 文件中封装查询方法（`FindByXxx` / `FindAllByXxx` / `Search`），外部调用方通过方法名传入语义化参数，不直接拼接 `WhereExpression`。

**重构代码时**：遇到散落在实体类外部的字段查询（如 `ClassName._.Field == value`、外部拼接 `WhereExpression`），应当：
1. 在对应实体的 Biz 文件中新建或复用已有的查询方法
2. 将外部调用改为调用该查询方法

**重构前**（查询散落在外部 Service/Controller 中）：

```csharp
// ❌ 在 OrderService 中直接拼接查询表达式
public IList<Order> GetUserOrders(Int32 userId, String? keyword)
{
    var exp = new WhereExpression();
    exp &= Order._.UserId == userId;
    exp &= Order._.Status > 0;
    if (!keyword.IsNullOrEmpty()) exp &= Order._.OrderNo.Contains(keyword.Trim());
    return Order.FindAll(exp, null);
}
```

**重构后**（查询封装到 Biz 文件，外部改为调用）：

```csharp
// ✅ Order.Biz.cs 内
partial class Order
{
    #region 高级查询

    /// <summary>搜索订单列表</summary>
    /// <param name="userId">用户编号，0 不过滤</param>
    /// <param name="key">订单号关键字，空时不过滤</param>
    /// <param name="page">分页参数</param>
    /// <returns>订单列表，不存在时返回空列表</returns>
    public static IList<Order> Search(Int32 userId, String? key, PageParameter? page)
    {
        var exp = new WhereExpression();
        if (userId > 0) exp &= _.UserId == userId;
        exp &= _.Status > 0;
        if (!key.IsNullOrEmpty()) exp &= _.OrderNo.Contains(key.Trim());
        return FindAll(exp, page);
    }

    #endregion
}

// ✅ OrderService 中调用
public IList<Order> GetUserOrders(Int32 userId, String? keyword)
    => Order.Search(userId, keyword, null);
```

## 脏字段追踪

实体从数据库加载后，自动追踪哪些字段被修改过，Update 时**仅更新脏字段**（减少 SQL 字段数）：

```csharp
var user = User.FindByKey(1);
user.HasDirty;              // 是否有未保存的修改
user.Dirtys["Name"];        // Name 字段是否被修改
user.IsDirty(nameof(Name)); // 同上
```

## Valid 验证钩子

Insert/Update/Delete 前自动调用，**返回 false 阻止操作**：

```csharp
public override Boolean Valid(DataMethod method)
{
    // Delete 通常只做必要检查
    if (method == DataMethod.Delete) return true;

    // 未修改时跳过（提升 Update 性能）
    if (!HasDirty) return true;

    // 必填校验
    if (Name.IsNullOrEmpty()) throw new ArgumentNullException(nameof(Name), "名称不能为空");

    // 长度校验
    if (Name.Length > 50) throw new ArgumentException("名称不能超过50个字符", nameof(Name));

    // 新增时特有逻辑（拦截器未覆盖时手动设置）
    if (method == DataMethod.Insert)
        Enable = true;

    return base.Valid(method);  // 调用基类：触发拦截器链 + 字符串长度自动截断
}
```

**`DataMethod` 枚举**：`None` / `Insert` / `Update` / `Delete` / `Upsert`

## 内置拦截器（按字段名自动激活）

实体包含特定命名字段时，**无需代码手动赋值**，拦截器在 Insert/Update 时自动填充：

| 拦截器 | 匹配字段名 | 类型 | 触发时机 |
|--------|-----------|------|---------|
| `TimeInterceptor` | `CreateTime` | `DateTime` | Insert |
| | `UpdateTime` | `DateTime` | Insert + Update |
| `UserInterceptor` | `CreateUserID` | `Int32`/`Int64` | Insert |
| | `CreateUser` | `String` | Insert |
| | `UpdateUserID` | `Int32`/`Int64` | Insert + Update |
| | `UpdateUser` | `String` | Insert + Update |
| `IPInterceptor` | `CreateIP` | `String` | Insert |
| | `UpdateIP` | `String` | Insert + Update |
| `TraceInterceptor` | `TraceId` | `String` | Insert + Update |

**关键细节**：
- `UserInterceptor.AllowEmpty = false`（默认）— 无登录用户时不清空已记录的操作人
- `TraceInterceptor.AllowMerge = true` — 多个 Trace 修改同一记录时联接所有 TraceId

**Model.xml 建模约定**（对应字段设 `Model="False" Category="扩展"`，不暴露到模型类）：

```xml
<Column Name="CreateTime"   DataType="DateTime" Nullable="False" Model="False" Category="扩展" Description="创建时间" />
<Column Name="CreateUser"   DataType="String"                    Model="False" Category="扩展" Description="创建者" />
<Column Name="CreateUserID" DataType="Int32"                     Model="False" Category="扩展" Description="创建者ID" />
<Column Name="CreateIP"     DataType="String"                    Model="False" Category="扩展" Description="创建IP" />
<Column Name="UpdateTime"   DataType="DateTime"                  Model="False" Category="扩展" Description="更新时间" />
<Column Name="UpdateUser"   DataType="String"                    Model="False" Category="扩展" Description="更新者" />
<Column Name="UpdateUserID" DataType="Int32"                     Model="False" Category="扩展" Description="更新者ID" />
<Column Name="UpdateIP"     DataType="String"                    Model="False" Category="扩展" Description="更新IP" />
<Column Name="TraceId"      DataType="String"                    Model="False" Category="扩展" Description="链路追踪" />
```

## EntityTransaction 实体事务

```csharp
// 推荐：强类型事务（自动绑定对应实体的数据库连接）
using var et = new EntityTransaction<Order>();
try
{
    var order = new Order { ... };
    order.Insert();

    var detail = new OrderDetail { OrderId = order.Id, ... };
    detail.Insert();

    et.Commit();  // 显式提交；未 Commit 则离开 using 时自动回滚
}
catch
{
    // using 块结束自动回滚
    throw;
}

// 指定连接名事务
using var et2 = new EntityTransaction(DAL.Create("Order"));
```

**缓存联动**：
- 事务内裸 SQL → 强制清空缓存
- 事务提交成功 → 按正常逻辑更新缓存
- 事务回滚 → 强制清空所有缓存

## InitData 种子数据

**执行时机**：应用启动 → 首次访问实体 → 建表完成 → `InitData()` 执行一次。

```csharp
partial class Role
{
    protected override void InitData()
    {
        if (Meta.Count > 0) return;  // 幂等：已有数据直接返回

        var roles = new[]
        {
            new Role { Name = "管理员", Enable = true, Sort = 1 },
            new Role { Name = "普通用户", Enable = true, Sort = 2 },
        };
        roles.Insert();
    }
}
```

**特点**：线程安全（Monitor 保证只执行一次）；`InitData` 内查询其他表时会自动触发对应表的 `WaitForInitData()`。

## EntityQueue 异步批写

高频写入场景（日志、访问统计等）：将实体操作批量化、异步化降低 DB 压力。

```csharp
// 最简用法：SaveAsync 隐式使用队列
await log.SaveAsync(3000);   // 延迟 3 秒批量写入

// 直接使用队列（如批量 Insert Only）
var queue = new EntityQueue(AccessLog.Meta.Session)
{
    Method = DataMethod.Insert,
    InsertOnly = true,
};
foreach (var log2 in logs)
    queue.Add(log2, 0);

queue.Dispose();  // Dispose 等待最多 3s 完成剩余刷出
```

**关键配置**：

| 属性 | 默认 | 说明 |
|------|------|------|
| `Method` | 自动 | 强制写入方式（Insert/Update/Upsert）|
| `InsertOnly` | `false` | true 时仅批量 Insert，跳过 Upsert |
| `MaxEntity` | 100 万 | 队列深度上限，超出时写入线程阻塞 15s |
| `Speed` | 只读 | 上次刷出速度（TPS）|

## XCodeSetting 关键配置

通过 `XCode.json` 或 `appsettings.json` 的 `"XCode"` 节配置：

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `Debug` | `true` | 调试日志 |
| `ShowSQL` | `true` | 输出 SQL 语句 |
| `SQLPath` | `""` | SQL 日志独立目录（生产环境建议设置）|
| `TraceSQLTime` | `1000` | 慢查询阈值（毫秒）|
| `Migration` | `On` | 反向工程模式（Off/ReadOnly/On/Full）|
| `BatchSize` | `5000` | 批量操作数据量 |
| `EntityCacheExpire` | `10` | 实体缓存过期时间（秒）|
| `SingleCacheExpire` | `10` | 单对象缓存过期时间（秒）|

```json
{
  "XCode": {
    "Migration": "Off",
    "ShowSQL": false,
    "SQLPath": "../SqlLog",
    "TraceSQLTime": 500
  }
}
```

## EntityFactory 初始化（应用启动）

```csharp
// 初始化所有连接（建表 + 初始化种子数据）
EntityFactory.InitAll();

// 只初始化指定连接
EntityFactory.InitConnection("Order");

// 只初始化单个实体
EntityFactory.InitEntity(typeof(User));

// 异步并行初始化（多连接时推荐）
await EntityFactory.InitAllAsync();
```

## 查询方法完整签名

### 单对象查询（返回 TEntity?）

| 方法 | 说明 |
|------|------|
| `FindByKey(Object key)` | 按主键查找，未找到返回 null |
| `FindByKey(Object key, String? selects)` | 按主键查找，仅返回指定列 |
| `FindByKeyForEdit(Object key)` | 按主键查找；**主键为空或记录不存在时返回新实例**，用于编辑页 |
| `FindByKeyWithCache(Object key)` | 从 SingleCache 查找，适合只读高频访问 |
| `FindBySlaveWithCache(String slaveKey)` | 按从键从 SingleCache 查找 |
| `Find(Expression where)` | 按 WhereExpression 查找单条 |
| `Find(Expression where, String? selects)` | 按表达式查找，指定返回列 |
| `Find(String whereClause)` | 按字符串条件查找（无类型安全） |
| `Find(String name, Object value)` | 按单字段名-值查找 |
| `Find(String[] names, Object[] values)` | 按多字段名-值查找 |
| `FindAsync(Expression where)` | 异步查找单条 |

```csharp
// 编辑页标准用法：id==0 或记录不存在时都返回空实体
var user = User.FindByKeyForEdit(id);  // 不会返回 null
user.Name = "new name";
user.Save();  // 自动判断 Insert 还是 Update

// 只读高频场景：先走单对象缓存
var user2 = User.FindByKeyWithCache(1);
```

### FindAll 分页查询全集

| 方法 | 说明 |
|------|------|
| `FindAll()` | 获取全表（大表慎用） |
| `FindAll(Expression? where, String? order, String? selects, Int64 startRow, Int64 maxRows)` | 标准分页 |
| `FindAll(Expression? where, PageParameter? page, String? selects)` | PageParameter 分页（推荐） |
| `FindAll(String sql)` | 直接执行 SQL 返回实体列表 |
| `FindAllWithCache()` | 从 EntityCache 查找全部 |
| `FindAllAsync(Expression where, PageParameter? page, String? selects)` | 异步分页 |

```csharp
// PageParameter 标准分页
var page = new PageParameter { PageIndex = 1, PageSize = 20 };
var list = User.FindAll(User._.Status == 1, page);
// 查询后 page.TotalCount 已被自动赋值

// 带统计（同时返回 totalCount 与 state 合计值）
page.RetrieveTotalCount = true;
page.RetrieveState = true;
```

### 统计与聚合

| 方法 | 返回 | 说明 |
|------|------|------|
| `FindCount()` | `Int64` | 全表计数 |
| `FindCount(Expression where, ...)` | `Int64` | 条件计数 |
| `FindCount(String where, ...)` | `Int32` | 字符串条件计数（遗留） |
| `FindMin(String field, Expression? where)` | `Decimal` | 查字段最小值 |
| `FindMax(String field, Expression? where)` | `Decimal` | 查字段最大值 |
| `FindData(Expression, String, String, Int64, Int64)` | `DbTable` | 返回内存数据表（非实体列表） |

```csharp
var count = Order.FindCount(Order._.Status == 1);
var minPrice = Order.FindMin("TotalAmount", Order._.Status == 1);
var maxPrice = Order.FindMax("TotalAmount", Order._.Status == 1);

// DbTable 适合统计汇总场景（避免创建大量实体对象）
var dt = Order.FindData(Order._.Status == 1, "CreateTime", "Id,Status,TotalAmount", 0, 100);
```

### SQL 构建与子查询

```csharp
// 构造 SelectBuilder 用于外层包装
var builder = User.CreateBuilder(User._.Status == 1, "Id desc", "Id,Name");

// FindSQL 得到 SelectBuilder，用于子查询
var subSql = User.FindSQL(null, null, "Id");
// 外层可用 WHERE Id IN (subSql)
```

## 存在性检查

```csharp
partial class User
{
    public override void Valid(Boolean isNew)
    {
        base.Valid(isNew);
        // 检查 Name 是否已存在（会自动排除当前记录）
        CheckExist(isNew, nameof(Name));

        // 组合唯一：Name+Email
        CheckExist(isNew, nameof(Name), nameof(Email));
    }
}

// 非 Valid 内部也可使用
var exists = user.Exist(nameof(Name));        // 返回 bool
var exists2 = user.Exist(true, nameof(Name)); // 显式指定 isNew
```

## 高并发 GetOrAdd 模式

适合统计场景：按某键"查则返回，无则新建"，避免并发重复插入：

```csharp
// 统计每天每用户的访问数，并发安全
var stat = DailyStat.GetOrAdd(
    userId,
    (k, isNew) => DailyStat.FindByUserDate(k, today),   // 查找函数
    k => new DailyStat { UserId = k, Date = today, Count = 0 }  // 创建函数
);
stat.Count++;
stat.Update();
```

等效于 `Find → 若null则Create + Insert → 返回`，内部加锁防止并发重建。

## 跨类型复制 CopyFrom

```csharp
// 将 UserModel（非实体类）的字段复制到 User 实体
var user = new User();
user.CopyFrom(model, setDirty: true, getDirty: false);
user.Save();

// 两个同类实体：仅复制有脏数据的字段（差量复制）
var user2 = User.FindByKey(1);
user2.CopyFrom(user, setDirty: true, getDirty: true);
```

## 静态批量操作

### 批量更新（不加载实体）

```csharp
// UPDATE User SET Status=2 WHERE Status=1
User.Update(User._.Status.SetValue(2), User._.Status == 1);

// 累加字段（AdditionalFields 字段）
User.Update("LoginCount=LoginCount+1,LastLoginTime=Now()", "Id=1");
```

### 批量删除（分批安全删除）

```csharp
// 删除全部满足条件的记录
User.Delete(User._.Status == 0);

// 分批删除：每批最多 1000 行，防止大批量删除锁表
User.Delete(User._.Status == 0, maximumRows: 1000);
```

### 批量Insert（高性能）

```csharp
// BatchInsert：一次提交多行，比逐条 Insert 快 5-10x
var list = new List<User> { ... };
list.BatchInsert();

// 忽略重复冲突的批量插入（MySQL 的 INSERT IGNORE）
list.BatchInsertIgnore();

// 自定义 BatchOption
list.BatchInsert(new BatchOption { BatchSize = 500 });

// 验证后批量插入（会触发 Valid 钩子）
var validated = list.Valid(isNew: true);
validated.BatchInsert();
```

## EntityTransaction 事务详解

```csharp
// 1. 强类型（最常用）：自动绑定 TEntity 对应的数据库连接
using var et = new EntityTransaction<Order>();
try
{
    var order = new Order { ... };
    order.Insert();                                // 同一事务内
    new OrderDetail { OrderId = order.Id }.Insert();
    et.Commit();
}
catch { throw; }  // using 块结束时自动 Rollback

// 2. 指定隔离级别
using var et2 = new EntityTransaction(DAL.Create("MyDb"), IsolationLevel.Serializable);

// 3. 多个实体同一数据库（用 DAL 共享连接）
var dal = DAL.Create("Order");
using var et3 = new EntityTransaction(dal);
// Order / OrderDetail 只要 ConnName 相同，都在同一事务内
```

**IsolationLevel 可选值**：`ReadUncommitted` / `ReadCommitted`（默认）/ `RepeatableRead` / `Serializable`

## PageParameter 完整属性

| 属性 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `PageIndex` | `Int32` | 1 | 页码（1-based） |
| `PageSize` | `Int32` | 20 | 每页行数 |
| `StartRow` | `Int64` | -1 | 直接指定起始行（0-based，与 PageIndex 二选一） |
| `TotalCount` | `Int64` | — | **查询后自动写入**总记录数 |
| `RetrieveTotalCount` | `Boolean` | false | 是否统计总数 |
| `State` | `Object?` | — | 统计附加数据（如合计金额）|
| `RetrieveState` | `Boolean` | false | 是否检索 State |

## 注意事项

- **禁止在 `Valid` 外部手动赋值审计字段**（CreateTime/UpdateTime 等）；拦截器自动处理。
- `FindAll` 返回的是引用，避免在缓存列表上直接修改实体后不 `Update()`。
- `SaveAsync` 有延迟，不适合需要立即可查的场景（用普通 `Save()`）。
- `BatchFinder` 解决表关联的 N+1 查询，参见 `xcode-data-access-layer` 技能。
- `FindByKeyForEdit` 解决编辑页 key==0 空对象问题，**不要手动判断 null**后再 `new`。
- `Delete(Expression, maximumRows)` 支持分表；`Delete(String)` 不支持，大表批量删除必须用前者。
- `BatchInsert` 不触发 `Valid`，需手动调用 `list.Valid(true)` 后再批量插入。
- `GetOrAdd` 内部用 `Monitor.TryEnter` 加锁，高并发统计场景务必用此方法代替手写判断。
- 实体类在项目中的架构定位（两层 vs 三层、何时需要 Service 层），参见 `project-architecture` 技能。
