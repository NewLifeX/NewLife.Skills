# NewLife.Core 日志与追踪模式证据

> 来源：`Log/ILog.cs` + `Log/ITracer.cs` + `Log/XTrace.cs`
> 日志文档（`Doc/日志ILog.md`）存在编码损坏，以源码为准。

---

## 1. 接口层次（源码校验）

```text
ILog
├── Write(LogLevel, format, args)
├── Debug / Info / Warn / Error / Fatal
├── Enable (Boolean)
└── Level  (LogLevel)

ITracer
├── Period / MaxSamples / MaxErrors / Timeout / MaxTagLength
├── AttachParameter   W3C traceparent 注入参数名
├── Resolver          ITracerResolver 扩展点
├── BuildSpan(name)   → ISpanBuilder
├── NewSpan(name)     → ISpan（using 块使用）
├── NewSpan(name, tag)
└── TakeAll()         重置并返回所有 SpanBuilder

ISpan : IDisposable
├── TraceId / ParentId
├── SetError(Exception, tag)
└── Dispose() → 上报当前 Span
```

---

## 2. `XTrace` 静态门面关键点（源码）

```csharp
// 全局 ILog 实例，默认 TextFileLog（延迟初始化）
public static ILog Log { get { InitLog(); return _Log; } set { _Log = value; } }

// 快捷写日志 → 委托给 Log.Info
public static void WriteLine(String msg)
public static void WriteLine(String format, params Object?[] args)

// 异常写入
public static void WriteException(Exception ex)

// 切换控制台输出（快捷方法）
public static void UseConsole(Boolean useColor = true)

// 调试模式开关 → Debug 级日志
public static Boolean Debug { get; set; }

// 日志文件路径
public static String LogPath { get; set; }
```

---

## 3. `DefaultTracer` 关键实现（源码）

```csharp
// 全局单例（影响所有 NewLife 组件追踪行为）
public static ITracer? Instance { get; set; }

// 静态构造注册默认类型到 IoC
static DefaultTracer()
{
    var ioc = ObjectContainer.Current;
    ioc.TryAddTransient<ITracer, DefaultTracer>();
    ioc.TryAddTransient<ISpanBuilder, DefaultSpanBuilder>();
    ioc.TryAddTransient<ISpan, DefaultSpan>();
}

// 采样参数默认值
Period     = 15;   // 秒
MaxSamples = 1;    // 每周期正常样本
MaxErrors  = 10;   // 每周期异常样本
```

---

## 4. `ILogFeature` 属性注入模式（NewLife 组件惯例）

```csharp
// 实现此接口的组件通过属性注入日志，而非构造注入
public interface ILogFeature
{
    ILog Log { get; set; }
}

// 使用方式
public class NetServer : ILogFeature
{
    public ILog Log { get; set; } = Logger.Null;  // 默认空日志
}

// 调用方替换
var server = new NetServer();
server.Log = XTrace.Log;  // 或注入 TextFileLog 实例
```

> **项目特例**：`ILogFeature` 是 NewLife 专有模式；通用替代是构造函数注入 `ILog` 或使用 `ILogger<T>` (Microsoft 扩展)。

---

## 5. 日志级别枚举（源码，完整）

```csharp
public enum LogLevel
{
    Off   = 0,   // 关闭
    Fatal = 1,   // 致命
    Error = 2,   // 错误
    Warn  = 3,   // 警告
    Info  = 4,   // 信息（默认输出级别）
    Debug = 5,   // 调试
    All   = 6    // 全量
}
```

---

## 6. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| `ILog` 分级写入接口 | ✅ 通用 | 与 `Microsoft.Extensions.Logging.ILogger` 等价 |
| 静态门面 (`XTrace`) | ⚠️ 半通用 | 思路通用；具体类 NewLife 特有 |
| `ILogFeature` 属性注入 | ⚠️ NewLife 特有 | 通用替代：构造注入 `ILog` |
| `ITracer/ISpan` 轻量 APM | ✅ 通用 | 与 `OpenTelemetry` / `Activity` 思路相同 |
| `DefaultTracer.Instance` 全局替换 | ✅ 通用 | 单例模式，可替换 |
| W3C `traceparent` 自动注入 | ✅ 通用 | 标准 HTTP 追踪头 |
