# NewLife 生态项目 AI 协作配置指南

## 目标

在依赖 `NewLife.Core` 的下游项目中配置 VS Code Copilot，快速建立项目级 AI 协作。

## 文件结构总览

```
你的项目/
├── .github/
│   ├── copilot-instructions.md       # 主指令（自动加载）
│   ├── instructions/
│   │   └── {module}.instructions.md  # 模块级指令（applyTo 自动加载）
│   ├── skills/
│   │   └── {topic}.skill.md          # 技能文件（用户 # 引用）
│   └── agents/
│       └── {role}.agent.md           # 代理文件（用户 @ 调用）
```

| 类型 | 加载方式 | 内容侧重 |
|------|---------|---------|
| instructions | 自动（applyTo + 触发信号） | 必须/禁止、架构约束、命名规范 |
| skills | 用户 `#` 引用 | 怎么用、代码示例、最佳实践 |
| agents | 用户 `@` 调用 | 角色定义、工作流、输出格式 |

---

## 主指令模板（`copilot-instructions.md`）

```markdown
# {项目名} Copilot 协作指令

适用于 {项目名} 全部代码。简体中文回复。
本项目依赖 NewLife.Core，核心编码规范继承 NewLife 主仓库 copilot-instructions.md。

## 1. 专用指令（前置检查）

| 触发信号 | 指令文件 |
|---------|---------|
| {关键词} | `{module}.instructions.md` |

## 2. 项目概述

- 项目名：{NuGet 包名}
- 核心功能：{一句话描述}
- 依赖：NewLife.Core {最低版本}+
- 目标框架：{net6.0/net8.0}

## 3. 架构约束

（项目专属架构规则，如实体基类、控制器基类等）

## 4. 编码规范补充

（在 NewLife 核心规范基础上，项目特有的补充规则）

## 5. 禁止项

（项目特有的禁止操作）
```

**要点**：核心规范（`String`/`Int32`、`Pool.StringBuilder` 等）无需重复声明，只写项目专属规则。

---

## 模块指令模板（`{module}.instructions.md`）

```markdown
---
applyTo: "**/YourModule/**"
---

# {模块名} 开发指令

## 架构概述
（3-5 句话）

## 核心接口
（关键接口/类及其职责）

## 编码规则

### 必须
- 规则 1（附 ✅/❌ 对比代码）

### 禁止
- 禁止项 1

## 常见模式
（2-3 个典型代码片段）
```

`applyTo` 模式参考：

| 模块类型 | applyTo 示例 |
|---------|------------|
| XCode 实体 | `"**/Entity/**"` |
| Cube 控制器 | `"**/Controllers/**"` |
| 缓存实现 | `"**/Caching/**"` |
| 协议处理 | `"**/Protocol/**"` |

---

## 技能文件模板（`{topic}.skill.md`）

```markdown
---
description: "一句话描述技能用途，供 Copilot 搜索匹配"
---

# {技能名}

## 功能概述

## 快速开始

```csharp
// 最简示例
```

## 核心 API

```csharp
// 从源码提取的真实签名
```

## 常见场景

### 场景 1：{描述}

```csharp
// 完整可运行代码
```

## 注意事项
```

**无需重复**已由 NewLife.Core 提供的技能（缓存、日志、网络、序列化、配置等），只写项目特有内容。

---

## 代理文件模板（`{role}.agent.md`）

```markdown
---
description: "代理的一句话描述"
tools: [readFile, search, editFiles]
---

# {代理名称}

## 角色定义
## 工作流程
1. 步骤 1
2. 步骤 2

## 输出格式
## 约束
```

---

## 来源

- `D:\X\NewLife.Core\Doc\AI协作开发指南.md`
