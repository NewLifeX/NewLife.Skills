---
name: xcode-data-access-layer
description: >
  使用 NewLife.XCode 数据访问层（DAL）进行直接 SQL 操作和高级查询构建，
  涵盖 DAL.Create() 全局实例、SelectBuilder SQL 构建与解析、
  WhereExpression 类型安全条件运算符（防 SQL 注入）、
  ReadWriteStrategy 读写分离，以及 BatchFinder 解决 N+1 查询问题。
  适用于复杂查询构建、跨表统计、读写分离配置、批量关联数据加载等任务。
argument-hint: >
  说明查询场景：是否需要跨表原生 SQL；条件是否复杂（多字段组合/模糊/区间）；
  是否有读写分离需求；是否存在循环逐条查询的 N+1 性能问题。
---

# XCode 数据访问层（DAL）

## 适用场景

- 使用 `WhereExpression` 构建类型安全的查询条件，防止 SQL 注入。
- 直接通过 `DAL` 执行原生 SQL（跨表查询、自定义统计）。
- 用 `SelectBuilder` 构建/解析/二次修改复杂查询语句。
- 配置读写分离，将查询压力分散到只读副本。
- 用 `BatchFinder` 消除关联数据加载中的 N+1 查询问题。

## WhereExpression — 查询条件表达式

`WhereExpression` 是 XCode 防 SQL 注入的核心工具。通过 `ClassName._` 获取字段定义，使用运算符重载拼接条件。

### 基础运算符

```csharp
// 等值 / 不等
User._.Status == 1
User._.Name != "admin"

// 比较
User._.Age > 18
User._.CreateTime >= DateTime.Today
User._.Score <= 100.0

// 模糊匹配
User._.Name.Contains("alice")     // LIKE '%alice%'
User._.Name.StartsWith("A")       // LIKE 'A%'
User._.Email.EndsWith(".cn")      // LIKE '%.cn'

// IN 查询
User._.Id.In(new[] { 1, 2, 3 })
User._.Status.In(new[] { 1, 2 })
User._.Id.NotIn(blockedIds)

// NULL 判断
User._.DeleteTime.IsNull()
User._.DeleteTime.NotNull()

// 排序（用于 FindAll 的 order 参数）
User._.CreateTime.Desc()
User._.Name.Asc()
```

### 组合条件

```csharp
// AND 组合（& 运算符）
var exp = User._.Status == 1 & User._.Age >= 18;

// OR 组合（| 运算符）
var exp2 = User._.Type == 1 | User._.Type == 2;

// 动态拼接（推荐模式）
var exp3 = new WhereExpression();
exp3 &= _.UserId == userId;                                 // 必须条件
if (start > DateTime.MinValue) exp3 &= _.CreateTime >= start;
if (end > DateTime.MinValue)   exp3 &= _.CreateTime < end;
if (!key.IsNullOrEmpty())      exp3 &= _.Name.Contains(key.Trim());

var list = User.FindAll(exp3, page);
```

### 在 FindAll 系列中使用

```csharp
// 完整签名：FindAll(where, orderBy, select, startRowIndex, maximumRows)
var list = User.FindAll(
    User._.Status == 1,
    User._.CreateTime.Desc(),
    null,   // select *
    0,      // offset
    20      // limit
);

// 带分页参数（推荐）
var page = new PageParameter { PageIndex = 1, PageSize = 20 };
var list2 = User.FindAll(User._.Status == 1, page);

// 统计
var count = User.FindCount(User._.Status == 1);
```

## SelectBuilder — SQL 查询构建器

用于构建或解析 SELECT 语句，支持二次修改。

```csharp
// 从零构建
var sb = new SelectBuilder
{
    Table = "User",
    Column = "Id, Name, CreateTime",
    Where = "Status = 1",
    OrderBy = "CreateTime Desc",
};
var sql = sb.ToString();
// SELECT Id, Name, CreateTime FROM User WHERE Status = 1 ORDER BY CreateTime Desc

// 解析已有 SQL 再修改
var sb2 = new SelectBuilder("SELECT * FROM User WHERE Status = 1");
sb2.Where += " AND RoleId = 2";
sb2.OrderBy = "Id Desc";
sb2.Limit = "LIMIT 0, 20";

// 通过 DAL 执行
var ds = DAL.Create("MyDb").Select(sb2.ToString());
```

## DAL — 数据访问层

```csharp
// 按连接名获取全局唯一实例
var dal = DAL.Create("MyDb");

// 核心属性
dal.ConnName    // 连接名
dal.DbType      // 数据库类型（DatabaseType 枚举）
dal.ShowSQL     // 是否输出 SQL 日志

// 查询 DataSet
var ds = dal.Select("SELECT * FROM User WHERE Status = 1");

// 查询 DataTable（第一个表）
var dt = dal.SelectTable("SELECT Id, Name FROM User");

// 执行非查询语句（返回受影响行数）
var rows = dal.Execute("UPDATE User SET Status = 0 WHERE Id = @Id",
    CommandType.Text,
    new DbParameter[] { new SqlParameter("@Id", 1) });

// 查询标量（COUNT / SUM 等）
var count = dal.SelectCount("SELECT COUNT(*) FROM User WHERE Status = 1");

// 查询实体列表（通过 SQL 映射到实体）
var users = User.FindAllBySQL("SELECT * FROM User WHERE Status = 1");
```

## ReadWriteStrategy — 读写分离

在连接字符串中配置主库和只读副本：

```json
{
  "ConnectionStrings": {
    "Order": "Server=master;Database=Order;Uid=sa;Pwd=xxx",
    "OrderSlave0": "Server=slave1;Database=Order;Uid=sa;Pwd=xxx;readonly=true",
    "OrderSlave1": "Server=slave2;Database=Order;Uid=sa;Pwd=xxx;readonly=true"
  }
}
```

**规则**：
- 写操作（Insert/Update/Delete）→ 自动路由到主库
- 读操作（FindAll/FindCount）→ 按策略路由到只读副本
- 连接名规则：`{主连接名}Slave{序号}`

代码层面也可显式指定：

```csharp
// 临时指定读连接（强制从主库读，如写后立即读）
using (EntitySplit.Begin(null, User.Meta.ConnName))
{
    var user = User.FindByKey(newUserId);
}
```

## BatchFinder — 解决 N+1 查询

**问题**：批量处理数据时，关联实体逐条查询导致 N 次数据库往返。

```csharp
// ❌ 反例：N+1 查询（100 条记录 = 100 次查询）
foreach (var log in logs)
{
    var user = User.FindById(log.UserId);   // 每次都查 DB
    Console.WriteLine($"{user?.Name}: {log.Action}");
}

// ✅ 正例：BatchFinder（一次 IN 查询，多次内存取用）
var finder = new BatchFinder<Int32, User>(logs.Select(e => e.UserId));
foreach (var log in logs)
{
    var user = finder.FindByKey(log.UserId);  // 内存命中
    Console.WriteLine($"{user?.Name}: {log.Action}");
}
```

**核心配置**：

| 属性 | 默认 | 说明 |
|------|------|------|
| `BatchSize` | `500` | 每次 IN 查询最大条数（自动分批）|
| `Callback` | `null` | 自定义查询函数（追加过滤或指定从库）|
| `Cache` | `ConcurrentDictionary` | 可预填充已有实体，只查未命中的 |

```csharp
// 预填充已有数据（避免重复查询）
var finder = new BatchFinder<Int32, User>(allUserIds);
foreach (var cached in onlineUsers)
    finder.Cache[cached.Id] = cached;

// FindByKey 只会查询 Cache 中不存在的 ID
var user4 = finder.FindByKey(someId);
```

## DAL.Query\<T\> — 泛型结果映射

`DAL_Mapper` 提供了类似 Dapper 的泛型映射能力，可将 SQL 查询结果直接映射到任意类型：

```csharp
var dal = DAL.Create("MyDb");

// 映射至自定义 DTO 或实体类
IEnumerable<UserDto> users = dal.Query<UserDto>(
    "SELECT Id, Name, Status FROM User WHERE Status = @s",
    new { s = 1 });

// 映射单行
UserDto? user = dal.QuerySingle<UserDto>(
    "SELECT * FROM User WHERE Id = @id",
    new { id = 42 });

// 映射基础类型（返回第一列）
IEnumerable<Int32> ids = dal.Query<Int32>("SELECT Id FROM User WHERE Status = 1");

// 异步版本
IEnumerable<UserDto> users2 = await dal.QueryAsync<UserDto>(
    "SELECT * FROM User WHERE Status = @s",
    new { s = 1 });
UserDto? user3 = await dal.QuerySingleAsync<UserDto>(
    "SELECT * FROM User WHERE Id = @id",
    new { id = 42 });

// 支持分页
IEnumerable<UserDto> paged = dal.Query<UserDto>(
    "SELECT * FROM User ORDER BY Id",
    null, startRowIndex: 20, maximumRows: 10);

// 带 PageParameter 分页
var page = new PageParameter { PageIndex = 2, PageSize = 20, RetrieveTotalCount = true };
IEnumerable<UserDto> paged2 = dal.Query<UserDto>(
    "SELECT * FROM User ORDER BY Id",
    null, page);
// page.TotalCount 已自动设置
```

**参数传递规则**：
- `param` 接受匿名对象（`new { s = 1 }`）或字典（`Dictionary<String, Object>`）
- 参数名与 SQL 中 `@param` 对应（不区分大小写）
- **不支持 `ValueTuple` 作为泛型类型**

### DAL 原生执行（参数化）

```csharp
// Execute 也支持匿名对象参数——比 CommandType 重载更简洁
Int32 rows = dal.Execute(
    "UPDATE User SET Status=@s WHERE Id=@id",
    new { s = 0, id = 42 });

// ExecuteScalar 获取标量
Int32? total = dal.ExecuteScalar<Int32>(
    "SELECT COUNT(*) FROM User WHERE Status = @s",
    new { s = 1 });

// ExecuteReader — 低层只读流（记得用 using 关闭）
using var reader = dal.ExecuteReader("SELECT Id, Name FROM User");
while (reader.Read())
    Console.WriteLine(reader["Name"]);
```

### ReadWriteStrategy 精细控制

除基础读写分离外，可按时段/表名强制走主库：

```csharp
var dal = DAL.Create("Order");
var strategy = dal.Strategy;

// 配置在 00:00-01:00 期间忽略读写分离（走主库，避免主从延迟导致统计误差）
strategy.IgnoreTimes.Add(new TimeRegion { Start = TimeSpan.FromHours(0), End = TimeSpan.FromHours(1) });

// 特定表名始终走主库（如 OrderStat 统计表写后立即读）
strategy.IgnoreTables.Add("OrderStat");
```

## 注意事项

- `WhereExpression` 所有条件均参数化，**永远不要拼接用户输入到 SQL 字符串**——这是防止 SQL 注入的根本。
- `SelectBuilder` 适合需要动态构建分页/子查询的复杂场景；简单查询优先使用 `FindAll + WhereExpression`。
- 读写分离场景中，**写后立即读**若业务不允许主从延迟，需显式绑定主库（使用 `EntitySplit.Begin`）。
- `BatchFinder` 适合一次性批量处理（如报表导出）；若需长期高频查单条，用 `SingleCache` 更合适。
- `DAL.Query<T>` **不支持 ValueTuple** 映射，会抛出 `InvalidOperationException`。
- `ExecuteReader` 返回的 `IDataReader` 必须在 `using` 块内使用，底层连接随 reader close 而释放。
