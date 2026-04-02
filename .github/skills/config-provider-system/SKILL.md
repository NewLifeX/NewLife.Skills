---
name: config-provider-system
description: >
  在 .NET 应用中设计或使用统一配置提供者架构，涵盖强类型单例配置、多格式文件（XML/JSON/INI）、
  远程配置中心（HTTP/Apollo）、热更新绑定、冒号分隔多级 Key 访问，以及命令行参数解析。
  适用于配置系统设计、IConfigProvider 实现、ConfigAttribute 定义，以及代码审查任务。
argument-hint: >
  说明你的配置场景：本地文件还是远程配置中心；是否需要热更新；
  强类型单例 (Config<T>) 还是手动 IConfigProvider；单环境还是多 Scope。
---

# 配置提供者系统设计技能

## 适用场景

- 为应用程序定义强类型配置对象，并希望自动与文件（XML/JSON/INI）双向同步。
- 使用远程配置中心（如星尘、Apollo）统一管理多服务配置，需要轮询热更新和本地缓存兜底。
- 在同一进程中同时使用多种配置来源，需要优先级组合或命名空间隔离。
- 解析命令行参数并与配置模型合并。
- 审查现有配置代码是否遵循接口优先、单例访问、热更新安全等原则。

## 核心原则

1. **接口优先**：所有代码面向 `IConfigProvider` 接口，不直接依赖 `XmlConfigProvider` 等具体类型；提供者实例通过 `Config<T>.Provider` 替换，而不是在业务逻辑中手动创建。
2. **强类型单例 `Config<T>`**：每种配置使用独立的继承类，通过 `Config<T>.Current` 单例访问；`Current` 线程安全，首次访问自动加载文件，文件不存在时返回默认值并写磁盘。
3. **热更新 `Bind`**：`provider.Bind<T>(model, autoReload: true)` 让配置变更自动同步到模型属性；订阅方应避免在 `Changed` 回调中执行耗时逻辑。
4. **冒号多级 Key**：索引器 `provider["Database:ConnectionString"]` 支持跨层级读写，等价于节点树遍历，无须手动拆分路径。
5. **首次创建检测**：`IsNew = true` 表示配置文件首次生成，可在 `OnLoaded()` 中做默认值初始化和 `Save()` 落盘；避免在构造时递归访问 `Current`。

## 执行步骤

### 一、选择提供者类型

| 场景 | 推荐提供者 |
|------|-----------|
| 本地 XML（默认）| `XmlConfigProvider`（`Config<T>` 默认） |
| 本地 JSON | `JsonConfigProvider` via `[Config("name", Provider = typeof(JsonConfigProvider))]` |
| 本地 INI | `IniConfigProvider` |
| 星尘/自研配置中心 | `HttpConfigProvider` |
| Apollo | `ApolloConfigProvider` |
| 多来源组合 | `CompositeConfigProvider` |

### 二、定义 `Config<T>` 强类型配置

1. 继承 `Config<TConfig>`，添加 `[Config("文件名")]` 特性。
2. 每个属性加 `[Description("...")]` 注释——`XmlConfigProvider` 会把它写成 XML 注释；`JsonConfigProvider` 会忽略。
3. 在 `OnLoaded()` 中验证/修正字段值，确保不合法字段不会传到业务层。
4. 不要在类的静态构造或实例构造中访问 `Config<T>.Current`（递归加载陷阱）。

```csharp
[Config("AppSettings")]
public class AppSettings : Config<AppSettings>
{
    [Description("服务端口")]
    public Int32 Port { get; set; } = 8080;

    [Description("调试模式")]
    public Boolean Debug { get; set; }

    protected override void OnLoaded()
    {
        if (Port is <= 0 or > 65535) Port = 8080;
    }
}

// 使用
var cfg = AppSettings.Current;
var port = cfg.Port;
```

### 三、切换为远程配置中心

```csharp
// 在应用启动最早处（Main / 程序入口）覆盖 Provider
AppSettings.Provider = new HttpConfigProvider
{
    Server = "http://stardust-config-center",
    AppId  = "my-service",
    Secret = "xxx",
    Scope  = "production",
    Period = 30,          // 每 30 秒轮询
    CacheLevel = ConfigCacheLevel.Json  // 本地明文缓存兜底
};
```

- `Provider` 必须在首次访问 `Current` 之前赋值；赋值后置空 `_Current`（若有该 API）重新加载。
- 不要在 DI 容器构造期间访问 `Current`，可能导致提供者尚未替换。

### 四、热更新绑定模型

```csharp
var provider = new HttpConfigProvider { /* ... */ };

// 绑定 POCO 模型，配置变更自动写回属性
provider.Bind<FeatureFlags>(flags, autoReload: true);

// 监听变更事件做额外处理
provider.Changed += (_, _) =>
{
    _logger.Info("配置已更新");
    RefreshCaches();
};
```

- `Bind` 会立即从 `provider` 加载一次，后续配置变更触发 `Changed` 时自动更新属性。
- 修改绑定后的模型属性后，需要显式调用 `provider.Save(model)` 才能持久化。

### 五、命令行参数解析

```csharp
var parser = new CommandParser { IgnoreCase = true };
var args = parser.Parse(Environment.GetCommandLineArgs());

// --port 9090 → args["port"] = "9090"
// -v          → args["v"]    = null

var port = args["port"].ToInt(8080);
```

### 六、自定义 `IConfigProvider`

1. 实现 `LoadAll()`（从数据源 → 配置树 `Root`）和 `SaveAll()`（配置树 → 数据源）。
2. `this[key]` 的 get 调用 `Root` 的节点树遍历，set 写回对应节点并触发 `Changed`。
3. 如需自定义属性映射（如字段名转换），实现目标类上的 `IConfigMapping` 接口。

## 重点检查项

- [ ] 是否面向 `IConfigProvider` 接口，而非直接依赖具体类？
- [ ] `Config<T>.Current` 是否在构造函数内（包括静态构造）被调用，导致递归？
- [ ] 远程提供者的 `AppId` 是否已设置（未设置会被服务端拒绝）？
- [ ] 热更新 `Bind` 后修改属性是否遗漏 `Save()`？
- [ ] 配置修改后是否调用了 `SaveAll()` / `Save()`（变更不会自动持久化到文件）？
- [ ] 多来源场景是否用了 `CompositeConfigProvider` 管理优先级？

## 输出要求

- **配置类**：继承 `Config<T>`，有 `[Config]` 特性、`[Description]` 属性注释、`OnLoaded` 验证。
- **提供者初始化**：在 `Main` / `Startup` 最早处完成 `Provider` 赋值，严格早于 `Current` 的首次访问。
- **热更新**：使用 `Bind` + `Changed` 事件，而不是轮询 `Current` 取值对比。
- **测试**：覆盖首次创建（`IsNew`）路径、`OnLoaded` 校验、`Changed` 回调、远端不可用时本地缓存兜底。

## 参考资料

参考示例与模式证据见 `references/newlife-config-patterns.md`。
