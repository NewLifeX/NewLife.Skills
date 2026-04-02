# NewLife.Core C# 风格样本

本文记录从 `d:\X\NewLife.Core` 观察到的代表性 C# 风格，用作 `coding-standards` 的参考样本，而不是要求所有仓库一律照搬。

## 已观察到的稳定规则

### 1. 命名空间与文件组织

- 使用 file-scoped namespace
- 单文件通常只承载一个主要公共类型
- 大类会用 `#region` 分组，常见顺序：属性 → 构造 → 创建/方法 → 业务 → 日志 → 辅助

### 2. 命名风格

- 接口统一使用 `I*`
- 私有字段使用 `_camelCase`
- 类型、方法、属性使用 PascalCase
- 参数、局部变量使用 camelCase
- 扩展/辅助类常命名为 `*Helper` 或 `*Extensions`

### 3. 注释风格

- `public` / `protected` 成员通常有 XML 注释
- `<summary>` 倾向单行闭合
- 复杂类型会用 `<remarks>` 解释设计理念、生命周期、典型用法
- 文档常附带 `newlifex.com/core/...` 链接

### 4. 项目特例

以下模式在 NewLife.Core 中具有明确的仓库风格属性，不应未经判断就推广到其它仓库：

- 偏好使用正式类型名：`String`、`Int32`、`Boolean`，而不是 `string`、`int`、`bool`
- 强调保留“防御性注释”，即记录历史踩坑经验的注释代码
- 循环体要求保留花括号
- 高频对象倾向优先复用项目内置池化设施

## 代表性证据

### `Common/Utility.cs`：静态门面 + 可替换实现

```csharp
// 静态门面持有可替换提供者
public static DefaultConvert Convert { get; set; } = new DefaultConvert();

// 扩展方法委托给提供者——调用方感知不到具体实现
public static Int32 ToInt(this Object? value, Int32 defaultValue = 0)
    => Convert.ToInt(value, defaultValue);
```

- 正式类型名贯穿整个文件：`String`、`Int32`、`Boolean`、`Double`、`DateTime`
- XML 注释 `<summary>` 倾向单行闭合；`<remarks>` 包含设计原因、背景约束
- 文档锚节点写法：`/// 文档 https://newlifex.com/core/utility`（放在类级 `<remarks>` 顶部）

### `Net/NetServer.cs`：大类 region 布局与属性注释

```csharp
// 大类 region 顺序
#region 属性
// Name / Local / Port / ProtocolType / AddressFamily / Servers / Server / ...
#endregion

#region 构造
#endregion

#region 方法
// Start / Stop / CreateSession ...
#endregion
```

属性写法规范（**均有证据**）：

```csharp
// 1. 带 backing field 的属性
private NetUri _Local = new();
public NetUri Local
{
    get => _Local;
    set { _Local = value; /* 副作用 */ }
}

// 2. 懒加载属性（get 内自动初始化）
public ISocketServer? Server
{
    get
    {
        if (ss.Count <= 0) EnsureCreateServer();
        return ss.Count > 0 ? ss[0] : null;
    }
    // ...
}

// 3. 集合属性初始化（.NET 8+ 集合表达式）
public IList<ISocketServer> Servers { get; private set; } = [];
```

`<remarks>` 高级注释写法（**有证据**）：

```csharp
/// <remarks>
/// <para>设计理念：</para>
/// <list type="bullet">
///   <item>多协议支持 - ...</item>
///   <item>双栈支持 - ...</item>
/// </list>
/// <code>
/// var server = new NetServer { Port = 8080 };
/// server.Start();
/// </code>
/// </remarks>
```

- `<para>` 用于段落分隔；`<list type="bullet">` 用于要点列举；`<code>` 内嵌完整可运行示例。
- `<see cref="EnsureCreateServer"/>` 用于跨成员引用（不依赖自由文本）。

### `Remoting/ApiHttpClient.cs`：模块命名前缀约定

- `ServiceEndpoint`（服务端点节点） / `ILoadBalancer`（策略接口） / `ApiHttpClient`（实现类）
- 实现类不以 `I*` + `Default*` 惯例命名，而是直接以功能命名（如 `ApiHttpClient` 而非 `DefaultApiHttpClient`）

---

## 5. 新增观察：C# 语言特性使用边界

| 特性 | 当前仓库态度 | 证据来源 |
|------|-------------|---------|
| file-scoped namespace | ✅ 全面使用 | Utility.cs, NetServer.cs |
| `record struct` 作为值类型包装 | ✅ 使用（`ArrayPacket`）| Data/IPacket.cs |
| 集合表达式 `[]` | ✅ 使用（.NET 8+ 目标框架） | NetServer.cs |
| `#if NET6_0_OR_GREATER` 条件编译 | ✅ 广泛使用 | Utility.cs |
| 正式类型名 `String`/`Int32` | ✅ NewLife 专属约定 | 全库 |
| `var` | ⚠️ 局部变量广泛使用，公共 API 不用 | 全库 |
| `required` / `init` | 未在核心类中大量出现 | — |

---

## 使用方式

- 若当前仓库已有明确 house style，优先遵循当前仓库，而不是强行套用本样本。
- "正式类型名"（`String` vs `string`）是 NewLife 特例，其他仓库扫描时需要独立判断。
- `<remarks>` + `<list>` + `<code>` 内嵌示例是高质量 XML 注释的通用实践，可推广。
- 若要提炼“团队共享规则”，应把这里的特例与通用规则分开写入最终技能。
