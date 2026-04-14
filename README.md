# NewLife Skills

**NewLife Copilot 资产统一管理库**——集中管理 NewLife 系列项目所有可复用的 Copilot 资产：技能、指令、提示词、智能体。

克隆到任意机器后，执行一条脚本即可将全部资产安装到 VS Code 用户数据目录，**无需在每个项目里各放一份 `.github`**。

---

## 快速开始

### 安装到本机（Win10/Win11 + VS Code + GitHub Copilot）

```powershell
# 克隆此仓库
git clone https://github.com/NewLifeX/NewLife.Skills.git
cd NewLife.Skills

# 安装全部 Copilot 资产到用户级目录
.\scripts\install-copilot-assets.ps1
```

安装完成后**重启 VS Code**，所有项目即可使用以下资产，无需在每个项目中放 `.github` 目录。

---

## 资产清单

### Skills（技能）

存放于 `.github/skills/`，每个技能一个子目录，含 `SKILL.md` 详细指南。共 71 个技能文件夹。

**快速使用指南（usage 类）**——按需快速上手，代码示例为主：

| 技能目录 | 覆盖领域 |
|---------|---------|
| `caching` | ICache/MemoryCache/Redis 统一缓存接口 |
| `logging-tracing` | ILog/XTrace 日志与 ITracer/DefaultTracer 链路追踪 |
| `networking` | NetServer/NetSession TCP/UDP/WebSocket 网络编程 |
| `serialization` | JSON/Binary/Span/CSV 序列化 |
| `configuration` | Config&lt;T&gt;/IConfigProvider/HttpConfigProvider 配置管理 |
| `http-client` | ApiHttpClient 多节点 HTTP 客户端与负载均衡 |
| `dependency-injection` | ObjectContainer/Host/Plugin/Actor 依赖注入与宿主 |
| `timer-scheduling` | TimerX/Cron 高级定时调度 |
| `security` | Hash/AES/SM4/RSA/JWT/TokenProvider 安全与加密 |
| `type-conversion` | ToInt/ToBoolean/StringHelper/Pool.StringBuilder 类型转换与工具 |

**前端美化指南（frontend 类）**——从设计理论到组件级美化，共 12 个技能文件夹：

| 技能目录 | 覆盖领域 |
|---------|---------|
| `frontend-design-system` | 设计令牌体系：色彩/字号/间距/圆角/投影/动画 |
| `frontend-dark-theme` | 亮色/暗色主题设计与实现 |
| `frontend-responsive-layout` | 响应式布局与导航适配 |
| `frontend-tailwind-patterns` | Tailwind CSS 现代模式集：按钮/卡片/毛玻璃/微动画 |
| `frontend-theme-customization` | 五大组件库主题深度定制（Element Plus/Ant Design/Arco/TDesign/Naive UI） |
| `frontend-table-styling` | 后台表格美化：表头/斑马纹/Badge/操作列/空状态/骨架屏 |
| `frontend-form-styling` | 表单美化：浮动标签/校验反馈/分步表单/密码强度 |
| `frontend-navigation-styling` | 导航美化：侧边栏/顶栏/面包屑/标签页路由 |
| `frontend-card-dashboard` | 仪表盘与卡片布局：统计卡/图表容器/排行榜 |
| `frontend-modal-feedback` | 弹窗与反馈：模态框/Toast/空状态页/错误页 |
| `frontend-bootstrap-modernize` | Bootstrap 3/4 现代化美化（Cube MVC 专用） |
| `frontend-visual-polish` | 视觉精修检查清单（20+ 项上线前打磨） |

**深度设计指南（architecture 类）**——涵盖 XCode/Cube/Redis/MQTT/Net/序列化/安全/定时器等所有领域，共 49 个技能文件夹。代表性技能：

| 技能目录 | 覆盖领域 |
|---------|---------|
| `project-architecture` | 项目架构分层：两层起步、按需渐进三层、充血模型 |
| `testing-strategy` | XCode 测试策略：SQLite 轻量集成测试、零架构侵入、测试隔离 |
| `xcode-entity-orm` | NewLife.XCode 实体 CRUD 开发 |
| `xcode-data-modeling` | XCode Model.xml 数据建模 |
| `cube-mvc-backend` | NewLife.Cube MVC 后台管理系统 |
| `redis-client` | NewLife.Redis 高性能 Redis 客户端 |
| `network-server-sessions` | NetServer/NetSession 高性能网络服务器 |
| `cache-provider-architecture` | ICache 统一缓存接口与分布式锁 |
| `security-crypto-patterns` | Hash/AES/RSA/JWT 加密安全 |
| `stardust-platform` | 星尘分布式服务平台接入 |
| `agent-service` | NewLife.Agent 跨平台系统服务 |
| `benchmark-testing` | BenchmarkDotNet 性能基准测试 |

### Instructions（指令）

存放于 `.github/instructions/`，触发关键词时 Copilot 自动加载：

| 文件 | 触发场景 |
|------|---------|
| `xcode.instructions.md` | XCode / 数据库 / Model.xml |
| `net.instructions.md` | NetServer / 网络编程 |
| `benchmark.instructions.md` | 性能测试 / BenchmarkDotNet |
| `development.instructions.md` | 新建系统 / 需求分析 / 架构设计 |
| `caching.instructions.md` | ICache / MemoryCache / Redis 缓存 |
| `serialization.instructions.md` | JSON / Binary 序列化 |
| `security.instructions.md` | 加密 / Hash / JWT / RSA |
| `remoting.instructions.md` | ApiHttpClient / RPC / 负载均衡 |
| `configuration.instructions.md` | Config / IConfigProvider / 配置中心 |

### Prompts（提示词）

存放于 `.github/prompts/`：

| 文件 | 用途 |
|------|------|
| `doc-writer.prompt.md` | 为 C# 代码生成高质量 Markdown 文档 |

### Agents（智能体）

存放于 `.github/agents/`：

| 文件 | 用途 |
|------|------|
| `newlife-expert.agent.md` | NewLife 全生态技术专家 |
| `code-review.agent.md` | NewLife 代码审查（8维度检查） |
| `project-init.agent.md` | NewLife 新项目初始化助手 |
| `release-prep.agent.md` | 开源库月度发版准备（ChangeLog/版本号/README） |

---

## 仓库结构

```text
.github/
  copilot-instructions.md      # NewLife 全局 Copilot 协作规范（含编码规范）
  agents/                      # 智能体定义 (*.agent.md)  → chatmodes/
  instructions/                # 场景指令 (*.instructions.md)  → prompts/
  prompts/                     # 提示词模板 (*.prompt.md)  → prompts/
  skills/                      # 技能文件夹，全部为 <name>/SKILL.md 格式 → prompts/skills/
docs/                          # 分析文档、设计说明
scripts/
  install-copilot-assets.ps1   # 安装脚本（主入口）
  sync-skills-to-user.ps1      # 旧名称兼容包装器
```

---

## 安装说明

`install-copilot-assets.ps1` 将资产复制到以下 VS Code 用户数据目录：

| 资产类型 | 目标路径 |
|---------|---------|
| Skills (`<name>/SKILL.md` 文件夹) | `%APPDATA%\Code\User\prompts\skills\` |
| Instructions (`*.instructions.md`) | `%APPDATA%\Code\User\prompts\` |
| Prompts (`*.prompt.md`) | `%APPDATA%\Code\User\prompts\` |
| Agents (`*.agent.md`) | `%APPDATA%\Code\User\prompts\` |
| 全局指令 (`copilot-instructions.md`) | `%APPDATA%\Code\User\prompts\newlife-global.instructions.md` |

---

## 维护说明

1. 从其他 NewLife 仓库（如 `.github/` 目录）学到新规范后，在此库中统一更新。
2. 更新后重新运行 `install-copilot-assets.ps1` 即可覆盖更新本机资产。
3. 提交到 Git，其他机器 `git pull` 后再次运行脚本即可同步。