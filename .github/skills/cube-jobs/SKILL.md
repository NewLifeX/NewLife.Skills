---
name: cube-jobs
description: >
  使用 NewLife.Cube 内置定时作业体系（ICubeJob/CubeJobBase/CronJobAttribute）
  开发和管理周期性后台任务，涵盖接口定义、强类型参数、Cron 表达式、
  依赖注入构造、分布式锁防重、Job.Data 状态持久化、内置作业（HttpService/SqlService/BackupDbService），
  以及 AddCubeJob() 注册与管理后台热修改。
  适用于定时数据统计、定时同步、HTTP 回调、SQL 批处理、数据库备份等后台任务场景。
argument-hint: >
  说明任务类型和触发频率：是纯计算任务、HTTP 请求、SQL 操作还是 XCode 数据库读写；
  是否需要注入其他服务；是否需要跨执行持久化状态（时间指针等）。
---

# Cube 定时作业

## 适用场景

- 定期执行数据统计、日志清理、数据同步、消息推送等后台任务。
- 利用内置 HTTP 作业定时调用外部接口（如 Webhook、健康检查）。
- 利用内置 SQL 作业定时执行数据库维护语句。
- 在管理后台界面热修改 Cron 表达式、参数或启停状态，无需重启服务。
- 分布式部署时通过魔方内置锁机制防止多节点重复执行。

---

## 核心接口

### ICubeJob — 作业接口

```csharp
public interface ICubeJob
{
    /// <summary>执行定时作业</summary>
    /// <param name="argument">JSON 格式参数字符串</param>
    /// <returns>执行结果日志消息</returns>
    Task<String> Execute(String argument);
}
```

### CubeJobBase / CubeJobBase<TArgument>

```csharp
// 基础基类（手动解析参数）
public abstract class CubeJobBase : ICubeJob
{
    public CronJob Job { get; set; }      // 当前作业实体，包含 Data/NextTime 等字段
    public abstract Task<String> Execute(String argument);
}

// 泛型基类（自动 JSON 反序列化参数，推荐使用）
public abstract class CubeJobBase<TArgument> : CubeJobBase where TArgument : class, new()
{
    public override async Task<String> Execute(String argument)
    {
        var arg = argument.IsNullOrEmpty() ? new TArgument() 
                  : argument.ToJsonEntity<TArgument>();
        return await OnExecute(arg);
    }

    protected abstract Task<String> OnExecute(TArgument argument);
}
```

### CronJobAttribute — 声明式注册

```csharp
[AttributeUsage(AttributeTargets.Class)]
public class CronJobAttribute(String name, String cron) : Attribute
{
    public String Name { get; set; } = name;    // 数据库唯一名，修改后视为新作业
    public String Cron { get; set; } = cron;    // 初始 Cron，后续以数据库为准
    public Boolean Enable { get; set; }         // 首次创建时是否自动启用
}
```

---

## 快速自定义作业（推荐模式）

```csharp
using NewLife.Cube.Jobs;

/// <summary>用户活跃度统计</summary>
[DisplayName("用户活跃度统计")]
[Description("每小时统计近30分钟的活跃用户数")]
[CronJob("StatActiveUsers", "0 0 * * * ? *", Enable = true)]   // 每小时整点
public class StatActiveUsersJob : CubeJobBase<StatArgument>
{
    private readonly ITracer _tracer;

    // 支持构造函数依赖注入
    public StatActiveUsersJob(ITracer tracer)
    {
        _tracer = tracer;
    }

    protected override async Task<String> OnExecute(StatArgument arg)
    {
        using var span = _tracer?.NewSpan(nameof(StatActiveUsersJob), arg);

        // 从 Job.Data 读取上次时间指针（跨执行持久化）
        var lastTime = Job.Data.IsNullOrEmpty()
            ? DateTime.Now.AddMinutes(-arg.MinutesBack ?? -30)
            : Job.Data.ToDateTime();

        var count = User.FindCount(User._.LastLoginTime > lastTime);

        // 更新时间指针供下次执行使用
        Job.Data = DateTime.Now.ToString("O");
        Job.Update();

        return $"统计完成，活跃用户数：{count}，时间范围：{lastTime:t}~{DateTime.Now:t}";
    }
}

public class StatArgument
{
    /// <summary>统计时间窗口（分钟），默认 30</summary>
    public Int32? MinutesBack { get; set; } = 30;
}
```

---

## 注册作业

### AddCubeJob() — 服务注册

```csharp
// Program.cs
builder.Services.AddCube();
builder.Services.AddCubeJob();   // 注册作业调度后台服务 + 自动扫描 ICubeJob 实现类
```

`AddCubeJob()` 完成：
1. 注册 `JobService` 为 `IHostedService`（在后台调度作业）。
2. 启动时调用 `BackupDbService.Init()`（注册内置备份作业）。
3. 调用 `JobService.ScanJobs()` 反射扫描所有 `[CronJob]` 特性类，自动创建/更新数据库记录。

### 扫描机制

- 扫描范围：当前 AppDomain 中所有实现 `ICubeJob` 的类型。
- 若数据库中已存在同名（`Name`）作业，**仅更新 DisplayName/Method/Remark**，不重置 Cron/参数/启用状态。
- 若不存在，则新增记录，使用 `CronJobAttribute` 中的初始值。

### 传统静态方法注册（兼容）

```csharp
// 在 Program.cs 或 BackupDbService.Init() 中
CronJob.Add(null, MyClass.MyStaticMethod, "5 0 0 * * ? *", enable: false);
// 参数1：DisplayName（null 取方法 DisplayName 特性）
// 参数2：静态方法委托
// 参数3：Cron 表达式
// 参数4：是否启用
```

---

## 内置作业

### HttpService — HTTP 请求作业

```csharp
// 注册名："RunHttp"，默认 Cron："25 0 0 * * ? *"（每天 00:00:25），默认禁用

// 参数（在管理后台的"参数"字段填 JSON）：
{
  "Method": "GET",               // GET 或 POST
  "Url": "https://api.example.com/trigger",
  "Body": "{\"key\":\"value\"}" // POST 时的请求体
}
```

### SqlService — SQL 执行作业

```csharp
// 注册名："RunSql"，默认 Cron："15 * * * * ? *"（每分钟第15秒），默认禁用

// 参数：
{
  "ConnName": "Master",           // DAL 连接名
  "Sql": "DELETE FROM AccessLog WHERE CreateTime < DATEADD(DAY,-30,GETDATE())"
}
```

### BackupDbService — SQLite 备份作业

```csharp
// 注册名："BackupDb"，默认 Cron："5 0 0 * * ? *"（每天 00:00:05），默认禁用

// 参数（字符串，逗号分隔连接名）：
"Cube,Log"   // 备份 Cube 库和 Log 库（仅支持 SQLite）
```

---

## CronJob 实体字段

```csharp
public class CronJob
{
    public Int32 Id { get; set; }
    public String Name { get; set; }         // 唯一名（代码级固定）
    public String DisplayName { get; set; }  // 显示名（管理后台可编辑）
    public String Cron { get; set; }         // Cron 表达式（管理后台可修改）
    public String Method { get; set; }       // ICubeJob 实现类全名 或 静态方法全名
    public String Argument { get; set; }     // JSON 参数（管理后台可修改）
    public String Data { get; set; }         // 跨执行持久化数据（由 Job 自写）
    public Boolean Enable { get; set; }      // 启停（管理后台可切换）
    public Boolean EnableLog { get; set; }   // 是否记录每次执行日志
    public DateTime LastTime { get; set; }   // 上次执行时间
    public DateTime NextTime { get; set; }   // 下次执行时间（由调度服务计算）
}
```

---

## Cron 表达式速查

魔方使用 Quartz 风格 7 段 Cron（秒 分 时 日 月 周 年）：

| 表达式 | 含义 |
|--------|------|
| `0 0 * * * ? *` | 每小时整点 |
| `0 0 0 * * ? *` | 每天 00:00:00 |
| `0 0 2 * * ? *` | 每天凌晨 02:00 |
| `0 0 0 1 * ? *` | 每月1日 00:00 |
| `0 0 0 * * SUN ? *` | 每周日 00:00 |
| `0/30 * * * * ? *` | 每30秒一次 |
| `0 0/5 * * * ? *` | 每5分钟一次 |
| `0 30 8-18 * * ? *` | 工作时间每小时30分 |
| `5 0 0 * * ? *` | 每天 00:00:05（避开整点） |
| `15 * * * * ? *` | 每分钟第15秒 |

---

## 分布式执行

- `JobService` 在执行前检查分布式锁（基于数据库 `CronJob.LastTime` 或 Redis）。
- 若检测到另一节点正在执行同名作业（`CheckRunning` 返回 true），**本次跳过**，写入调试日志。
- 无需额外配置，内置自动防重复执行。

---

## 管理后台操作

| 功能 | 路径 |
|------|------|
| 查看所有作业列表 | 系统管理 → 定时作业 |
| 修改 Cron 表达式 | 编辑作业 → Cron 字段 |
| 修改参数 | 编辑作业 → 参数字段（JSON） |
| 手动立即执行 | 列表 → 执行按钮 |
| 查看执行日志 | 列表 → 日志明细 |

---

## 常见例外与注意事项

- `CronJobAttribute.Name` 是数据库唯一键，修改后视为新作业，旧记录不会自动删除（需手动处理）。
- `CronJobAttribute.Cron` 仅在**首次创建**记录时有效，之后以数据库中的值为准（避免代码更新覆盖管理员的手动配置）。
- `Job.Data` 在 `OnExecute` 中写入后需手动调用 `Job.Update()` 才能持久化。
- 依赖注入作用域：`JobService` 从 `IServiceProvider` 使用 `GetService` 获取 Job 实例，默认以**单例**方式解析（非 Scoped），如需 Scoped 服务需手动创建 Scope。
- 静态方法方式不支持依赖注入，推荐新代码全部使用 `CubeJobBase<TArgument>`。

## 推荐检查项

- [ ] 是否已调用 `AddCubeJob()`（否则 Job 不会被扫描和调度）
- [ ] `CronJobAttribute.Name` 是否全局唯一（同名作业在同一应用中只会保留一条记录）
- [ ] 需要跨执行持久化的数据是否通过 `Job.Data + Job.Update()` 保存
- [ ] 首次启动后是否在管理后台启用所需作业（内置作业默认 `Enable = false`）
- [ ] 需注入服务的 Job 是否已将服务注册到 DI 容器
