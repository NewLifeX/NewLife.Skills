---
name: system-introspection
description: >
  使用 NewLife.Core 的 MachineInfo（硬件 / 系统信息，CPU 占用 / 内存 / 网速）
  和 Runtime（平台判断 / 容器检测 / 高精度计时 / 内存释放）获取运行环境信息。
  适用于系统监控、环境自适应配置、可观测性心跳上报等场景。
argument-hint: >
  说明你的场景：获取机器唯一标识（UUID/Guid/Serial）；
  读取实时 CPU 负载 / 内存占用；判断运行平台（Windows/Linux/Container）；
  还是获取高精度系统运行时长（TickCount64）。
---

# 系统自省技能（MachineInfo + Runtime）

## 适用场景

- **`MachineInfo`**：心跳上报（CPU 占用率、可用内存、网速）；机器指纹绑定（UUID/Guid/Serial）；容量规划（总内存/磁盘）；跨平台硬件信息获取。
- **`Runtime`**：平台条件编译替代（`Runtime.Windows` / `Linux` / `OSX`）；容器/Docker 环境检测（`Runtime.Container`）；控制台/Web/GUI 场景判断；高精度系统运行时长（`TickCount64`，无32位溢出问题）；主动释放 GC 内存（`FreeMemory()`）。
- 代码审查：`MachineInfo.GetCurrent()` 会同步阻塞等待 `RegisterAsync()`，推荐在应用启动时 `await RegisterAsync()`；`Refresh()` 刷新动态指标，不会重新读取静态硬件信息。

## 核心原则

1. **`RegisterAsync()` 启动阶段调用一次**：异步读取全部硬件信息并缓存到 `machine_info.json`，服务重启后加速初始化；`GetCurrent()` 是同步阻塞包装，仅在无法使用 async 时用。
2. **静态属性 vs 动态属性**：硬件属性（`UUID`/`Memory`/`Processor`）在 `Init()/RegisterAsync()` 后固定；动态属性（`CpuRate`/`AvailableMemory`/`UplinkSpeed`）需调用 `Refresh()` 刷新。
3. **`MachineInfo.Current` 即单例**：`RegisterAsync()` 会注册到 `ObjectContainer`，可通过 `MachineInfo.Resolve()` 从 DI 获取。
4. **`TickCount64` 无溢出**：`Environment.TickCount`（32位）约49.7天溢出；`Runtime.TickCount64`（`Int64`）无此问题，所有计时逻辑用 `TickCount64`。
5. **`Runtime.Container`**：通过环境变量 `DOTNET_RUNNING_IN_CONTAINER` 判断，标准 Docker 镜像自动设置此变量。

## 执行步骤

### 一、应用启动时初始化机器信息

```csharp
using NewLife;
using NewLife.Log;

// 应用启动（最早，如 Main 或 ConfigureServices）
var machine = await MachineInfo.RegisterAsync();

XTrace.WriteLine("OS:       {0} {1}", machine.OSName,  machine.OSVersion);
XTrace.WriteLine("CPU:      {0}", machine.Processor);
XTrace.WriteLine("内存:     {0:N0} MB", machine.Memory / 1024 / 1024);
XTrace.WriteLine("UUID:     {0}", machine.UUID);
XTrace.WriteLine("机器GUID: {0}", machine.Guid);
XTrace.WriteLine("序列号:   {0}", machine.Serial);
```

### 二、实时监控 CPU / 内存 / 网速

```csharp
var machine = MachineInfo.Current!;

// 刷新动态指标（CPU / 内存 / 网速 / 温度 / 电量）
machine.Refresh();

XTrace.WriteLine("CPU 占用: {0:P1}", machine.CpuRate);
XTrace.WriteLine("可用内存: {0:N0} MB", machine.AvailableMemory / 1024 / 1024);
XTrace.WriteLine("空闲内存: {0:N0} MB", machine.FreeMemory        / 1024 / 1024);
XTrace.WriteLine("上行速度: {0:N0} KB/s", machine.UplinkSpeed   / 1024);
XTrace.WriteLine("下行速度: {0:N0} KB/s", machine.DownlinkSpeed / 1024);
XTrace.WriteLine("温度:     {0:F1}°C",  machine.Temperature);
XTrace.WriteLine("电量:     {0:P0}",    machine.Battery);
```

定期刷新（结合定时器）：

```csharp
var timer = new TimerX(_ => MachineInfo.Current?.Refresh(), null, 0, 5_000);
```

### 三、机器唯一标识（硬件指纹）

```csharp
var machine = MachineInfo.GetCurrent();

// UUID：主板/BIOS 唯一标识（最稳定，推荐）
var deviceId = machine.UUID;

// Guid：系统分配的逻辑 ID（OS 安装时生成）
var sysGuid = machine.Guid;

// Serial：整机序列号
var serial = machine.Serial;

// DiskID：主硬盘序列号
var diskId = machine.DiskID;

// 组合指纹（更稳健）
var fingerprint = $"{machine.UUID}|{machine.DiskID}".ToMD5();
```

### 四、Runtime — 平台与环境判断

```csharp
using NewLife;

// 平台判断
if (Runtime.Windows)       XTrace.WriteLine("Windows 平台");
else if (Runtime.Linux)    XTrace.WriteLine("Linux 平台");
else if (Runtime.OSX)      XTrace.WriteLine("macOS 平台");

// 运行时类型
if (Runtime.Mono)          XTrace.WriteLine("Mono 运行时");
if (Runtime.Unity)         XTrace.WriteLine("Unity 运行时");

// 宿主类型
if (Runtime.Container)     XTrace.WriteLine("Docker / Kubernetes 容器");
if (Runtime.IsConsole)     XTrace.WriteLine("控制台程序");
else if (Runtime.IsWeb)    XTrace.WriteLine("Web 应用");

// 容器环境自适应配置
var logPath = Runtime.Container ? "/app/logs" : @".\Logs";
```

### 五、高精度计时（TickCount64）

```csharp
// 无32位溢出的系统运行时长（毫秒）
var startMs  = Runtime.TickCount64;
DoSomeWork();
var elapsed  = Runtime.TickCount64 - startMs;
XTrace.WriteLine("耗时: {0} ms", elapsed);

// 系统已运行时长
var uptimeSec = Runtime.TickCount64 / 1000;
XTrace.WriteLine("系统运行: {0} 天 {1:D2} 时 {2:D2} 分",
    uptimeSec / 86400, uptimeSec % 86400 / 3600, uptimeSec % 3600 / 60);
```

### 六、内存释放

```csharp
// 主动触发 GC 并缩减 WorkingSet（降低内存占用）
Runtime.FreeMemory();

// 指定进程 ID（如需对外部进程操作，通常不用）
Runtime.FreeMemory(processId: 0, gc: true, workingSet: true);
```

### 七、其他 Runtime 工具

```csharp
// 当前进程 ID
int pid = Runtime.ProcessId;

// 客户端唯一标识（基于机器+进程）
string clientId = Runtime.ClientId;

// 读取环境变量（跨平台兼容，包括系统/用户/进程级别）
string? dbHost = Runtime.GetEnvironmentVariable("DB_HOST");
var allVars    = Runtime.GetEnvironmentVariables();

// 高精度 UTC 时间（通过 TimerScheduler 提供，可测试替换）
DateTimeOffset now = Runtime.UtcNow;
```

## 重点检查项

- [ ] `MachineInfo.RegisterAsync()` 是否在应用启动时调用（而不是每次使用时调用）？
- [ ] 读取监控数据之前是否调用了 `Refresh()`（静态硬件属性不需要刷新，动态指标需要）？
- [ ] 使用计时逻辑时是否改用 `Runtime.TickCount64` 而非 `Environment.TickCount`（后者32位约49天溢出）？
- [ ] 机器唯一标识是否优先选 `UUID`（最稳定），并做空值保护（虚拟机/容器环境可能返回 `null`）？
- [ ] 容器判断是否用 `Runtime.Container`（读取 `DOTNET_RUNNING_IN_CONTAINER` 环境变量），而非自行判断路径？

## 输出要求

- **机器信息**：`MachineInfo`（`NewLife`）—— `RegisterAsync()`/`GetCurrent()`/`Refresh()`；静态属性（UUID/Memory/Processor）+ 动态属性（CpuRate/AvailableMemory/UplinkSpeed）。
- **运行时工具**：`Runtime`（`NewLife`，静态类）—— `Windows`/`Linux`/`OSX`/`Container`/`IsConsole`/`IsWeb`；`TickCount64`；`FreeMemory()`；`ProcessId`/`ClientId`。

## 参考资料

- `NewLife.Core/Common/MachineInfo.cs`
- `NewLife.Core/Common/Runtime.cs`
- 相关技能：`logging-tracing-system`（APM 心跳上报结合 MachineInfo）、`timer-scheduler`（定期 Refresh 监控指标）
