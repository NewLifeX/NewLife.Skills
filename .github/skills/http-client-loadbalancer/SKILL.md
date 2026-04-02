---
name: http-client-loadbalancer
description: 'Design or use multi-endpoint HTTP clients with failover, weighted routing, race mode, authentication, response mapping, and client reuse. Use when building resilient service-to-service HTTP integrations.'
argument-hint: 'Provide the target service pattern, endpoint list, authentication mode, and whether you need usage guidance, design review, or code generation.'
---

# 设计多节点 HTTP 客户端与负载均衡

## 适用场景

当你需要为服务间调用设计一个可复用的 HTTP 客户端，并且希望具备多地址、故障转移、加权分配、认证、响应解包等能力时，使用本技能。

适合：

- 多服务节点容灾
- 主备切换
- 加权路由
- 快速节点竞速调用
- 统一认证与响应格式适配
- 复用型 SDK / 网关客户端设计

## 核心原则

- 客户端实例应复用，不能每次请求都重新创建
- 服务列表、负载均衡和请求构造应分层处理
- 网络异常应触发节点切换，但业务异常不应盲目重试
- 认证、过滤器、响应解包都应作为可插拔能力
- 慢调用、统计和跟踪应尽量内置在客户端层

## 推荐能力清单

- 多地址配置
- 故障转移（Failover）
- 加权轮询（Weighted Round Robin）
- 竞速调用（Race）
- Token / Authentication 认证
- 自定义状态码字段与数据字段映射
- 请求/响应/错误过滤器
- 统计、追踪、慢调用日志
- 文件下载与校验（如有需求）

## 执行步骤

1. 明确服务地址来源：静态配置、配置中心、服务发现或运行时注入。
2. 定义服务节点模型，至少包含名称、地址、权重、可用状态、错误统计。
3. 选择负载均衡模式：主备优先、加权分配，或竞速模式。
4. 设计客户端复用策略，避免每个请求新建 `HttpClient`。
5. 设计请求构造与响应解包层，支持认证、统一错误处理和字段映射。
6. 区分网络失败与业务失败，只有前者才进入自动切换或重试路径。
7. 为慢调用、统计、链路追踪留出扩展点。

## 输出要求

输出至少包含：

- 节点组织方式
- 负载均衡选择理由
- 请求与响应约定
- 认证与过滤策略
- 客户端复用与资源管理要求
- 异常处理与观测能力

## 参考资料

- 参考 `references/newlife-apihttpclient-patterns.md`

## 三种负载均衡策略（NewLife.Remoting）

如果使用 `NewLife.Remoting` 中的 `ApiHttpClient`，以下三种内置策略可直接配置：

### 策略对比

| 策略 | 类型 | 适用场景 | 带宽开销 |
|------|------|---------|---------|
| 故障转移 | `FailoverLoadBalancer` | 主备切换，正常只用主节点，故障自动接管 | 低 |
| 加权轮询 | `WeightedRoundRobinLoadBalancer` | 多实例按性能比例分流 | 低 |
| 竞速调用 | `RaceLoadBalancer` | 极低延迟要求，接受带宽消耗 | 高 |

### 服务节点定义（ServiceEndpoint）

```csharp
var services = new List<ServiceEndpoint>
{
    new ServiceEndpoint("primary",  new Uri("http://10.0.0.1:8080")),          // 主节点
    new ServiceEndpoint("backup",   new Uri("http://10.0.0.2:8080")),          // 备节点
    new ServiceEndpoint("s2",       new Uri("http://10.0.0.3:8080")) { Weight = 2 }, // 权重=2（60%）
};
```

### ILoadBalancer 接口

```csharp
public interface ILoadBalancer
{
    LoadBalanceMode Mode { get; }
    Int32 ShieldingTime { get; set; }                 // 错误屏蔽秒数（默认 60）
    ServiceEndpoint GetService(IList<ServiceEndpoint> services);
    void PutService(IList<ServiceEndpoint> services, ServiceEndpoint svc, Exception? error);
    //                                                                       ↑ null = 成功，非null = 失败
}
```

### 使用示例（故障转移）

```csharp
var lb = new FailoverLoadBalancer { ShieldingTime = 30 };

var svc = lb.GetService(services);
try
{
    var result = await CallAsync(svc.Address);
    lb.PutService(services, svc, null);        // 报告成功
}
catch (Exception ex)
{
    lb.PutService(services, svc, ex);          // 报告失败 → 自动屏蔽节点，下次切换
}
```

### 负载均衡行为细节

**FailoverLoadBalancer**：
1. 优先使用 `services[0]`（主节点）
2. `HttpRequestException`/`TaskCanceledException` → 屏蔽当前节点 `ShieldingTime` 秒，切换到下一节点
3. 屏蔽到期后，下次 `GetService` 尝试切回主节点
4. 全部节点不可用时自动重置，重新尝试

**WeightedRoundRobinLoadBalancer**：
1. 节点按 `Weight` 比例分配：`Weight = 3 / 2` → 约 60% / 40%
2. 每节点在轮次内用满配额后切换，网络异常时跳过

**RaceLoadBalancer**：并发请求所有节点，第一个响应成功的即返回，其余请求取消。
