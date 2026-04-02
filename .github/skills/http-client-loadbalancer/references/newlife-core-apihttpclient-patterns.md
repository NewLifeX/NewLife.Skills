# NewLife.Core ApiHttpClient 模式样本

本文基于 `d:\X\NewLife.Core\NewLife.Core\Remoting\ApiHttpClient.cs` 与 `d:\X\NewLife.Core\.github\instructions\remoting.instructions.md` 提炼 `ApiHttpClient` 的关键设计模式。

## 已确认的关键模式

### 1. 服务地址组织

- 支持单地址或多地址逗号分隔
- 支持 `name=weight*url` 形式配置名称与权重
- 支持在地址后附加 `#token=...` 形式的节点级 Token
- 支持从 `IConfigProvider` 绑定服务地址

### 2. 负载均衡模式

`ApiHttpClient` 把负载均衡独立为 `ILoadBalancer`：

- `FailoverLoadBalancer`：主节点优先，失败后切换备用节点
- `WeightedRoundRobinLoadBalancer`：按权重分配请求
- `RaceLoadBalancer`：并行请求多个节点，取最快响应

这说明：**调用层不直接写死节点选择逻辑，而是把节点选择交给独立策略对象。**

### 3. 客户端复用

- 每个 `ServiceEndpoint` 内部缓存 `HttpClient`
- `EnsureClient` 负责惰性创建
- `CreateClient` 统一处理代理、证书、追踪和 UserAgent

这说明：**应复用服务级客户端，而不是按请求创建客户端。**

### 4. 请求构造与响应解包

- `BuildRequest` 根据 HTTP 方法、参数和返回类型构造请求
- `Token` / `Authentication` 统一注入认证头
- `CodeName` / `DataName` 允许适配不同服务端返回结构
- `ApiHelper.ProcessResponse<TResult>` 负责统一解包

### 5. 异常处理边界

在 `InvokeAsync<TResult>` 中：

- 发生 `HttpRequestException` 或 `TaskCanceledException` 时，会继续尝试其它节点
- 业务层异常不会无脑切换所有节点
- 最终会把错误反馈给负载均衡器，用于服务可用性管理

这说明：**网络层失败与业务层失败需要分开处理。**

### 6. 可观测性

- `Tracer` 用于链路跟踪
- `StatInvoke` 用于调用统计
- `SlowTrace` 用于慢调用日志
- `Source` / `Current` 用于暴露当前服务节点

## 适合抽象成团队共享规则的部分

- 多节点 HTTP 客户端要把“服务节点、负载均衡、请求构造、响应解包、认证、过滤器、观测”拆成独立层次
- 复用客户端实例，不要请求级创建
- 节点故障切换只针对网络失败
- 响应结构差异通过字段映射适配，而不是到处写 if/else

## 当前限制

- `d:\X\NewLife.Core\Doc\HTTP客户端ApiHttpClient.md` 当前读取结果存在编码异常，后续如需完整吸收文档示例，建议先统一其编码后再做第二轮融合。
