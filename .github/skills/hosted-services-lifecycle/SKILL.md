---
name: hosted-services-lifecycle
description: >
  设计轻量级应用主机，管理后台服务（IHostedService）的启动、停止顺序与生命周期。
  涵盖宿主信号处理（Ctrl+C/SIGTERM）、优雅停机、依赖注入集成，以及最大执行时间限制。
  适用于控制台应用、后台服务、微服务、守护进程等场景的主机设计与代码审查。
argument-hint: >
  说明你的宿主场景：常驻进程还是限时任务；是否需要多服务并行；
  如何做依赖注入（ObjectContainer 还是 MS DI）；是否需要定时停止或优雅停机钩子。
---

# 应用主机生命周期管理技能

## 适用场景

- 控制台应用需要同时运行多个后台服务（消息消费、定时任务、健康检查等），并在收到 Ctrl+C 或系统信号时优雅停机。
- 微服务/守护进程需要统一管理各组件的启动/停止顺序，确保依赖关系和资源释放正确。
- 需要在依赖注入容器初始化完成后，统一拉起全部已注册的后台服务。
- 定时测试或 CI 场景需要运行一段时间后自动退出（`MaxTime` 限制）。

## 核心原则

1. **`IHostedService` 契约**：每个后台服务独立实现 `StartAsync(CancellationToken)` 和 `StopAsync(CancellationToken)`；启动时不阻塞（耗时任务在后台 `Task` 中运行）；停止时等待当前工作单元完成，但要遵守 `CancellationToken`。
2. **单向生命周期**：`Host` 顺序启动所有服务，逆序停止；不要直接持有 `Host` 引用在服务内部调用 `Close`，应通过 `CancellationToken` 协作退出。
3. **依赖注入优先**：通过 `IObjectContainer.AddHostedService<T>()` 注册服务，让容器负责实例化和依赖解析；避免在 `Add<TService>()` 之前手工 `new`。
4. **优雅停机时限**：`StopAsync` 应设置合理超时（比如 5 秒）；超时后强制退出，防止应用卡死；`MaxTime` 用于测试或限时任务，生产环境通常保持 `-1`。
5. **信号处理统一**：通过 `Host.RegisterExit` 注册清理回调，而非散落在各处监听 `AppDomain.ProcessExit` / `Console.CancelKeyPress`。

## 执行步骤

### 一、定义后台服务

```csharp
public class WorkerService : IHostedService
{
    private CancellationTokenSource? _cts;
    private Task? _task;

    public Task StartAsync(CancellationToken cancellationToken)
    {
        _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _task = RunAsync(_cts.Token);
        return Task.CompletedTask;  // StartAsync 立即返回，不阻塞
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        _cts?.Cancel();
        if (_task != null)
            await Task.WhenAny(_task, Task.Delay(5_000, cancellationToken));
    }

    private async Task RunAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            // 执行业务逻辑
            await Task.Delay(1_000, stoppingToken);
        }
    }
}
```

### 二、注册服务并启动主机

```csharp
// 推荐方式：通过 IoC 注册
var ioc = ObjectContainer.Current;
ioc.AddSingleton<IMessageQueue, RedisQueue>();
ioc.AddHostedService<WorkerService>();
ioc.AddHostedService<HealthCheckService>();

var host = new Host(ioc.BuildServiceProvider());
host.Run();  // 阻塞，直到 Ctrl+C / SIGTERM / Close()
```

- `AddHostedService<T>()` 等价于 `ioc.AddSingleton<IHostedService, T>()`，服务实例由容器管理。
- 若需手动传入已构建的实例：`host.Add(myServiceInstance)`。

### 三、信号与退出钩子

```csharp
// 注册清理回调（持久注册，可多次调用；生命周期与进程一致）
Host.RegisterExit(() =>
{
    flushLogs();
    releaseConnections();
});
```

- `RegisterExit` 内部使用 `AppDomain.ProcessExit` + `Console.CancelKeyPress`，无需重复注册。

### 四、限时运行（测试/CI）

```csharp
var host = new Host(ioc.BuildServiceProvider());
host.MaxTime = 30_000;   // 30 秒后自动停止
await host.RunAsync();
```

### 五、手动控制启停（集成测试）

```csharp
using var cts = new CancellationTokenSource();

await host.StartAsync(cts.Token);

// 做断言...
await Task.Delay(500);

await host.StopAsync(cts.Token);
```

### 六、与 `Microsoft.Extensions.Hosting` 的对比定位

| 特性 | `NewLife.Model.Host` | `Microsoft.Extensions.Hosting` |
|------|---------------------|-------------------------------|
| 接口 | `IHostedService`（相同语义）| `IHostedService` |
| 容器 | `ObjectContainer`（`IObjectContainer`）| `IServiceCollection` |
| 信号处理 | `Host.RegisterExit` | 内置 |
| 依赖 | 仅 `NewLife.Core` | 需 `Microsoft.Extensions.Hosting` |

> 两套 `IHostedService` 接口签名相同，在 .NET 5+ 下可互相兼容；容器层不互通。

## 重点检查项

- [ ] `StartAsync` 是否立即返回？长任务是否在后台 `Task` 中运行，而非在 `StartAsync` 内 `await` 阻塞？
- [ ] `StopAsync` 是否有合理超时？是否在 `CancellationToken` 被触发后尽快退出？
- [ ] 服务内是否持有 `Host` 引用并直接调用 `Close`（应改为通过 `CancellationToken` 协作）？
- [ ] 是否散落多处 `Console.CancelKeyPress` / `AppDomain.ProcessExit`（应改用 `RegisterExit`）？
- [ ] 服务的构造函数是否注入了过多依赖，或依赖了"还没启动的服务"？
- [ ] 多服务之间的启停顺序是否有依赖？如有，应通过启动顺序排列或协调令牌解决。

## 输出要求

- **服务类**：实现 `IHostedService`；`StartAsync` 立即返回并启动后台 `Task`；`StopAsync` 取消并等待。
- **入口**：`Main` 或 `Program.cs` 中用 `AddHostedService<T>()` 注册所有服务，构建 `Host` 并调用 `Run()`。
- **清理**：通过 `Host.RegisterExit` 统一注册清理钩子，不散落各处。
- **测试**：能通过 `StartAsync` + 等待 + `StopAsync` 独立测试每个服务，无须启动完整主机。

## 参考资料

参考示例与模式证据见 `references/newlife-host-patterns.md`。
