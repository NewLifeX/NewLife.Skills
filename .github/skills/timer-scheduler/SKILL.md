---
name: timer-scheduler
description: >
  使用 NewLife.Threading.TimerX 实现高级定时任务，涵盖周期执行、异步回调、绝对时间触发、
  Cron 表达式调度、动态调整执行间隔（SetNext）、延迟批处理队列（DeferredQueue），
  以及避免 System.Threading.Timer 可重入问题的正确模式。
  适用于后台任务调度、定时数据采集、定期清理、批量写入合并等场景。
argument-hint: >
  说明你的调度需求：周期性执行（指定间隔毫秒）还是按固定时刻（每天 2 点）；
  是否需要 Cron 表达式；是否有可重入风险（耗时操作）；
  是否需要延迟批量写入合并（DeferredQueue）。
---

# 定时器与任务调度技能

## 适用场景

- 后台周期性任务（数据采集、健康检查、缓存刷新），需要防止任务并发重入。
- 按固定时刻执行（每天凌晨清理、每月账单生成）—— 用绝对时间或 Cron 表达式。
- 业务逻辑需要根据运行结果动态调整下一次执行间隔（如自适应轮询）—— 用 `SetNext`。
- 高频写操作（每秒 N 次设备上报、计数更新）需要合并为批量落库，降低数据库压力 —— 用 `DeferredQueue`。
- 代码审查：识别 `System.Threading.Timer` 的可重入问题，确认定时器在服务停止时被 `Dispose`。

## 核心原则

1. **TimerX 不可重入**：上一次回调执行完毕后，才开始计算下一次倒计时；`System.Threading.Timer` 默认可重入，耗时操作会并发重叠。
2. **优先使用异步回调**：涉及 I/O 的任务使用 `Func<Object, Task>` 构造函数，TimerX 自动设置 `IsAsyncTask = true`；同步回调阻塞调度线程。
3. **绝对时间 vs 相对时间**：固定时刻用 `DateTime` 或 Cron 构造（自动设置 `Absolutely = true`）；相对周期用毫秒构造；混用 `SetNext` 只对相对周期有效。
4. **DeferredQueue 的写入合并**：相同 key 在同一周期内只保留最新值 —— 天然解决 "最后状态同步" 类场景的冗余写问题。
5. **安全释放**：`TimerX` 挂载在静态调度器上，防止被 GC；服务停止时必须 `Dispose`；`DeferredQueue.Dispose` 会自动 `Flush` 尾批数据。

## 执行步骤

### 一、周期性任务（基础用法）

```csharp
using NewLife.Threading;

// 1 秒后首次执行，之后每 5 秒一次
var timer = new TimerX(state =>
{
    Console.WriteLine($"执行：{DateTime.Now}");
}, null, dueTime: 1_000, period: 5_000);

// 只执行一次（period = 0）
var once = new TimerX(_ => DoCleanup(), null, dueTime: 500, period: 0);
```

### 二、异步回调（推荐 I/O 场景）

```csharp
// 使用 Func<Object, Task> — 自动标记为异步任务模式
var timer = new TimerX(async state =>
{
    var data = await FetchDataAsync();
    await SaveAsync(data);
}, null, dueTime: 1_000, period: 30_000);
```

### 三、绝对时间与 Cron 表达式

```csharp
// 每天凌晨 2 点执行（startTime 过期时自动加 period 对齐）
var start = DateTime.Today.AddHours(2);
var dailyTimer = new TimerX(_ =>
{
    RunNightlyCleanup();
}, null, startTime: start, period: 24 * 3600 * 1000);

// Cron 表达式：每个工作日 9:30（秒 分 时 日 月 星期）
var workdayTimer = new TimerX(async _ =>
{
    await SendDailyReport();
}, null, cronExpression: "0 30 9 * * 1-5");

// 多个时间点（分号分隔）：工作日凌晨 2 点 + 周六凌晨 3 点
var multiTimer = new TimerX(_ => { }, null, "0 0 2 * * 1-5;0 0 3 * * 6");
```

**Cron 字段顺序**（6 位，与 Quartz 不同，无"年"字段）：
```
秒(0-59)  分(0-59)  时(0-23)  日(1-31)  月(1-12)  星期(0-6，0=周日)
```

常用模式：
```
*/10 * * * * *       每 10 秒
0 */5 * * * *        每 5 分钟整
0 0 * * * *          每小时整点
0 0 2 * * *          每天凌晨 2 点
0 0 9-17 * * 1-5     工作日 9–17 点每整点
0 0 0 1 * *          每月 1 号凌晨
```

### 四、动态调整执行间隔（SetNext）

```csharp
TimerX? _poller = null;

_poller = new TimerX(state =>
{
    var hasData = PollQueue();

    if (hasData)
        _poller!.SetNext(100);   // 有数据：100 ms 后继续
    else
        _poller!.SetNext(5_000); // 空闲：5 秒后检查
}, null, dueTime: 0, period: 5_000);
```

> **注意**：`SetNext` 对 `Absolutely = true` 的定时器（绝对时间/Cron）无效。

### 五、DeferredQueue — 延迟批处理

适合场景：设备每秒 N 次上报、高频计数更新，不能逐条落库。

```csharp
using NewLife.Model;

var dq = new DeferredQueue
{
    Name      = "DeviceSave",
    Period    = 5_000,      // 每 5 秒触发一批
    BatchSize = 1_000,      // 单批最多 1000 条
    Finish    = list =>
    {
        // list 中相同 key 已合并为最新值
        SaveBatch(list.Cast<DeviceStatus>());
    },
    Error = (list, ex) => XTrace.WriteException(ex),
};

// 高频写入：相同 deviceId 同一周期内自动合并为一条
void OnDeviceReport(Device d)
{
    dq.TryAdd(d.Id.ToString(), d);
}

// 应用退出时（Dispose 自动 Flush 尾批）
using (dq) { /* 等待 Flush */ }
```

#### 借出-提交模式（在已有对象上累加计数）

```csharp
// GetOrAdd：借出对象，批处理等待本次修改完成后再消费
var stat = dq.GetOrAdd<DeviceStat>(deviceId.ToString());
if (stat != null)
{
    stat.Count++;
    stat.LastSeen = DateTime.Now;
    dq.Commit(deviceId.ToString());  // 必须调用，否则对象被锁定
}
```

### 六、Cron 独立使用（不依赖 TimerX）

```csharp
var cron = new Cron("0 0 2 * * 1-5");

// 判断某时刻是否触发
if (cron.IsTime(DateTime.Now)) RunTask();

// 计算下一次执行时间
var next = cron.GetNext(DateTime.Now);

// 计算上一次执行时间
var prev = cron.GetPrevious(DateTime.Now);
```

## 重点检查项

- [ ] 是否误用 `System.Threading.Timer`（可重入），而应换 `TimerX`（不可重入）？
- [ ] 异步任务是否使用了 `Func<Object, Task>` 构造（而非把 `async` lambda 强转为同步 `TimerCallback`）？
- [ ] 服务停止时是否调用了 `timer.Dispose()`（否则定时器会在后台继续运行）？
- [ ] Cron 表达式字段顺序是否正确（NewLife 是"秒 分 时 日 月 星期"，**6 位**，注意与 5 位 Unix cron 的区别）？
- [ ] `DeferredQueue.Dispose` 是否在服务生命周期结束时调用（确保 Flush 尾批）？
- [ ] `DeferredQueue.GetOrAdd` 借出后是否一定调用了 `Commit`（未调用将阻塞批处理线程）？
- [ ] 绝对时间定时器的 `startTime` 是否在过去（TimerX 会自动加 period 对齐，但需确认意图）？

## 输出要求

- **周期任务**：`TimerX`（`NewLife.Threading`）；不可重入、支持异步、内置 APM 埋点。
- **Cron 调度**：`Cron`（`NewLife.Threading`）；6 位表达式（秒~星期），支持 `*`/`,`/`-`/`/`/`L`/`W` 等语法。
- **批量合并**：`DeferredQueue`（`NewLife.Model`）；写入合并、周期批处理、借出-提交模式。
- **配置项**：`TimerX.Period`/`SetNext`/`Absolutely`；`DeferredQueue.Period`/`BatchSize`/`MaxEntity`。

## 参考资料

参考示例与模式证据见 `references/newlife-timer-patterns.md`。
