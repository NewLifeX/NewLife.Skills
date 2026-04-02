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

- 参考 `references/newlife-core-apihttpclient-patterns.md`
