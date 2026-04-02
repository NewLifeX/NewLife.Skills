# NewLife.Core 来源映射表

本文用于把 `d:\X\NewLife.Core` 中的高价值知识来源映射到 `d:\X\NewLife.Skills` 的目标技能，作为后续持续提炼、融合和校验的依据。

## 总体原则

- **先高价值**：优先处理 `.github` 协作指令，其次是 `Doc/` 高价值模块文档，最后是源码稳定约定。
- **先通用化**：优先抽象为通用技能；仅当规则强依赖 `NewLife.*` 组件或 API 时，才保留来源说明和适用边界。
- **先建映射再落文件**：每个来源文件都应先进入本表，再决定是转成技能、参考资料，还是暂缓处理。
- **用源码校验文档**：功能文档不能直接照搬，必须回到真实代码符号交叉验证。

## 来源分级说明

| 等级 | 含义 | 处理策略 |
|------|------|---------|
| 高 | 可直接抽象为跨仓库通用技能 | 第一批优先实施 |
| 中 | 有明显通用价值，但需要源码补证据 | 第二批处理 |
| 低 | 仓库专属或组件强绑定 | 保留来源，暂不通用化 |
| 样板 | 适合做 skill 的 `references/`、模板或案例 | 作为支撑资料纳入 |

## 第一批来源映射

### 1. `.github` 协作指令

| 来源文件 | 主要内容 | 分级 | 目标技能/文档 | 当前决策 |
|---------|---------|------|---------------|---------|
| `.github/copilot-instructions.md` | 核心原则、兼容性、编码规范、测试、文档发布、禁止项 | 高 | `coding-standards`、`compatibility-checks` | 已开始抽象 |
| `.github/instructions/development.instructions.md` | 需求 → 设计 → 拆分 → 迭代 → 验收 → 自治批处理 | 高 | `development-workflow` | 已开始抽象 |
| `.github/instructions/benchmark.instructions.md` | BenchmarkDotNet 规范、报告格式、分析约束 | 高 | `benchmark-testing` | 已开始抽象 |
| `.github/prompts/doc-writer.md` | API 文档 frontmatter 与章节骨架 | 高 | `write-tech-docs`（增强） | 已纳入增强计划 |
| `.github/instructions/caching.instructions.md` | 缓存模块规范 | 中 | 待后续决定：通用缓存技能 / 仅作为来源 | 暂缓 |
| `.github/instructions/serialization.instructions.md` | 序列化模块规范 | 中 | 待后续决定：序列化技能 | 暂缓 |
| `.github/instructions/security.instructions.md` | 安全与加密规范 | 中 | 待后续决定：安全技能 | 暂缓 |
| `.github/instructions/configuration.instructions.md` | 配置系统规范 | 中 | 待后续决定：配置技能 | 暂缓 |
| `.github/instructions/remoting.instructions.md` | API / 负载均衡 / 远程调用规范 | 中 | 可能支撑 `http-client-loadbalancer` | 暂缓 |
| `.github/instructions/net.instructions.md` | 网络服务、会话、管道、编解码 | 低 | 更适合作为后续源码分析参考 | 暂缓 |
| `.github/instructions/xcode.instructions.md` | XCode ORM 专属规范 | 低 | 不纳入本轮通用技能 | 排除 |
| `.github/agents/*.agent.md` | 代理角色定义与工作边界 | 样板 | 未来可转元技能/代理模板 | 暂不处理 |
| `.github/skills/*.skill.md` | NewLife.Core 专属功能说明 | 样板 | 作为未来功能型 skill 参考结构 | 暂不直接迁移 |

### 2. `Doc/` 功能文档

| 来源文件 | 主题 | 分级 | 目标技能/文档 | 当前决策 |
|---------|------|------|---------------|---------|
| `Doc/核心库目录.md` | 全量导航索引 | 高 | `docs/newlife-core-analysis-roadmap.md`、后续主题映射 | 立即使用 |
| `Doc/HTTP客户端ApiHttpClient.md` | 多节点 HTTP 客户端、故障转移、负载均衡 | 高 | `http-client-loadbalancer` | 已开始实施 |
| `Doc/事件总线EventBus.md` | 事件驱动、消息分发 | 高 | `event-bus-messaging` | 第一批样板 |
| `Doc/数据包IPacket.md` | 高性能缓冲区、数据包设计 | 高 | `high-performance-buffers` | 第一批样板 |
| `Doc/轻量级应用主机Host.md` | 宿主与生命周期 | 中 | 可能形成 `hosted-services-lifecycle` | 第二批 |
| `Doc/网络服务端NetServer.md` | 网络服务框架 | 中 | 可能形成 `network-socket-framework` | 第二批 |
| `Doc/缓存系统ICache.md` | 统一缓存抽象 | 中 | 可能形成 `cache-provider-architecture` | 第二批 |
| `Doc/日志ILog.md` | 日志与追踪 | 中 | 可能形成 `logging-tracing-system` | 第二批 |
| `Doc/文档标准模板.md` | 文档结构与规范 | 高 | `write-tech-docs` 参考资料 | 第一批增强 |
| `Doc/AI协作开发指南.md` | AI 协作经验 | 样板 | 未来元技能 | 暂缓 |
| `Doc/文档驱动AI分发架构.md` | 文档驱动工作流 | 样板 | 未来流程/元技能 | 暂缓 |
| `Doc/性能/*.md` | 性能报告与测试结果 | 样板 | `benchmark-testing` 的参考资料 | 参考 |

### 3. 源码捕获入口

| 来源文件 | 关键观察点 | 分级 | 目标技能/文档 | 当前决策 |
|---------|-----------|------|---------------|---------|
| `NewLife.Core/Common/Utility.cs` | 静态门面、可替换实现、类型转换、XML 注释风格 | 高 | `coding-standards`、后续源码捕获技能 | 第一批证据源 |
| `NewLife.Core/Net/NetServer.cs` | 多协议服务器、管道、事件驱动、会话生命周期 | 高 | `development-workflow` 参考、后续 `network-socket-framework` | 第一批证据源 |
| `NewLife.Core/Remoting/ApiHttpClient.cs` | 负载均衡、服务发现、请求构造、配置绑定 | 高 | `http-client-loadbalancer`、`compatibility-checks` 参考 | 第一批证据源 |
| `NewLife.Core/Configuration/*` | 多配置源、远程配置 | 中 | 后续 `config-provider-system` | 第二批 |
| `NewLife.Core/Caching/*` | 统一缓存接口与实现 | 中 | 后续 `cache-provider-architecture` | 第二批 |
| `NewLife.Core/Serialization/*` | 多格式序列化与适配 | 中 | 后续 `binary-serialization` / `serialization-patterns` | 第二批 |
| `NewLife.Core/Model/ObjectContainer.cs` | IoC、服务提供者、宿主协作 | 中 | 后续 `dependency-injection-patterns` | 第二批 |

## 第一批要落地的技能

| 技能名 | 主要来源 | 目标 |
|-------|---------|------|
| `coding-standards` | `.github/copilot-instructions.md` + `Utility.cs` | 抽象仓库显式编码规范与项目特例处理方式 |
| `compatibility-checks` | `.github/copilot-instructions.md` + `Utility.cs` | 处理多目标框架、语言版本、条件编译、兼容性边界 |
| `development-workflow` | `development.instructions.md` | 抽象需求→设计→任务→迭代→验收流程 |
| `benchmark-testing` | `benchmark.instructions.md` | 抽象 BenchmarkDotNet 与性能报告规范 |
| `write-tech-docs`（增强） | `doc-writer.md` + `文档标准模板.md` | 强化 frontmatter、章节骨架、追溯来源 |
| `http-client-loadbalancer` | `ApiHttpClient.cs` + `remoting.instructions.md` + `HTTP客户端ApiHttpClient.md` | 抽象多节点 HTTP 客户端、故障转移、负载均衡与认证模式 |

## 暂缓项

以下内容价值高，但若立刻通用化容易失真，本轮只登记不迁移：

- `caching.instructions.md`
- `serialization.instructions.md`
- `security.instructions.md`
- `configuration.instructions.md`
- `remoting.instructions.md`
- `net.instructions.md`
- `.github/skills/*.skill.md`

## 进入下一轮的门槛

在进入 `Doc/` 功能技能与源码深挖前，应先满足以下条件：

1. 第一批 4 个通用技能已成型。
2. `write-tech-docs` 已完成增强。
3. 至少 1 个 `.github` 来源技能完成从来源 → 技能 → references 的最小闭环。
4. 已有一份正式的源码扫描路线文档，避免后续分析失控。
