# NewLife.Skills

**NewLife Copilot 资产统一管理库**——集中管理 NewLife 系列项目可复用的 Copilot 资产：全局指令、专用指令、技能、智能体。

克隆到任意机器后执行一条脚本即可安装到 VS Code 用户数据目录，**无需在每个项目放一份 `.github`**。
也可通过 `npx skills` 一键安装到 VS Code，**无需在每个项目放一份 `.github`**。
也可作为 **VS Code Agent Plugin** 安装，在 VS Code 扩展搜索中直接发现和使用。

---

## 设计理念

资产采用**最小化策略**，分三层承担不同职责：

| 层级       | 载体                    | 内容                           | 维护成本       |
| ---------- | ----------------------- | ------------------------------ | -------------- |
| **Tier 1** | NuGet 包 XML 注释       | 类与成员的「如何使用」         | 跟代码一起维护 |
| **Tier 2** | 本仓库全局 instructions | NewLife 反常规约定（硬约束）   | 极低，集中维护 |
| **Tier 3** | 本仓库 skill / agent    | 流程类、架构决策类、跨组件取舍 | 仅必要项       |

**判定原则**：能由 XML 注释或通用知识覆盖的，不做 skill；能由全局 instructions 承担的，不做专用 instructions。

### 指导思想（2026-10 行业调研后确定，今后改进本库时遵守）

> 依据：60+ 份外部资料调研（Stack Overflow / DORA / JetBrains 调查、Thoughtworks、美团技术团队等公开信息）。

1. **少而准**：AI 的注意力有预算，规则多了会整体失效（社区经验：会话常读指令约 150~200 条就到上限，越短越有效）。宁少勿多、宁短勿长。
2. **约束要可执行**：能用脚本、检查、门禁拦住的问题，不靠文字提醒——文字会被忽略，检查不会（参考 `scripts/verify-assets.ps1`）。
3. **经验固化成工具链**：每条规则都要对应一次真实发生的问题（棘轮原则：犯了错才加规则，没犯过不加）；经验能做成工具就不只写成文档。
4. **评审减负优先**：AI 写码变快后，人的评审成了最大瓶颈（行业数据：PR 数 +98%、评审时长 +91%）。最折磨人的不是完全错，而是「差一点就对」（66% 的开发者要花更多时间修这类代码）。所有产出面向「让人快速审」：小批次、给证据、一句话说清行为变化，并重点标出「看着对、可能差一点」的地方。
5. **信息分层**：短期信息→任务文件；长期决策→决策记录；契约→接口文件；可执行行为→测试；细节→代码与注释。不追求「全量同步」。

---

## 快速开始

### 安装方式对比

| 方式                       | 命令                                                                 | 适用场景               |
| -------------------------- | -------------------------------------------------------------------- | ---------------------- |
| **VS Code Agent Plugin** 🆕 | VS Code 扩展搜索 `@agentPlugins`                                     | 推荐，VS Code 原生体验 |
| **npx skills**             | `npx skills add https://git.newlifex.com/NewLife/NewLife.Skills.git` | 命令行快速安装         |
| **传统克隆**               | `.\scripts\install-copilot-assets.ps1`                               | 离线环境或自定义安装   |

### 方式一：VS Code Agent Plugin（推荐）

1. 在 VS Code 扩展搜索视图（`Ctrl+Shift+X`）中搜索 `@agentPlugins`
2. 找到 **NewLife Skills** 插件并安装
3. 重启 VS Code 后即可使用全部技能和 Agent

> 需要 VS Code 1.96+ 和 GitHub Copilot Chat 扩展。

### 方式二：npx skills

```bash
npx skills add https://git.newlifex.com/NewLife/NewLife.Skills.git
```

或从 GitHub 安装：

```bash
npx skills add https://github.com/NewLifeX/NewLife.Skills.git
```

安装完成后**重启 VS Code**，所有项目即可使用全部资产。

> 需要 [Node.js 18+](https://nodejs.org) 和 `npx`（npm 自带）。首次运行会自动下载 `skills` CLI。

### 查看可用技能

```bash
npx skills add https://git.newlifex.com/NewLife/NewLife.Skills.git --list
```

### 安装单个技能

```bash
npx skills add https://git.newlifex.com/NewLife/NewLife.Skills.git --skill cube-mvc-backend
```

### 方式三：克隆安装（传统方式）

```powershell
git clone https://github.com/NewLifeX/NewLife.Skills.git
cd NewLife.Skills
.\scripts\install-copilot-assets.ps1
```

### 更新

重新执行安装命令即可。`npx skills` 会自动同步最新版本。

传统方式直接重新执行 `install-copilot-assets.ps1`。脚本基于 manifest 自动同步：

- 新资产 → 复制到 `%USERPROFILE%\.copilot\`
- 仓库已删除但上次安装过的 → **自动清理**（孤儿清理）
- 旧位置（`%APPDATA%\Code\User\prompts`）的同名副本 → **自动迁移清理**（加 `-KeepLegacy` 保留）

### 首次从旧脚本迁移

如果之前用过旧版安装脚本（没有 manifest），磁盘上残留了大量旧 skill / instructions / agent，加 `-AssumeAllOrphans` 一次性清理：

```powershell
# 先预览将清理什么
.\scripts\install-copilot-assets.ps1 -AssumeAllOrphans -WhatIf

# 确认后执行
.\scripts\install-copilot-assets.ps1 -AssumeAllOrphans
```

> 旧版脚本把 Instructions / Agents 装在 `%APPDATA%\Code\User\prompts\`，该位置 Agent Host 会话不再读取；新脚本统一装到 `%USERPROFILE%\.copilot\`。

### 卸载

```powershell
.\scripts\install-copilot-assets.ps1 -Uninstall
```

---

## 资产清单

> **项目文档规范**：NewLife 项目的 `Doc/` 目录标准产物（需求文档、功能清单、架构设计、竞品分析）见 [`development-process`](.github/skills/development-process/SKILL.md) 技能。基础约定（文档命名、反模式）见 [`development.instructions.md`](.github/instructions/development.instructions.md)。通过 README 导航即可，无需独立索引文件。

### 全局指令

[.github/copilot-instructions.md](.github/copilot-instructions.md)——所有 NewLife 项目通用的硬约束：加载标注、兼容性、命名/类型/风格规范、防御性注释、内置工具优先、工作流。

### 专用指令（按关键词触发加载）

存放于 [.github/instructions/](.github/instructions)：

| 文件                          | 触发场景                                              |
| ----------------------------- | ----------------------------------------------------- |
| `xcode.instructions.md`       | XCode / Model.xml / 实体生成 / 数据库 ORM             |
| `cube.instructions.md`        | Cube / 魔方 / 后台管理 / EntityController / Area 区域 |
| `development.instructions.md` | 新建系统 / 需求分析 / 架构设计 / 迭代开发 / 自治模式  |

### Skills（按需加载）

存放于 [.github/skills/](.github/skills)，每个技能一个子目录：

| 技能                          | 适用场景                                                                                   |
| ----------------------------- | ------------------------------------------------------------------------------------------ |
| `xcode-data-modeling`         | 设计 Model.xml、xcode 命令生成实体                                                         |
| `cube-mvc-backend`            | Cube 后台管理深度定制：字段速查、视图覆盖、ConfigController                                |
| `project-architecture`        | 两层/三层架构选型、充血模型、Service 抽取判断、简单优先（约 90% 覆盖）与扩展设计                                              |
| `development-process`         | 研发全流程（新建→演化）：需求文档/功能清单/架构设计、迭代开发、自治批处理、迭代演化期（变更路由/文档回流/架构地图/收敛体检） |
| `testing-strategy`            | 单元测试（xUnit）/集成测试（SQLite）测试策略                                               |
| `e2e-testing`                 | NewLife 前端/Cube 的 Playwright E2E 标准：搭建/登录会话复用/标准场景清单/失败截图/数据隔离 |
| `benchmark-testing`           | BenchmarkDotNet 基准测试：设计/运行/结果分析/性能报告                                      |
| `cross-compatibility-testing` | 竞品交叉兼容测试：文件格式/网络协议/编解码多模式验证                                       |
| `xml-comment-enrichment`      | XML 注释 AI 友好化刷新：分级补全 `<summary>`/`<param>`/`<returns>`/`<example>`/`<remarks>` |
| `doc-writer`                  | 为 C# 代码生成高质量 Markdown 文档（frontmatter/概述/快速开始/API 表格/最佳实践）          |

### Agents（用户主动 `@` 调用）

存放于 [.github/agents/](.github/agents)：

| Agent                  | 用途                                                                                |
| ---------------------- | ----------------------------------------------------------------------------------- |
| `competitive-analysis` | 联网搜索竞品、功能对比矩阵、输出竞品分析报告                                        |
| `benchmark-testing`    | BenchmarkDotNet 流程化性能测试、基准报告                                            |
| `release-prep`         | 月度发版准备（ChangeLog/版本号/PackageReleaseNotes）                                |
| `project-init`         | 新项目初始化（NewLife 技术栈脚手架）                                                |
| `code-review`          | 按 NewLife 规范审查代码；产出四要素工单并登记待修复项，修完即删                      |
| `large-refactoring`    | 大型重构只读讨论搭档：影响面→方案对比→切片计划，确认后交「开发循环」执行            |
| `upgrade-compat`       | 下游依赖升级兼容：编译分诊→二进制兼容扫描→修复→回归验证                            |
| `dev-loop`             | 自治开发循环：选功能→实现→测试→DoD自检+完成凭证→更新清单→提交→批次末自审→检查点报告 |
| `doc-sync`             | 代码↔文档双向同步：从代码重建文档体系，或用文档审计代码一致性                       |
| `implementation-audit` | 实现缺口审计：逐功能对照需求文档，发现未完整实现的功能并规划修复                    |

### 协作场景速查

| 你的诉求 | 用什么 |
| -------- | ------ |
| 大型重构/跨层改造：先谈方案，谈妥再改 | 「大型重构」（只读讨论）→「开发循环」（"按方案执行"） |
| 审查代码、找改进项，修完为止 | 「代码审查」→ 待修复项工单（FIX-/IMP-）→「开发循环」修复；不修项入收口记录，防重复报告 |
| 批量开发新功能 / 修复待修复项 | 「开发循环」（"继续开发"/"全部搞完"） |
| 代码与文档对齐、重建文档体系 | 「文档同步」「实现审计」 |
| 下游项目更新 NuGet 后出现兼容问题 | 「升级兼容」（编译分诊→兼容扫描→修复→回归） |
| 上线后的迭代打磨（增删/细化功能、防文档漂移） | 变更路由 + 文档回流（development-process §2.9）→「开发循环」执行 |

---

## 仓库结构

```text
.github/
  copilot-instructions.md   # 全局 Copilot 协作规范（必须遵守）
  instructions/             # 专用指令（关键词触发）
  skills/                   # 技能（按需加载）
  agents/                   # 智能体（@ 调用）
  plugin.json               # VS Code Agent Plugin 清单
docs/                       # 维护原则与治理文档
scripts/
  install-copilot-assets.ps1
```

---

## 安装路径

`install-copilot-assets.ps1` 将资产复制到 Copilot 官方用户目录 `%USERPROFILE%\.copilot\`：

| 资产                       | 目标                                                              |
| -------------------------- | ----------------------------------------------------------------- |
| Skills (`<name>/SKILL.md`) | `%USERPROFILE%\.copilot\skills\`                                  |
| Instructions               | `%USERPROFILE%\.copilot\instructions\`                            |
| Agents                     | `%USERPROFILE%\.copilot\agents\`                                  |
| 全局指令                   | `%USERPROFILE%\.copilot\instructions\newlife-global.instructions.md` |

> Agent Host 会话（Session Target 为 Copilot）只读取 Agent Host 的用户目录，不再读取 VS Code 配置目录（`%APPDATA%\Code\User\prompts`）。从旧版脚本升级时会自动清理旧位置同名副本（含已废弃的 `*.prompt.md`），加 `-KeepLegacy` 可保留。

---

## 维护原则

1. **30 天淘汰制**：连续 30 天未触发的 skill / instructions 进入删除候选
2. **搬运型禁止**：能由 XML 注释或通用知识覆盖的内容不做 skill
3. **单一事实源**：API 用法首选 XML 注释；架构决策首选 skill；硬约束首选全局 instructions
4. **改动验证**：修改后在真实项目随机提一个相关问题，观察「生效」标注是否符合预期
5. **棘轮增补**：新增规则 / 资产必须对应一次真实发生的问题；不因「以后可能用到」而提前预设

详见 [docs/三层架构与维护原则.md](docs/三层架构与维护原则.md)。

---

## 项目使用建议

将本仓库资产安装到 VS Code 后，建议在你的项目 `README.md` 中声明以下信息，帮助 AI 更准确地工作（开发循环 agent 会优先读取）：

```markdown
## AI 协作声明

- **项目类型**：.NET 后端 / Node.js 前端 / 全栈
- **编译命令**：`dotnet build` / `pnpm build`
- **测试命令**：`dotnet test` / `pnpm test`
- **核心项目**：`src/MyApp.Service`（后端）、`src/MyApp.Web`（前端）
```

> 声明后，开发循环 agent 的编译/测试命令检测步骤会优先以 README 声明为准，无需每次手动指定。
