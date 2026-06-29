# NewLife Copilot 协作指令

适用于 NewLife 系列全部 C#/.NET 仓库，本文件可随仓库/指令目录一起拷贝到其他项目直接复用。**简体中文回复。**
通用 C# 最佳实践（设计模式、SOLID、健壮性等）AI 已知，**仅列出组织专属规则与反常规约定**。

---

## 0. 加载标注（强制）

**每次回答开头第一行**必须输出加载状态，便于用户验证哪些资产真正生效：

```
> 已加载: instructions=[xxx,yyy], skills=[xxx], agent=xxx
```

- 未加载任何专用指令/技能时写 `instructions=[]`、`skills=[]`
- 当前 agent 未指定时写 `agent=default`
- 该行后空一行再开始正文，正文不得省略此标注

---

## 1. 专用指令（前置检查，命中即加载）

开始任务前，将用户请求与下表关键词逐行匹配。**命中则立即用 `read_file` 读取 `.github/instructions/{指令文件}`**。未命中则跳过。

| 触发关键词 | 指令文件 |
|---|---|
| XCode/实体生成/Model.xml/数据库 CRUD/`NewLife.XCode`/`*.xcode.xml`/项目名含 `.Data`/`XCode.*` 命名空间/修改任意 `.xml` 模型文件 | `xcode.instructions.md` |
| Cube/魔方/Web开发/后台管理/`NewLife.Cube` 引用/`NewLife.Cube.*` 命名空间/EntityController/Area/区域控制器 | `cube.instructions.md` |
| 新建系统/新建项目/新增模块/需求整理/需求文档/需求分析/架构设计/技术方案/功能拆分/任务分解/迭代开发/PRD/做一个系统/做一个平台/批量开发/自治模式/全部搞完/接着做 | `development.instructions.md` |

---

## 2. 核心原则

检索优先、风格一致、兼容友好、**主动优化**。
发现明显缺陷（资源泄漏、空引用、逻辑错误）时主动修复；优化请求时深入分析，不做表面工作。
小改动直接做并说明；大改动（公共 API/大范围重构）先列方案询问确认。

**最高杠杆原则**：优先信任 NewLife NuGet 包的 XML 注释。AI 跳转到类型定义即可看到 `<summary>` / `<remarks>` / `<example>`，无需 skill 复述用法。Skill 只承担"流程类、架构决策类、跨多个组件的取舍"。

### 2.1 未知 API 的强制查询步骤

当用户提到某个 NewLife 类型（如 `CsvFile` / `ApiHttpClient` / `MemoryCache` / `TimerX` / `XCode.Entity` 等），或代码中需要使用某个 NewLife 类型而你**不确定其用法**时，**必须按以下顺序查询，禁止凭印象编造 API**：

1. **优先查 XML 注释**：用 `vscode_listCodeUsages` 或 `grep_search` 在工作区或 NuGet 包缓存（`%USERPROFILE%\.nuget\packages\<包名>\<版本>\lib\<tfm>\*.xml`）定位类型，读取其 `<summary>` / `<remarks>` / `<example>`
2. **次选搜索源码**：若工作区包含对应 NewLife 仓库（如 `D:\X\NewLife.Core`），直接 `grep_search` 类型名定位源码
3. **再次官方文档**：访问 https://newlifex.com 或 GitHub 仓库 README
4. **最后才加载 skill**：仅当上述都不足以回答时（一般是流程/架构问题），考虑加载相关 skill

> **禁止行为**：未经查询直接给出 API 调用示例。如果跳过 1~3 步直接编代码，极易虚构方法签名、参数顺序、返回类型。

---

## 3. 兼容性约束（极重要）

- **语言版本**：当前为 **C# 14**（`<LangVersion>latest</LangVersion>`），最大化使用现代语法（switch 表达式、集合表达式 `[]`、`?.`/`??`/`??=`、模式匹配、目标类型 `new`、record 等）
- **框架版本**：新增 API 前先看当前项目 `.csproj` 的 `<TargetFrameworks>`，**只需满足已声明版本的兼容性**。若包含 `net45`/`netstandard2.0` 等低版本，再用条件编译降级
- **禁止高版本专属 BCL API**（低版本项目）：❌ `ArgumentNullException.ThrowIfNull()` → ✅ `if (x == null) throw new ArgumentNullException(nameof(x));`
- **条件编译符号**：`NETFRAMEWORK`、`NETSTANDARD2_0`、`NETCOREAPP`、`NET5_0_OR_GREATER`、`NET6_0_OR_GREATER`、`NET8_0_OR_GREATER`

---

## 4. 编码规范

### 4.1 类型名（关键差异）

**必须**使用 .NET 正式名：`String`/`Int32`/`Boolean`/`Int64`/`Double`/`Object` 等。
❌ **禁止**使用 C# 别名：`string`/`int`/`bool`/`long`/`double`/`object`

### 4.2 命名

| 成员 | 规则 | 示例 |
|---|---|---|
| 类型/公共成员 | PascalCase | `UserService`、`GetName()` |
| 参数/局部变量 | camelCase | `userName`、`count` |
| 私有字段 | `_camelCase` | `_cache`、`_instance` |
| 扩展方法类 | `xxxHelper` 或 `xxxExtensions` | `StringHelper` |

### 4.3 代码风格

- **命名空间**：file-scoped namespace
- **单文件**：每文件一个主要公共类型；较大平台差异使用 `partial`
- **集合初始化**：优先集合表达式 `[]`，如 `List<String> Tags { get; set; } = [];`
- **Null 条件运算符**：优先 `?.`/`??`；**C# 14 空条件赋值 `??=`** 替代 `if (x == null) x = ...`

```csharp
// ✅ C#14 空条件赋值
_cache ??= new MemoryCache();
list ??= [];

// ✅ 单行 if 不加花括号（同行或换行均可）
if (value == null) return;
if (key == null) throw new ArgumentNullException(nameof(key));

if (value == null)
    throw new ArgumentNullException(nameof(value), "Value cannot be null");

// ✅ 多分支单语句不加花括号
if (count > 0)
    DoSomething();
else
    DoOther();

// ✅ for/foreach/while 循环体必须保留花括号（即使单语句）
foreach (var item in list)
{
    Process(item);
}

// ✅ using 优先无花括号声明；仅需生命周期（如锁）时用弃元
using var stream = File.OpenRead("file.txt");
using var _ = _lock.AcquireLock();
```

### 4.4 Region 与日志

较长类使用 `#region` 分段，顺序：`属性` → `静态` → `构造` → `方法` → `辅助` → **`日志`**。
含 `ILog Log` 和 `WriteLog` 时：**必须放类末尾**，用名为"日志"的 region 包裹，不放入"辅助"。
关键过程可使用 `Tracer?.NewSpan()` 埋点。

### 4.5 文档注释

- `<summary>` **必须同行闭合**：`/// <summary>获取名称</summary>`
- 每个参数**必须有** `<param>` 标签，无论方法可见性
- 有返回值**必须有** `<returns>`；复杂方法可增加 `<remarks>`
- `public`/`protected` 成员必须注释；`[Obsolete]` 必须包含迁移建议
- 主入口/常用类型应提供至少一个 `<example>` 代码块（AI 与开发者的首要参考）

### 4.6 异步与性能

- 异步方法后缀 `Async`，库内部默认 `ConfigureAwait(false)`
- 热点路径避免反射/复杂 Linq，优先手写循环/`ArrayPool<T>`/`Span`
- 池化资源明确获取/归还，异常分支不遗失归还

### 4.7 错误处理

- 精准异常类型：`ArgumentNullException`/`InvalidOperationException` 等
- TryXxx 模式：不用异常作常规分支
- 类型转换：优先 `Utility` 扩展方法 — `ToInt()`/`ToLong()`/`ToDouble()`/`ToDecimal()`/`ToBoolean()`/`ToDateTime()`/`ToDateTimeOffset()`
- 对外异常不暴露内部实现/路径

---

## 5. NewLife 内置工具（禁止重复造轮子）

优先使用项目内置工具而非标准库：

- 字符串构建：`Pool.StringBuilder`（替代 `new StringBuilder()`）
- 时间戳（毫秒级相对时间）：`Runtime.TickCount64`；**精确耗时测量：`Stopwatch`**
- 类型转换：`Utility` 扩展方法 — 见 4.7
- 二进制读写：`SpanReader` / `SpanWriter`（替代手动字节偏移）
- 追踪埋点：`Tracer?.NewSpan()`
- HTTP 客户端：`ApiHttpClient`（多节点/负载均衡/失败重试）
- 缓存：`MemoryCache.Instance` / Redis `FullRedis`（统一 `ICache` 接口）
- 定时任务：`TimerX`（替代 `System.Threading.Timer`）

> 详细 API 用法请直接查看对应类型的 XML 注释（IDE 跳转或 NuGet 包文档），无需另行加载技能。

---

## 6. 防御性注释（禁止删除）

代码中带说明文字的被注释代码属于**防御性注释**，记录历史踩坑经验。**禁止删除，禁止"恢复"执行**。可补充更详细说明。

```csharp
// 曾经尝试过同步等待，但会导致线程池饥饿和死锁
// var result = task.Result;

// 不要使用 SendAsync 的无超时重载，否则会造成连接泄漏
// await client.SendAsync(data);
```

---

## 7. 工作流

加载标注 → 触发检查（第 1 节） → 检索（**优先复用**现有实现 + XML 注释） → 评估（公共 API/兼容性/性能） → 方案 → 实施 → 验证 → 必要时 AskQuestions 确认 → 说明

- **触发检查**：开始工作前必须完成，遗漏专用指令将导致输出不符合要求
- **实施**：完成主任务；顺带修复明显缺陷；顺带简化重复代码；保留原注释与结构
- **验证**：代码变更必须编译通过；找到相关测试则运行；仅文档变更可跳过

### 主动优化原则

用户要求**分析/优化代码**时：

| 行动 | 说明 |
|---|---|
| 架构梳理 | 重构不清晰结构 |
| 缺陷修复 | 资源泄漏/空引用/并发/逻辑错误直接修复 |
| 代码简化 | 提取重复、合并冗余、应用现代语法 |
| 性能优化 | 缓存重复计算、池化高频对象、避免无用分配 |
| 注释完善 | 补 XML 注释和关键逻辑说明 |

---

## 8. 测试

- 框架 xUnit；类名 `{ClassName}Tests`；方法加 `[DisplayName("中文描述意图")]`
- 网络端口用 `0`/随机，IO 用临时目录
- 先搜索 `{ClassName}` 引用定位测试文件，再找 `{ClassName}Tests.cs`；**未找到需说明**，不自动创建测试项目

---

## 9. 文档与发布

### Markdown 文档

**UTF-8 无 BOM**；存放 `Doc/` 目录；文件名优先中文，内容优先简体中文，避免乱码。**已有文件必须先读取再增量修改，禁止覆盖。**

> 代码注释同样要求 UTF-8 无 BOM，优先简体中文。

#### 禁止同义改写式文档重构

修改已有 Markdown 文档时，**以原文为基线做最小增量修改**。

**仅以下情形允许修改原句**：
- 新增事实（原文没有描述的内容）
- 旧事实纠错（原文有明确错误）
- 架构/文件/术语发生实质变化（改名、删除、合并）
- 用户明确要求重构表达

**以下情形必须保留原句，不得改写**：
- 修改前后语义完全相同，仅措辞、语序、风格或表达方式不同
- 为"更顺口""更统一""更简洁"而重写语义不变的段落
- 不同 AI 模型风格差异导致的同义改写（A 模型写文档，B 模型整理时尤其容易出现）

**大改动前置审查**：若预计单文件改动超过约 30% 行数，或会导致 Git diff 出现大段重排，必须先输出"保留原句 / 必改语义 / 删除理由 / 新增理由"对照清单，得到用户确认后再修改。

> 所有文档变更都应让评审者能从 Git diff 中直接看出真实内容变化。文档瘦身不能牺牲 Git diff 可读性。

### NuGet 版本

| 类型 | 格式 | 示例 |
|---|---|---|
| 正式版 | `{主}.{子}.{年}.{月日}` | `11.9.2025.0701` |
| 测试版 | `{主}.{子}.{年}.{月日}-beta{时分}` | `11.9.2025.0701-beta0906` |

---

## 10. 重要禁止项

AI 容易犯但在本项目影响严重的错误：

- 将 `String`/`Int32` 改为 `string`/`int`（必须用正式名）
- 删除防御性注释
- 删除 for/foreach/while 循环体的花括号
- 将 `<summary>` 拆成多行
- 擅自删除 `public`/`protected` 成员
- 擅自新增外部 NuGet 依赖（需说明理由）
- 仅删除空白行/注释制造"格式优化"提交
- 虚构不存在的 API/文件/类型
- 伪造测试结果/性能数据
- 在热点路径添加未缓存反射/复杂 Linq
- 输出敏感凭据/内部地址
- 发现问题却视而不见
- 用户要求优化时仅做注释/测试等表面工作
- **跳过加载标注或第 1 节触发检查**
- **对已有 Markdown 文档做同义改写式重构**（修改前后语义相同，仅措辞/语序/风格不同，导致 Git diff 大段变化却无实质内容变化）

---

## 11. 变更说明模板

```markdown
## 概述
做了什么 / 为什么

## 影响
- 公共 API：是/否
- 性能影响：无/有（说明）

## 兼容性
降级策略 / 条件编译点

## 风险与后续
潜在回归 / 是否补测试
```

---

## 12. Skills 与 Agents

资产采用**最小化策略**：能由 NuGet 包 XML 注释承担的，不做 skill；能由全局 instructions 承担的，不做 instructions。仅保留**流程类、架构决策类、跨组件取舍**的资产。

### Skills（按需加载）

仅在用户请求明显涉及对应主题时，主动 `read_file` 读取 `.github/skills/<name>/SKILL.md`：

| 技能 | 适用场景 |
|---|---|
| `xcode-data-modeling` | 设计 Model.xml、xcode 命令生成实体（触发 xcode.instructions.md 后进一步参考） |
| `cube-mvc-backend` | Cube 后台管理深度定制：字段操作速查、视图覆盖、ConfigController（触发 cube.instructions.md 后进一步参考） |
| `project-architecture` | 两层/三层架构选型、充血模型、Service 是否抽取的判断 |
| `benchmark-testing` | BenchmarkDotNet 流程化性能测试、基准报告编写 |
| `competitive-analysis` | 联网搜索 GitHub 竞品、制作功能对比矩阵、输出竞品分析报告 |
| `testing-strategy` | 单元测试（xUnit）/集成测试（SQLite）/E2E 测试策略与规范 |
| `cross-compatibility-testing` | 竞品交叉兼容测试：文件格式/网络协议/编解码的多模式对比验证 |

> **未列入上表的目录均为已废弃**，不应主动加载。

### Agents（用户主动 @ 调用）

| Agent | 用途 |
|---|---|
| `release-prep` | 月度发版准备（ChangeLog/版本号/PackageReleaseNotes） |
| `project-init` | 新项目初始化（NewLife 技术栈脚手架） |
| `code-review` | 按 NewLife 规范审查代码 |
| `dev-loop` | 自治开发循环：选功能→实现→测试→提交→更新清单→检查点报告 |

---

## 13. 资产维护原则

- **30 天淘汰制**：连续 30 天未触发的 skill/instructions 进入删除候选
- **搬运型禁止**：内容能由 XML 注释或通用知识覆盖的 skill 不应存在
- **单一事实源**：API 用法首选 XML 注释；架构决策首选 skill；硬约束首选本文件
- **改动验证**：修改本文件或 instructions 后，在真实项目随机提一个相关问题，观察加载标注是否符合预期

---

（完）
