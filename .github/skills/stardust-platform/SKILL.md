---
name: stardust-platform
description: >
  使用 NewLife.Stardust 接入星尘分布式服务平台，涵盖 StarFactory 统一接入入口、
  服务注册与发现（IRegistry）、配置中心（star.Config → IConfigProvider）、
  APM 性能追踪（StarTracer + 全链路诊断监听器）、应用心跳监控，
  以及 IoC 集成（AddStardust/UseStardust）和 StarAgent 守护进程接入。
  适用于微服务注册发现、集中配置管理、分布式链路追踪、应用运维监控等场景。
argument-hint: >
  说明你的星尘使用场景：服务注册发现、配置中心、性能监控（APM）、
  还是以上全部；是否集成在 ASP.NET Core 中；
  是否需要通过 StarAgent 接入本地代理；
  配置中心是否需要热更新。
---

# 星尘分布式服务平台技能（NewLife.Stardust）

## 适用场景

- 微服务架构中通过星尘注册中心实现服务注册、发现与负载均衡。
- 集中管理多套环境（开发/测试/生产）配置，支持动态热更新无需重启。
- 服务间调用链路追踪（APM），自动采集 HTTP/SQL/EF Core/gRPC/MQ 调用链。
- 应用心跳监控：CPU 占用、内存、线程、GC 等指标定期上报到星尘平台。
- ASP.NET Core 应用快速接入（`AddStardust`），不改业务代码实现全链路可观测性。
- StarAgent 守护进程接管应用部署、进程监控、远程发布。

## 核心原则

1. **`StarFactory` 是唯一的接入入口**：通过 `new StarFactory(server, appId, secret)` 或 `AddStardust()` 获取；不要直接 `new StarClient()`/`new AppClient()`，内部初始化顺序有依赖。
2. **配置加载优先级（高→低）**：构造参数 > `appsettings.json` 的 `Star` 节 > 本机 StarAgent（UDP 5500）> `star.config` 文件；生产环境推荐用 `appsettings.json`，本地开发通过 StarAgent 自动获取服务端地址。
3. **`star.Config` 返回 `IConfigProvider`，与本地配置统一接口**：配置中心的 key 通过 `star.Config["Key"]` 读取；可与 `appsettings.json` 组合使用（同一接口，星尘配置优先级可调整）。
4. **APM 追踪调用 `DiagnosticListenerObserver.Install()` 一次即可**：安装后自动监听 ASP.NET Core/HttpClient/EF Core/SQL/gRPC 等，无需在每个调用点手动埋点；仅需在关键业务操作处用 `tracer.NewSpan()` 补充自定义 span。
5. **服务发现消费返回地址列表，调用方负责负载均衡**：`registry.Consume("UserService")` 返回该服务全部可用实例地址；结合 `NewLife.Http.HttpClient` 或手动轮询实现客户端负载均衡。
6. **StarAgent 是 NewLife.Agent 的增强版本**：`StarAgent` 基于 `ServiceBase` 构建，额外提供进程守护、远程发布、节点监控采集；部署 StarAgent 后，本地应用可通过 UDP 5500 自动获取星尘服务端地址（无需硬编码）。

## 执行步骤

### 一、控制台/Worker 应用接入

```csharp
using NewLife.Stardust;

// 方式 1：显式参数（指定星尘服务端）
var star = new StarFactory("http://stardust.example.com:6600", "MyApp", "secret");

// 方式 2：自动发现（本机有 StarAgent 时自动获取地址）
var star = new StarFactory();   // 从环境自动读取服务端地址

// 获取各功能入口
var registry = star.Registry;   // 服务注册发现
var config   = star.Config;     // 配置中心
var tracer   = star.Tracer;     // APM 性能追踪

// 使用配置中心读取配置
var dbConn = config["ConnectionStrings:Default"];

// 发布自身服务（注册到注册中心）
registry.Register("OrderService", "http://192.168.1.10:5001");

// 应用退出时取消注册（建议放在 IDisposable 中）
registry.Unregister("OrderService");
```

### 二、ASP.NET Core 集成（推荐）

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

// 一行代码接入星尘（注册发现 + 配置中心 + APM）
var star = builder.AddStardust("OrderService");

// 自动完成：
// 1. 将本服务注册到星尘注册中心
// 2. 接入配置中心（star.Config 合并到 IConfiguration）
// 3. 安装 APM 诊断监听器（自动追踪 HTTP/SQL/EF）
// 4. 定期心跳上报 CPU/内存等运行指标

builder.Services.AddControllers();
var app = builder.Build();
app.MapControllers();
app.Run();
```

### 三、appsettings.json 配置

```json
{
  "Star": {
    "Server"        : "http://stardust.example.com:6600",
    "AppKey"        : "OrderService",
    "Secret"        : "your-secret",
    "TracerPeriod"  : 60,
    "MaxSamples"    : 1,
    "MaxErrors"     : 10,
    "Debug"         : false
  }
}
```

### 四、服务注册与发现

```csharp
// 发布（注册自身）
var registry = star.Registry;
registry.Register("OrderService", "http://192.168.1.10:5001");

// 消费（发现其他服务）
var addresses = await registry.ConsumeAsync("UserService");
// addresses: ["http://192.168.1.20:5002", "http://192.168.1.21:5002"]

// 客户端负载均衡（简单轮询）
var idx  = Interlocked.Increment(ref _roundRobinIndex);
var addr = addresses[idx % addresses.Length];

// 使用 NewLife.Http 配合多地址自动故障切换
var client = new HttpClient { BaseAddress = new Uri(addr) };
var result = await client.GetStringAsync("/api/users/1");
```

### 五、配置中心使用

```csharp
// 读取配置（与 IConfiguration 接口一致）
var config = star.Config;
var dbConn  = config["DbConn"];
var timeout = config["Timeout"].ToInt(30);

// 订阅配置变更（热更新）
config.OnChanged += (k, v) =>
{
    XTrace.WriteLine($"配置已更新: {k} = {v}");
    // 重新应用配置
};

// 在 DI 中使用（IConfiguration 方式）
builder.Configuration.AddStardust(star);

// 然后通过标准 IConfiguration 读取
var connStr = configuration.GetConnectionString("Default");
```

### 六、APM 性能追踪

```csharp
// 方式 1：自动安装（推荐，覆盖全部框架埋点）
// 在 AddStardust 时自动调用，无需手动
DiagnosticListenerObserver.Install();

// 方式 2：手动自定义 Span（业务关键路径补充）
var tracer = star.Tracer;
using var span = tracer.NewSpan("ProcessOrder");
span.Tag = orderId.ToString();
try
{
    // 业务逻辑
    ProcessOrderInternal(orderId);
}
catch (Exception ex)
{
    span.SetError(ex, null);  // 标记错误并记录异常
    throw;
}

// 自动追踪的框架（安装 DiagnosticListenerObserver 后）：
// - ASP.NET Core 请求（入站 HTTP）
// - HttpClient（出站 HTTP）
// - EF Core / ADO.NET SQL 查询
// - gRPC 调用
// - MongoDB 操作
// - DNS 查询 / TCP 连接
```

### 七、通过 StarAgent 接入（推荐生产部署）

```bash
# 1. 机器上部署 StarAgent（一次性）
dotnet StarAgent.dll -install
# StarAgent 监听 UDP 5500，应用自动发现星尘服务端地址

# 2. 应用代码中直接用自动发现模式
# var star = new StarFactory();  // 自动从本机 StarAgent 获取服务端地址
# 无需在代码或配置文件中硬编码星尘服务端地址
```

### 八、StarAgent 作为应用守护进程

```csharp
// StarAgent 基于 NewLife.Agent 的 ServiceBase 构建
// 应用只需要以 NewLife.Agent 方式打包，StarAgent 接管进程生命周期：
// - 进程异常退出自动重启
// - 远程触发发布新版本
// - 采集 CPU/内存/网络指标上报到星尘平台
// - 支持通过星尘平台 Web 界面远程查看日志和执行命令

// 具体见 agent-service 技能中的 ServiceBase 用法
```

## StarFactory 功能入口速查

| 属性 | 类型 | 说明 |
|------|------|------|
| `star.Registry` | `IRegistry` | 服务注册与发现 |
| `star.Config` | `IConfigProvider` | 配置中心（与 IConfiguration 统一接口） |
| `star.Tracer` | `ITracer` | APM 性能追踪（NewSpan/StartSpan） |
| `star.Client` | `IApiClient` | 星尘原始 HTTP 客户端（低级 API） |
| `star.Dust` | `AppClient` | 应用客户端（心跳、服务注册的底层实现） |

## 配置参数速查

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `Server` | 星尘服务端地址 | 空（从 StarAgent/环境变量读取） |
| `AppKey` | 应用唯一标识 | 入口程序集名称 |
| `Secret` | 应用密钥（鉴权） | 空 |
| `TracerPeriod` | 追踪数据上报间隔（秒） | `60` |
| `MaxSamples` | 每周期最大正常采样数 | `1` |
| `MaxErrors` | 每周期最大错误采样数 | `10` |
| `Debug` | 调试模式（输出原始请求） | `false` |

## 自动追踪覆盖范围

| 组件 | 监听器类 | 追踪点 |
|------|---------|--------|
| ASP.NET Core | `AspNetCoreDiagnosticListener` | HTTP 入站请求 |
| HttpClient | `HttpDiagnosticListener` | HTTP 出站调用 |
| EF Core | `EfCoreDiagnosticListener` | SQL 查询 |
| ADO.NET | `SqlClientDiagnosticListener` | SQL 执行 |
| gRPC | `GrpcDiagnosticListener` | gRPC 调用 |
| MongoDB | `MongoDbDiagnosticListener` | 数据库操作 |
| Socket/TCP | `SocketEventListener` | 网络连接 |
| DNS | `DnsEventListener` | 域名解析 |

## 常见错误与注意事项

- **`AppKey` 相同的多个实例会被视为同一服务的多个节点**：同一服务的所有实例使用相同 `AppKey`，注册中心自动识别为同一服务的不同副本，参与负载均衡。
- **配置中心变更不是实时推送而是轮询**：默认 60 秒轮询一次；不要在热路径中假设配置值毫秒级同步，设计时应允许短暂的「旧值」窗口。
- **StarAgent UDP 5500 端口需开放防火墙**：应用通过 UDP 5500 探测本机 StarAgent 获取服务端地址；容器化部署时需映射该端口或通过环境变量 `STAR_SERVER` 指定地址。
- **`DiagnosticListenerObserver.Install()` 只调用一次**：重复调用会注册多个监听器，导致追踪数据重复上报，增加平台存储压力。
- **配置中心 key 区分大小写**：星尘配置中心的 key 大小写敏感；读取 `dbConn` 与 `DbConn` 是两个不同的 key。
- **`secret` 为空时所有应用可接入**：开发环境可省略 secret；生产环境必须配置密钥，防止未授权应用注册到注册中心污染服务列表。
