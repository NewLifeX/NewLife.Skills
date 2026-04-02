# NewLife.Core 扫描路线图

本文定义 `d:\X\NewLife.Core` 的持续扫描和技能提炼顺序，目标是避免一次性铺得太大，保证每轮都有可验证产出。

## 目标

- 从 `.github` 中提炼可复用的协作技能。
- 从 `Doc/` 中提炼高价值功能型技能。
- 从源码中捕获稳定约定和架构模式。
- 把新知识按“捕获 → 融合 → 发布”的闭环写入当前技能库。

## 总体节奏

```text
第一轮：.github 高价值协作指令
第二轮：Doc 三个样板模块
第三轮：源码基础约定
第四轮：源码架构模式
第五轮：按模块纵深扫描
```

## 第一轮：.github 协作指令

### 输入

- `d:\X\NewLife.Core\.github\copilot-instructions.md`
- `d:\X\NewLife.Core\.github\instructions\development.instructions.md`
- `d:\X\NewLife.Core\.github\instructions\benchmark.instructions.md`
- `d:\X\NewLife.Core\.github\prompts\doc-writer.md`

### 产出

- `coding-standards`
- `compatibility-checks`
- `development-workflow`
- `benchmark-testing`
- 增强后的 `write-tech-docs`

### 校验标准

- 每个技能都能说明“什么时候用”和“输出什么”。
- 每个技能都带至少一份 references 资料。
- 项目特例与通用规则明确区分，不把仓库方言当成语言普遍规律。

## 第二轮：Doc 三个样板模块

### 样板主题

1. `HTTP客户端ApiHttpClient.md`
2. `事件总线EventBus.md`
3. `数据包IPacket.md`

### 目标技能

- `http-client-loadbalancer`
- `event-bus-messaging`
- `high-performance-buffers`

### 方法

1. 从文档抽出使用场景、核心 API、设计动机、常见坑。
2. 回到源码入口校验真实符号与实现方式。
3. 把模块文档中的性能报告、案例、背景说明拆到 references。

## 第三轮：源码基础约定

### 重点文件

- `NewLife.Core/Common/Utility.cs`
- `NewLife.Core/Net/NetServer.cs`
- `NewLife.Core/Remoting/ApiHttpClient.cs`

### 重点观察

- 命名约定：接口、实现、字段、布尔属性、Helper / Extensions
- 基础风格：命名空间、注释、单文件职责、循环与异常处理
- 项目特例：正式类型名、保留防御性注释、资源池复用

### 目标产出

- `coding-standards` 的增强版 references
- 未来 `capture-csharp-style` 或 `capture-core-conventions` 的候选条目

## 第四轮：源码架构模式

### 重点观察

- 静态门面 + 可替换实现
- 组合模式
- 工厂/提供者模式
- 事件驱动
- 管道处理
- 负载均衡与故障转移

### 重点入口

- `Utility.Convert`
- `NetServer.AttachServer` / `EnsureCreateServer` / `CreateSession`
- `ApiHttpClient.CreateLoadBalancer` / `SetServer` / `InvokeAsync`

### 目标产出

- 架构型技能的候选条目
- 各模块扫描任务的拆分基线

## 第五轮：按模块纵深扫描

按以下顺序推进，每轮只做 1~2 个模块：

1. `Configuration`
2. `Caching`
3. `Serialization`
4. `Net`
5. `Remoting`
6. `Log`
7. `Model/ObjectContainer`

## 每轮固定流程

1. 选定模块。
2. 读取导航和入口文件。
3. 捕获候选规则。
4. 与现有技能去重融合。
5. 产出技能或 references。
6. 更新来源映射与路线图。

## 停止条件与风险控制

满足任一条件时，应先暂停总结再继续：

- 同一轮涉及超过 2 个主题。
- 某主题同时依赖文档、源码、测试、外部站点，证据还不够。
- 新结论与已有技能冲突。
- 出现明显仓库特例，但还没有找到边界说明。

## 完成定义

当以下条件满足时，可视为本轮扫描完成：

- 来源、结论、目标技能三者已经对应起来。
- 至少有一个真实符号或文件可作为引用证据。
- 已决定该知识进入 `SKILL.md`、`references/`，还是暂缓。
- 已更新本路线图或来源映射文档。
