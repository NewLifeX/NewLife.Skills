---
name: agent-service
description: >
  使用 NewLife.Agent 将 .NET 应用注册为跨平台系统服务（Windows Service、Linux systemd、macOS LaunchAgent），
  涵盖 ServiceBase 生命周期钩子（StartWork/StopWork/DoLoop）、IHost 平台实现、
  命令行管理（-install/-start/-stop/-uninstall）、自定义命令处理器、
  看门狗/内存监控/自动重启，以及 ASP.NET Core UseAgentService 集成。
  适用于后台服务、数据采集守护进程、定时任务服务的系统级部署。
argument-hint: >
  说明你的服务场景：新建独立后台服务还是将 ASP.NET Core 应用注册为系统服务；
  目标平台（Windows/Linux/macOS）；是否需要自定义命令；
  是否需要看门狗保护其他进程；是否需要内存/线程超限自动重启。
---

# 跨平台系统服务技能（NewLife.Agent）

## 适用场景

- 将控制台应用一行代码注册为 Windows Service 或 Linux systemd 服务，实现开机自启。
- 数据采集、定时任务、消息消费等长期运行后台服务的系统级部署与管理。
- 需要在服务内同时启动多个子任务（`TimerX`/`NetServer` 等），统一生命周期管理。
- 生产环境需要进程自我保护：内存超限自动重启、崩溃自动恢复、看门狗保护其他服务。
- ASP.NET Core 应用需要以系统服务方式运行（替代 `UseWindowsService`/`UseSystemd`）。

## 核心原则

1. **继承 `ServiceBase`，覆写 `StartWork`/`StopWork`**：这是唯一的业务接入点；`Starting` 阶段初始化资源、启动后台任务；`Stopping` 阶段释放资源、等待任务完成；两个方法都**必须调用 `base.xxx(reason)`**，否则框架状态标志不正确。
2. **`Main(args)` 是统一入口**：一行代码 `new MyService().Main(args)` 处理全部逻辑——命令行参数解析（`-install`/`-run` 等）、系统服务注册、交互式菜单；无需多个 `Main` 函数。
3. **`-run` 参数用于控制台调试**：开发阶段用 `dotnet run -- -run` 在控制台中模拟服务运行（前台执行），无需安装；CI/CD 中通过 `-install` 注册到系统。
4. **平台由框架自动选择**：无需编写平台判断代码；`IHost` 的实现（`WindowsService`/`Systemd`/`OSXLaunch`/`DefaultHost`）由运行时环境自动决定，同一份代码跨平台运行。
5. **看门狗和内存监控通过 `Setting` 配置**：在 `Agent.config` 或代码中设置 `WatchDog`/`MaxMemory`/`AutoRestart` 属性，不需要修改 `DoLoop` 逻辑；框架在 `DoLoop` 内自动检查并执行动作。
6. **自定义命令继承 `BaseCommandHandler`**：在 `Process(args)` 中实现命令逻辑，设置 `Cmd`、`ShortcutKey`、`Description`，框架自动发现并挂入命令行和交互菜单。

## 执行步骤

### 一、创建最简系统服务

```csharp
using NewLife.Agent;

// 1. 定义服务类
public class MyService : ServiceBase
{
    public MyService()
    {
        ServiceName = "MyAwesomeService";
        DisplayName = "我的后台服务";
        Description = "数据采集与同步服务";
    }

    // 服务启动时调用（初始化资源、启动后台任务）
    protected override void StartWork(String reason)
    {
        base.StartWork(reason);  // 必须调用

        // 启动定时采集任务
        _timer = new TimerX(CollectDataAsync, null, 1_000, 30_000);
        WriteLog("服务启动，原因：{0}", reason);
    }

    // 服务停止时调用（释放资源）
    protected override void StopWork(String reason)
    {
        _timer?.Dispose();
        WriteLog("服务停止，原因：{0}", reason);

        base.StopWork(reason);  // 必须调用
    }

    private TimerX _timer;
    
    private async Task CollectDataAsync(Object? state)
    {
        // 采集逻辑...
        await Task.Delay(100);
    }
}

// 2. Program.cs 入口（一行代码）
static void Main(String[] args) => new MyService().Main(args);
```

### 二、命令行管理

```bash
# 安装并自动启动系统服务
dotnet MyService.dll -install

# 仅安装，不启动
dotnet MyService.dll -install -ns

# 卸载服务
dotnet MyService.dll -uninstall
# 或短命令
dotnet MyService.dll -u

# 启动 / 停止 / 重启已安装的服务
dotnet MyService.dll -start
dotnet MyService.dll -stop
dotnet MyService.dll -restart

# 查询服务状态
dotnet MyService.dll -status

# 控制台前台运行（开发调试）
dotnet MyService.dll -run
```

### 三、配置看门狗和资源限制

```csharp
// 方式 1：在构造函数中设置（代码级配置，高优先级）
public MyService()
{
    ServiceName = "MyService";
    
    // 内存超过 512MB 自动重启
    // (通过 Setting 配置，见方式 2)
}

// 方式 2：通过 Agent.config 配置（推荐生产环境）
// Agent.config 位于应用目录，首次运行自动生成
// 也可在 Setting.Current 中修改
var setting = Setting.Current;
setting.MaxMemory       = 512;   // 最大内存（MB），超过自动重启
setting.MaxThread       = 1000;  // 最大线程数，超过告警
setting.MaxHandle       = 5000;  // 最大句柄数，超过告警
setting.AutoRestart     = 360;   // 运行满 N 分钟自动重启（0=禁用）
setting.WatchDog        = "OtherService";  // 监视其他服务名，停止则启动
setting.Save();
```

### 四、自定义命令与菜单

```csharp
// 添加自定义命令（例如：手动触发数据同步）
public class SyncCommandHandler : BaseCommandHandler
{
    private readonly MyService _service;

    public SyncCommandHandler(ServiceBase service) : base(service)
    {
        Cmd         = "-sync";          // 命令行参数
        Description = "立即执行数据同步";
        ShortcutKey = 'S';              // 交互菜单快捷键（大小写不敏感）
    }

    public override void Process(String[] args)
    {
        XTrace.WriteLine("开始手动同步...");
        // 执行同步逻辑
        (_service as MyService)?.SyncNow();
    }

    // 是否在交互菜单中显示
    public override Boolean IsShowMenu() => true;
}

// 在服务中注册（框架通过反射自动发现同 Assembly 内的 BaseCommandHandler）
// 无需手动注册，只要类在同一程序集中即自动生效
```

### 五、ASP.NET Core 集成

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// 替代 builder.Host.UseWindowsService() 或 UseSystemd()
builder.Host.UseAgentService(options =>
{
    options.ServiceName = "MyWebService";
    options.DisplayName = "我的 Web 服务";
    options.Description = "ASP.NET Core 应用系统服务";
});

builder.Services.AddControllers();
var app = builder.Build();
app.MapControllers();
app.Run();
```

### 六、Linux（systemd）服务文件

```bash
# 安装后，框架自动在 /etc/systemd/system/ 生成 .service 文件
# 内容大致如下（框架自动生成，无需手动编写）：
# [Unit]
# Description=我的后台服务
# After=network.target
#
# [Service]
# Type=simple
# ExecStart=/usr/bin/dotnet /opt/myservice/MyService.dll -run
# Restart=on-failure
# RestartSec=5
#
# [Install]
# WantedBy=multi-user.target

# 安装命令
sudo dotnet MyService.dll -install

# 验证
sudo systemctl status MyService
sudo journalctl -u MyService -f
```

## ServiceBase 生命周期钩子速查

| 方法 | 调用时机 | 常见用途 |
|------|---------|---------|
| `StartWork(reason)` | 服务启动后（平台服务线程中） | 初始化资源，启动 TimerX/NetServer 等 |
| `DoLoop()` | 服务运行期间（阻塞循环中） | 一般不需重写；框架在此做资源监控、WatchDog |
| `StopWork(reason)` | 服务停止前 | 取消任务，释放资源（Dispose），等待 I/O 完成 |

## 命令行参数速查

| 参数 | 功能 |
|------|------|
| `-install` | 安装并启动系统服务 |
| `-uninstall` / `-u` | 卸载系统服务 |
| `-start` | 启动已安装服务 |
| `-stop` | 停止已安装服务 |
| `-restart` | 重启已安装服务 |
| `-status` | 查询服务状态 |
| `-run` | 前台控制台运行（调试） |
| `-watch` | 看门狗模式（监视并守护目标服务） |

## 常见错误与注意事项

- **`StartWork`/`StopWork` 忘记调用 `base.xxx(reason)`**：基类维护 `Running` 标志和日志，遗漏调用会导致状态不一致，`DoLoop` 可能不退出。
- **在 `StartWork` 中做长时间 I/O（如等待数据库连接）**：SCM（Windows 服务控制器）对启动时间有限制（默认 30 秒），超时会被强制终止；应在 `StartWork` 中仅启动后台任务，不等待完成。
- **`StopWork` 中释放资源后还持有引用**：`Dispose` 后将字段置 `null`，避免定时器回调在停止后仍然执行导致 `ObjectDisposedException`。
- **Linux 下用 `UseAutorun=true` 与 systemd 冲突**：`UseAutorun` 是 Windows 注册表自启方式；Linux 上应由 systemd 管理重启策略，不要混用。
- **多实例部署需不同 `ServiceName`**：同一程序部署多份时，每份实例的 `ServiceName` 必须唯一，否则系统服务注册冲突。
