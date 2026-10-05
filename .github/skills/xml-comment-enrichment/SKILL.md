---
name: xml-comment-enrichment
description: >-
  对已有 C# 类库项目分级刷新 XML 注释，使其达到 AI 友好标准。
  扫描 public/protected API，补全缺失的 <summary>/<param>/<returns>/<example>/<remarks>，
  增强已有注释。核心类全面刷新，普通类补齐必填项，工具类仅补 <summary>。
  适用场景：基础类库注释补全、NuGet 包文档质量提升、Tier 1 知识源建设。
argument-hint: >-
  说明目标项目路径、刷新级别（核心/普通/工具的全量或指定）、是否包含 <example> 代码块。
---

# XML 注释 AI 友好化刷新

## 适用场景

- 基础类库项目（NewLife.Core / NewLife.XCode / NewLife.Remoting 等）的 XML 注释补全与增强
- NuGet 包发布前提升文档注释质量
- 落实三层架构 Tier 1 策略：让 XML 注释成为 AI 的第一手知识来源

## 核心理念

> **XML 注释是 Tier 1 最高杠杆知识源**——跟版本走、跨项目自动可用、AI 跳转定义即得。
> 本技能指导 AI 如何写出高质量的、对 AI 友好的 XML 注释。

---

## 1. AI 友好注释标准

### 1.1 必须项（所有 public/protected 成员）

| 成员类型 | 必须的标签 |
|----------|-----------|
| 类型（class/struct/interface/enum/record） | `<summary>` |
| 方法（含构造函数、运算符） | `<summary>` + 每个参数 `<param name="...">` + `<returns>`（非 void 时） |
| 属性（含索引器） | `<summary>` |
| 字段（public/protected） | `<summary>` |
| 事件 | `<summary>` |
| 委托 | `<summary>` + `<param>` + `<returns>`（非 void 时） |

### 1.2 推荐项（核心类 / 高频 API）

| 标签 | 何时使用 | 示例 |
|------|----------|------|
| `<remarks>` | 适用/不适用场景说明、反常规设计解释、性能注意事项 | `<remarks>本方法非线程安全，请在单线程或加锁环境下使用。</remarks>` |
| `<example>` | 主入口类、高频 API、易误用的方法 | 完整可运行的代码块（3-15 行） |
| `<seealso>` | 相关 API 互相指引 | `<seealso cref="Pool.StringBuilder"/>` |
| `<typeparam>` | 泛型类型参数 | `<typeparam name="T">实体类型</typeparam>` |

### 1.3 编写规范

适用全部 NewLife 项目，与 `copilot-instructions.md` §4.5 对齐：

- `<summary>` **必须同行闭合**：`/// <summary>获取名称</summary>`
- 中文描述，简洁准确（"获取…"、"设置…"、"表示…"）
- `<example>` 代码块完整可运行，包含必要的 using 和上下文
- `<remarks>` 重点写"为什么这样设计"而非重复 `<summary>`
- `<param>` 描述参数含义和约束（可空？范围？格式？）
- `<returns>` 描述返回值含义和可能为 null 的条件

---

## 2. 分级策略

根据类的重要程度分为三级：

### 核心类（Core Tier）

**判定标准**：高频使用、入口类、框架基础类型。

**示例**（以 NewLife.Core 为例）：`XTrace`、`SettingBase`、`TimerX`、`MachineInfo`、`Runtime`、`ApiHttpClient`、`SpanReader`、`Pool`、`Utility` 等。

**注释要求**：

- 所有必须项 100% 覆盖
- `<remarks>` 覆盖所有类型和主要方法
- 主入口类型至少 1 个 `<example>`
- 高频方法（>5 处调用）需要 `<example>`
- 反常规设计必须有 `<remarks>` 解释
- 相关 API 用 `<seealso>` 互相指引

### 普通类（Normal Tier）

**判定标准**：业务类、辅助类、中等使用频率。

**注释要求**：

- 所有必须项 100% 覆盖
- 主要方法有 `<remarks>` 补充说明
- 可选 `<example>`（复杂方法推荐添加）

### 工具类（Utility Tier）

**判定标准**：扩展方法类、简单转换器、内部辅助类。

**注释要求**：

- `<summary>` 100% 覆盖
- `<param>` 和 `<returns>` 补全（如有参数/返回值）

---

## 3. 工作流

### 步骤 1：扫描与分级

1. 扫描目标项目的所有 `.cs` 文件
2. 提取所有 `public`/`protected` 类型和成员
3. 按分级标准为每个类型标注级别（核心/普通/工具）
4. 检查每个成员的现有注释完整性

```markdown
## 注释扫描报告 — {项目名}

### 概览
| 级别 | 类型数 | 成员数 | 注释覆盖率 | 需新增 <example> |
|------|:------:|:------:|:--------:|:---------------:|
| 核心 | {N} | {M} | {百分比}% | {X} |
| 普通 | {N} | {M} | {百分比}% | {Y} |
| 工具 | {N} | {M} | {百分比}% | — |

### 缺失清单（核心类）

| 类型 | 成员 | 缺失项 | 优先级 |
|------|------|--------|:------:|
| `XTrace` | `WriteLog` | `<param>`×2, `<remarks>` | 🔴 |
| `Pool` | `StringBuilder` | `<example>` | 🟡 |
```

### 步骤 2：用户确认

列出缺失清单后，等待用户确认：

- 分级是否准确（核心/普通/工具的归属是否合理）
- 刷新范围（全部 or 仅核心类 or 指定几个类）
- 是否需要 `<example>` 代码块（会增加工作量但价值最高）

### 步骤 3：逐文件补充

按优先级（核心 > 普通 > 工具）逐文件处理：

1. 读取源文件
2. 为每个缺失注释的成员生成注释：
   - 从方法名和签名推断功能描述
   - 阅读方法体理解行为和边界条件
   - 参考已有良好注释的同类方法
3. 使用 `edit/editFiles` 精确插入注释（不重写整个文件）
4. 每处理完一个文件，编译验证一次

### 步骤 4：编译验证

所有文件处理完后：

```bash
dotnet build
```

确保 XML 文档生成无警告（特别是 `CS1591` 缺失 XML 注释警告）。

### 步骤 5：输出刷新报告

```markdown
## 📝 XML 注释刷新报告 — {项目名}

### 刷新统计
| 级别 | 处理类型数 | 新增 <summary> | 新增 <param> | 新增 <returns> | 新增 <example> | 新增 <remarks> |
|------|:--------:|:------------:|:----------:|:------------:|:------------:|:------------:|
| 核心 | {N} | {X} | {Y} | {Z} | {W} | {V} |
| 普通 | {N} | {X} | {Y} | {Z} | {W} | {V} |
| 工具 | {N} | {X} | {Y} | {Z} | — | — |

### 注释覆盖率变化
| 指标 | 刷新前 | 刷新后 |
|------|:------:|:------:|
| `<summary>` 覆盖率 | {百分比}% | {百分比}% |
| `<param>` 覆盖率 | {百分比}% | {百分比}% |
| `<returns>` 覆盖率 | {百分比}% | {百分比}% |
```

---

## 4. 注释模板

### 类型

```csharp
/// <summary>高性能字符串构建器池</summary>
/// <remarks>
/// 适用于高频字符串拼接场景（如日志、序列化）。
/// 从池中获取实例，用完后归还，避免频繁分配。
/// 不适用于需长期持有的 StringBuilder 引用。
/// </remarks>
/// <example>
/// var sb = Pool.StringBuilder.Get();
/// sb.Append("Hello ");
/// sb.Append("World");
/// var result = sb.Put(true); // 归还并返回字符串
/// </example>
public static class Pool
```

### 方法

```csharp
/// <summary>从池中获取 StringBuilder 实例</summary>
/// <returns>已清空的 StringBuilder 实例，用完后需调用 <see cref="Put"/> 归还</returns>
/// <example>
/// var sb = Pool.StringBuilder.Get();
/// try { sb.Append("data"); }
/// finally { sb.Put(); }
/// </example>
public static StringBuilder Get()
```

### 属性

```csharp
/// <summary>获取或设置缓存过期时间（秒）</summary>
/// <remarks>设为 0 表示永不过期。默认值 600（10 分钟）。</remarks>
public Int32 Expire { get; set; }
```

### 参数

```csharp
/// <param name="name">用户名，不能为空</param>
/// <param name="age">年龄，范围 0-150</param>
/// <param name="cancellationToken">取消令牌，可选</param>
```

### 返回值

```csharp
/// <returns>找到的用户实体；未找到时返回 <c>null</c></returns>
```

---

## 5. 常见陷阱

| 陷阱 | 错误示例 | 正确做法 |
|------|----------|----------|
| 重复方法名 | `/// <summary>Get</summary>` | `/// <summary>从池中获取 StringBuilder 实例</summary>` |
| 无信息量 | `/// <summary>名称</summary>` | `/// <summary>获取或设置用户显示名称</summary>` |
| 缺参数约束 | `/// <param name="name">名称</param>` | `/// <param name="name">用户名，不能为空，最大长度 50</param>` |
| `<example>` 不可运行 | 缺少 using / 上下文 | 包含完整 using 和必要初始化 |
| `<remarks>` 重复 `<summary>` | 两段内容相同 | `<remarks>` 写适用场景/不适用场景/为什么这样设计 |
