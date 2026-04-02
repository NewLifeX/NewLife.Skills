# NewLife.Core Host 模式证据

> 来源：`Doc/轻量级应用主机Host.md`（部分编码损坏）+ `Model/Host.cs` + `Model/IObjectContainer.cs`
> 文档中文编码损坏段落以源码及类型注释为准。

---

## 1. 接口与类层次（源码校验）

```text
IHostedService
├── StartAsync(CancellationToken)
└── StopAsync(CancellationToken)

IHost
├── Services (IServiceProvider)
├── Add(IHostedService) / Add<TService>()
├── StartAsync / StopAsync
├── Run / RunAsync
└── Close(reason)

Host : DisposeBase, IHost
├── Services       (构造注入 IServiceProvider)
├── HostedServices (IList<IHostedService> — 已注册服务列表)
├── MaxTime        (Int32，默认 -1 永久阻塞)
└── 信号处理        (Ctrl+C / SIGINT / SIGTERM → 调用所有 StopAsync)
```

---

## 2. `AddHostedService` 扩展（源码）

```csharp
// 等价于 ioc.AddSingleton<IHostedService, THostedService>()
public static IObjectContainer AddHostedService<THostedService>(
    this IObjectContainer services) where THostedService : class, IHostedService
{
    services.AddSingleton<IHostedService, THostedService>();
    return services;
}

// 工厂重载，支持依赖注入传参
public static IObjectContainer AddHostedService<THostedService>(
    this IObjectContainer services,
    Func<IServiceProvider, THostedService> implementationFactory) where THostedService : class, IHostedService
{
    services.AddSingleton<IHostedService>(implementationFactory);
    return services;
}
```

**重点**：`IHostedService` 是以 `Singleton` 注册的，容器只创建一个实例；多次注册同一类型会叠加（同 `.NET` 泛型宿主行为）。

---

## 3. 主机启停顺序（文档观察 + 源码推断）

```
Host.Run / RunAsync
│
├─ foreach services → service.StartAsync(ct)    ← 顺序启动
├─ 阻塞等待: MaxTime (-1 = 永久) 或收到 SIGTERM/Ctrl+C
├─ foreach services (逆序) → service.StopAsync(ct)  ← 逆序停止
└─ Dispose
```

- 文档说明：MaxTime > 0 时精确到毫秒；文档示例中使用 60_000 表示 1 分钟。
- 逆序停止来源：文档原则"最后启动的先停止"（依赖链安全）。

---

## 4. `IHostedService` 实现要点（源码注释）

```csharp
// StartAsync：立即返回，在后台 Task 运行；不在此处 await 长任务
public Task StartAsync(CancellationToken cancellationToken)
{
    _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
    _task = RunAsync(_cts.Token);
    return Task.CompletedTask;
}

// StopAsync：取消 CTS，等待 Task 或超时
public async Task StopAsync(CancellationToken cancellationToken)
{
    _cts?.Cancel();
    if (_task != null)
        await Task.WhenAny(_task, Task.Delay(5_000, cancellationToken));
}
```

---

## 5. `Host.RegisterExit` 静态方法

```csharp
// 注册进程退出回调（可多次调用，每次追加）
Host.RegisterExit(() => { /* 清理资源 */ });

// 接收 sender/EventArgs 版本
Host.RegisterExit((sender, e) => { /* ... */ });
```

内部统一接管 `AppDomain.ProcessExit` 和 `Console.CancelKeyPress`，防止各处重复注册冲突。

---

## 6. 与 `Microsoft.Extensions.Hosting` 兼容性

- `IHostedService` 接口签名在语义上完全一致（`StartAsync`/`StopAsync`），.NET 5+ 下可互相兼容。
- `ObjectContainer` 实现了 `IServiceProvider`，可作为宿主的 `Services` 传入。
- 不需要 `Microsoft.Extensions.Hosting` 包依赖，适合体积敏感或 AOT 场景。

---

## 7. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| `IHostedService` Start/Stop | ✅ 通用 | `.NET` 泛型宿主同接口 |
| `StartAsync` 立即返回 | ✅ 通用 | 与 `BackgroundService` 基类一致 |
| `CancellationToken` 协作退出 | ✅ 通用 | 标准取消模式 |
| `RegisterExit` 统一信号处理 | ⚠️ NewLife 特有 | 通用替代：`IHostApplicationLifetime` |
| `ObjectContainer.AddHostedService` | ⚠️ NewLife 特有 | 通用替代：`IServiceCollection.AddHostedService` |
| `MaxTime` 属性限时退出 | ⚠️ NewLife 特有 | 通用替代：`CancellationTokenSource(TimeSpan)` |
