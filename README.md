# NewLife.Skills

**NewLife Copilot 资产统一管理库**——集中管理 NewLife 系列项目可复用的 Copilot 资产：全局指令、专用指令、技能、智能体。

克隆到任意机器后执行一条脚本即可安装到 VS Code 用户数据目录，**无需在每个项目放一份 `.github`**。

---

## 设计理念

资产采用**最小化策略**，分三层承担不同职责：

| 层级 | 载体 | 内容 | 维护成本 |
|---|---|---|---|
| **Tier 1** | NuGet 包 XML 注释 | 类与成员的「如何使用」 | 跟代码一起维护 |
| **Tier 2** | 本仓库全局 instructions | NewLife 反常规约定（硬约束） | 极低，集中维护 |
| **Tier 3** | 本仓库 skill / agent | 流程类、架构决策类、跨组件取舍 | 仅必要项 |

**判定原则**：能由 XML 注释或通用知识覆盖的，不做 skill；能由全局 instructions 承担的，不做专用 instructions。

---

## 快速开始

```powershell
git clone https://github.com/NewLifeX/NewLife.Skills.git
cd NewLife.Skills
.\scripts\install-copilot-assets.ps1
```

安装完成后**重启 VS Code**，所有项目即可使用全部资产。

### 更新

直接重新执行 `install-copilot-assets.ps1`。脚本基于 manifest 自动同步：

- 新资产 → 复制
- 仓库已删除但上次安装过的 → **自动清理**（孤儿清理）
- 不会触碰 manifest 之外的文件

### 首次从旧脚本迁移

如果之前用过旧版安装脚本（没有 manifest），磁盘上残留了大量旧 skill / instructions / agent，加 `-AssumeAllOrphans` 一次性清理：

```powershell
# 先预览将清理什么
.\scripts\install-copilot-assets.ps1 -AssumeAllOrphans -WhatIf

# 确认后执行
.\scripts\install-copilot-assets.ps1 -AssumeAllOrphans
```

### 卸载

```powershell
.\scripts\install-copilot-assets.ps1 -Uninstall
```

---

## 资产清单

### 全局指令

[.github/copilot-instructions.md](.github/copilot-instructions.md)——所有 NewLife 项目通用的硬约束：加载标注、兼容性、命名/类型/风格规范、防御性注释、内置工具优先、工作流。

### 专用指令（按关键词触发加载）

存放于 [.github/instructions/](.github/instructions)：

| 文件 | 触发场景 |
|---|---|
| `xcode.instructions.md` | XCode / Model.xml / 数据库 ORM |
| `development.instructions.md` | 新建系统 / 需求分析 / 架构设计 / 多迭代开发 |

### Skills（按需加载）

存放于 [.github/skills/](.github/skills)，每个技能一个子目录：

| 技能 | 适用场景 |
|---|---|
| `xcode-data-modeling` | 设计 Model.xml、xcode 命令生成实体 |
| `xcode-sharding-etl` | XCode 分库分表、ETL 数据同步 |
| `cube-mvc-backend` | Cube 后台管理系统、字段定制、视图覆盖 |
| `network-server-sessions` | NetServer/NetSession 高性能服务器架构 |
| `testing-strategy` | XCode + SQLite 轻量集成测试 |
| `benchmark-testing` | BenchmarkDotNet 流程化性能测试 |
| `project-architecture` | 两层/三层架构选型、充血模型 |
| `development-workflow` | 需求拆分、迭代开发流程 |
| `coding-standards` | 编码规范的元规则（写新规范时参考） |
| `compatibility-checks` | 多目标框架兼容性审查 |

### Agents（用户主动 `@` 调用）

存放于 [.github/agents/](.github/agents)：

| Agent | 用途 |
|---|---|
| `release-prep` | 月度发版准备（ChangeLog/版本号/PackageReleaseNotes） |
| `project-init` | 新项目初始化（NewLife 技术栈脚手架） |
| `code-review` | 按 NewLife 规范审查代码 |

### Prompts

存放于 [.github/prompts/](.github/prompts)：

| 文件 | 用途 |
|---|---|
| `doc-writer.prompt.md` | 为 C# 代码生成高质量 Markdown 文档 |

---

## 仓库结构

```text
.github/
  copilot-instructions.md   # 全局 Copilot 协作规范（必须遵守）
  instructions/             # 专用指令（关键词触发）
  skills/                   # 技能（按需加载）
  agents/                   # 智能体（@ 调用）
  prompts/                  # 提示词模板
docs/                       # 设计文档、技能体系说明
scripts/
  install-copilot-assets.ps1
```

---

## 安装路径

`install-copilot-assets.ps1` 将资产复制到：

| 资产 | 目标 |
|---|---|
| Skills (`<name>/SKILL.md`) | `%APPDATA%\Code\User\prompts\skills\` |
| Instructions / Prompts / Agents | `%APPDATA%\Code\User\prompts\` |
| 全局指令 | `%APPDATA%\Code\User\prompts\newlife-global.instructions.md` |

---

## 维护原则

1. **30 天淘汰制**：连续 30 天未触发的 skill / instructions 进入删除候选
2. **搬运型禁止**：能由 XML 注释或通用知识覆盖的内容不做 skill
3. **单一事实源**：API 用法首选 XML 注释；架构决策首选 skill；硬约束首选全局 instructions
4. **改动验证**：修改后在真实项目随机提一个相关问题，观察「已加载」标注是否符合预期

详见 [docs/skill-system-design.md](docs/skill-system-design.md)。
