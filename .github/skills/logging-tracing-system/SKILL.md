---
name: logging-tracing-system
description: >
  在 .NET 应用中设计或使用统一日志与链路追踪系统，涵盖 ILog 分级写入、XTrace 静态门面、
  ITracer/ISpan 轻量级 APM 埋点、TraceId 透传，以及日志实现切换（文件/控制台/网络/组合）。
  适用于日志接口设计、链路追踪集成、观测性基础设施建设与代码审查任务。
argument-hint: >
  说明你的可观测性需求：是否只需要日志还是也需要追踪；
  用 XTrace 静态门面还是 DI 注入 ILog；TraceId 是否要跨服务传播；
  需要哪种日志实现（文件/控制台/网络/CompositeLog）。
---

# 日志与链路追踪系统技能

## 适用场景

- 新建 .NET 应用需要快速集成日志，希望面向接口而非绑定某个具体日志框架。
- 已有 `XTrace.WriteLine` 散落各处，需要梳理日志级别、切换日志目标（文件→控制台→网络）。
- 需要在 HTTP/RPC 调用链中传播 `TraceId`，并在本地 `ISpan` 中记录耗时和 Tag。
- 代码审查：确认依赖注入中是否通过 `ILog` / `ILogFeature` 接口接受日志，而非硬编码 `XTrace`。
- 接入 APM 平台，需要实现 `ITracer` 或替换 `DefaultTracer.Instance`。

## 核心原则

1. **接口写日志**：业务类通过 `ILog` 接口记录日志（构造注入或 `ILogFeature.Log` 属性）；只有应用入口和工具类才直接用 `XTrace` 静态门面。
2. **`XTrace` 是全局门面**：`XTrace.Log` 持有当前 `ILog` 实现；`XTrace.WriteLine` 委托给 `XTrace.Log.Info`；切换全局日志实现只需替换 `XTrace.Log`。
3. **日志级别控制**：通过 `ILog.Level` 过滤；`Debug` 级默认不写文件（`XTrace.Debug = true` 才启用）；生产环境至少保留 `Info`。
4. **`ITracer` 轻量 APM**：通过 `DefaultTracer.Instance` 全局替换追踪器；每个操作用 `using var span = tracer.NewSpan("name", tag)` 包裹；`Span.Dispose` 自动上报。
5. **TraceId 透传**：`ISpan` 活跃期间，发出的 HTTP/RPC 请求自动注入 `traceparent`（W3C 标准）；事件总线等组件读取 `DefaultTracer.Current?.TraceId` 写入消息头。
6. **组合日志**：用 `CompositeLog` 将多个 `ILog` 实现合并为一路，替换 `XTrace.Log` 即可同时写文件和控制台。

## 执行步骤

### 一、确定日志目标

| 场景 | 推荐实现 |
|------|---------|
| 默认文件日志 | `TextFileLog`（`XTrace` 自动初始化）|
| 控制台应用调试 | `XTrace.UseConsole()` 或 `ConsoleLog` |
| 远程聚合 | `NetworkLog` |
| 多目标 | `CompositeLog(fileLog, consoleLog)` |

### 二、业务类注入日志

```csharp
// 方式 1：构造注入（推荐，可测试）
public class MyService(ILog log)
{
    public void Process()
    {
        log.Info("开始处理");
        try { /* ... */ }
        catch (Exception ex) { log.Error("{0}", ex.Message); }
    }
}

// 方式 2：ILogFeature 接口属性（NewLife 组件常见模式）
public class MyComponent : ILogFeature
{
    public ILog Log { get; set; } = Logger.Null;  // 默认空日志，不写任何内容

    public void DoWork() => Log.Info("工作中...");
}
```

### 三、切换全局日志实现

```csharp
// 在 Main / Startup 中，尽早调用
XTrace.UseConsole();                      // 切换到彩色控制台
// 或
XTrace.Log = new CompositeLog(
    TextFileLog.Create("Logs"),
    new ConsoleLog());

XTrace.Debug = true;                      // 启用 Debug 级日志
```

### 四、链路追踪埋点

```csharp
// 1. 设置全局追踪器（一次性，应用启动时）
DefaultTracer.Instance = new DefaultTracer
{
    Period = 15,          // 采样周期（秒）
    MaxSamples = 1,       // 每周期正常样本数
    MaxErrors  = 10,      // 每周期异常样本数
    Timeout    = 3_000,   // 超时强制采样（毫秒）
};

// 2. 埋点（每个操作）
var tracer = DefaultTracer.Instance;
using var span = tracer.NewSpan("db/query", $"SELECT user:{id}");
try
{
    var result = await db.QueryAsync(id);
    return result;
}
catch (Exception ex)
{
    span?.SetError(ex, null);   // 标记异常
    throw;
}
// Span.Dispose() 自动上报
```

### 五、TraceId 跨层传递

```csharp
// 在当前 Span 活跃时，自动注入 HTTP 请求头 traceparent
var http = new HttpClient();
// DefaultTracer 自动为 HttpClient 注入 traceparent（若已配置）

// 在事件总线等非 HTTP 场景手动读取当前活跃 Span 的 TraceId
var traceId = DefaultSpan.Current?.TraceId;  // DefaultSpan.Current 是 AsyncLocal
```

### 六、日志级别与配置

```xml
<!-- NewLife.config -->
<Setting>
  <LogPath>Logs</LogPath>
  <LogLevel>Info</LogLevel>
  <LogFileFormat>{0:yyyy-MM-dd}.log</LogFileFormat>
</Setting>
```

日志级别顺序：`Off < Fatal < Error < Warn < Info < Debug < All`  
设置 `Level = Warn` 时，只有 `Warn`/`Error`/`Fatal` 会输出。

## 重点检查项

- [ ] 业务类是否通过 `ILog` / `ILogFeature` 接口记录日志，而非硬编码 `XTrace`？
- [ ] `ILog.Enable = false` 或 `Level = Off` 时，是否有代码仍在构建开销大的日志字符串（应先检查 `Enable`）？
- [ ] 追踪 `Span` 是否在所有代码路径（含异常）中都被 `Dispose`？推荐 `using`。
- [ ] 异常路径是否调用了 `span.SetError(ex, tag)` 标记失败？
- [ ] `DefaultTracer.Instance` 是否在应用启动时设置（晚于 DI 容器构建则组件追不到早期埋点）？
- [ ] `CompositeLog` 中若某个实现抛出异常，是否影响其他目标的写入（实现应独立 try-catch）？

## 输出要求

- **日志接口**：`ILog` + `LogLevel` 枚举；`ILogFeature` 属性注入接口。
- **实现文件**：`TextFileLog`（文件）、`ConsoleLog`（控制台）、`CompositeLog`（组合），各自独立文件。
- **追踪接口**：`ITracer` + `ISpanBuilder` + `ISpan`；`DefaultTracer` 作为默认实现。
- **配置**：在 `NewLife.config` / `appsettings.json` 中统一管理日志路径和级别，不硬编码。
- **测试**：可通过注入 `Logger.Null` 或 `TestLog`（记录日志到列表）测试各模块，不依赖文件 IO。

## 参考资料

参考示例与模式证据见 `references/newlife-log-tracer-patterns.md`。
