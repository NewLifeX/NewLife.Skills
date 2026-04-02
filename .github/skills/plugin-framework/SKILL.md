---
name: plugin-framework
description: >
  使用 NewLife.Core 的 IPlugin / PluginManager 构建应用内插件系统：
  定义插件接口、通过 PluginAttribute 标记宿主、用 PluginManager 扫描/加载/初始化/销毁插件。
  适用于功能扩展点、事件监听器注册、可拔插模块等场景。
argument-hint: >
  说明你的场景：宿主标识是什么（Identity）；插件需要实现哪些附加接口（如 IDataProcessor）；
  是否需要依赖注入（IServiceProvider）获取服务；
  插件是否需要 Dispose（倒序销毁）。
---

# 插件框架技能（IPlugin + PluginManager）

## 适用场景

- 宿主程序定义扩展点接口（如 `IDataProcessor`），插件程序集实现后通过扫描自动加载。
- 模块化架构：各功能模块以插件形式挂载到宿主，解耦核心与扩展逻辑。
- 事件监听器分发：宿主遍历 `Plugins.OfType<IEventListener>()` 通知所有监听器。
- 代码审查：确认 `PluginManager.Dispose()` 在宿主关闭时调用（倒序释放各插件 `IDisposable`）；`Init()` 返回 `false` 的插件会被自动移除。

## 核心原则

1. **`Init()` 决定留存**：插件的 `Init` 返回 `true` 才被保留；`false` 表示"不适用本宿主"，立即从 `Plugins` 中移除。
2. **`[Plugin("Identity")]` 是过滤器**：`Load()` 时只加载带有与宿主 `Identity` 匹配的 `PluginAttribute` 的类型（或无该 Attribute 的类型也会被加载，在 `Init` 中自行判断）。
3. **`IServiceProvider` 在 `Init` 中注入依赖**：插件构造函数无法获取服务；在 `Init(identity, provider)` 中通过 `provider.GetService<T>()` 获取依赖。
4. **倒序 Dispose**：`PluginManager.Dispose()` 按加载逆序调用各 `IDisposable` 插件的 `Dispose()`，确保依赖顺序正确释放。
5. **所有程序集扫描**：`Load()` 扫描 AppDomain 中所有已加载程序集，插件只需在项目中引用即可自动发现。

## 执行步骤

### 一、定义插件接口与实现

```csharp
using NewLife.Model;

// 1. 定义扩展点接口（可选，宿主通过此接口调用插件）
public interface IDataProcessor
{
    string Name { get; }
    void Process(object data);
}

// 2. 实现插件（[Plugin] 标记宿主 Identity）
[Plugin("DataPipeline")]         // 只在 "DataPipeline" 宿主中加载
public class JsonProcessor : IPlugin, IDataProcessor
{
    public string Name => "JSON处理器";

    private ILogger? _logger;

    // 构造函数：宿主加载时调用（此时无服务注入）
    public JsonProcessor() { }

    // Init：宿主初始化时调用，provider 可获取依赖服务
    public bool Init(string? identity, IServiceProvider provider)
    {
        // 非目标宿主则拒绝，PluginManager 会移除此插件
        if (identity != "DataPipeline") return false;

        _logger = provider.GetService<ILogger>();
        _logger?.Info("JsonProcessor 初始化");
        return true;
    }

    public void Process(object data)
    {
        var json = data.ToJson();
        _logger?.Info("处理JSON: {0}", json);
    }
}

// 3. 支持多宿主（多个 PluginAttribute）
[Plugin("WebServer")]
[Plugin("ApiServer")]
public class AuthPlugin : IPlugin
{
    public bool Init(string? identity, IServiceProvider provider) => true;
}
```

### 二、宿主加载插件

```csharp
using NewLife.Model;
using NewLife.Log;

// 创建插件管理器
var manager = new PluginManager
{
    Identity = "DataPipeline",           // 宿主标识，与 PluginAttribute 匹配
    Provider = ObjectContainer.Provider, // 服务容器，传递给 Plugin.Init()
    Log      = XTrace.Log,
};

// 扫描所有已加载程序集，发现并实例化 IPlugin 实现
manager.Load();

// 依次调用 Init()，移除返回 false 的插件
manager.Init();

// 查看已加载的插件
foreach (var plugin in manager.Plugins ?? Array.Empty<IPlugin>())
{
    XTrace.WriteLine("已加载插件: {0}", plugin.GetType().Name);
}

// 宿主关闭时释放（倒序 Dispose）
manager.Dispose();
```

### 三、通过扩展接口使用插件

```csharp
// 遍历实现了特定扩展接口的插件
foreach (var processor in manager.Plugins?.OfType<IDataProcessor>() ?? Enumerable.Empty<IDataProcessor>())
{
    processor.Process(myData);
}

// 事件监听模式
public void RaiseEvent(string eventName, object? args)
{
    foreach (var listener in manager.Plugins?.OfType<IEventListener>() ?? Enumerable.Empty<IEventListener>())
    {
        listener.OnEvent(eventName, args);
    }
}
```

### 四、带生命周期的插件（Dispose）

```csharp
[Plugin("MyApp")]
public class ResourcePlugin : IPlugin, IDisposable
{
    private Timer? _timer;

    public bool Init(string? identity, IServiceProvider provider)
    {
        if (identity != "MyApp") return false;

        // 启动内部资源
        _timer = new Timer(OnTick, null, 0, 5000);
        return true;
    }

    private void OnTick(object? state) { /* 定期任务 */ }

    public void Dispose()
    {
        _timer?.Dispose();
        _timer = null;
        XTrace.WriteLine("ResourcePlugin 已释放");
    }
}
// PluginManager.Dispose() 会倒序调用各插件的 Dispose()
```

### 五、仅获取插件类型（不实例化）

```csharp
// 获取所有匹配的插件类型，自定义实例化逻辑
foreach (var type in manager.LoadPlugins())
{
    XTrace.WriteLine("发现插件类型: {0}", type.FullName);
    // 自定义实例化...
}
```

## 重点检查项

- [ ] 宿主关闭时是否调用了 `manager.Dispose()`（确保插件倒序释放）？
- [ ] 插件 `Init()` 是否在 `identity` 不匹配时返回 `false`（避免无关宿主误加载）？
- [ ] 插件是否在 `Init()` 中获取服务依赖（而不是构造函数，构造函数时 `IServiceProvider` 还未传入）？
- [ ] 实现了 `IDisposable` 的插件是否不在 `Init` 外部缓存资源（Dispose 在宿主关闭时才调用）？
- [ ] `PluginAttribute` 标记的 Identity 是否与 `PluginManager.Identity` 大小写一致（字符串比较）？

## 输出要求

- **插件接口**：`IPlugin`（`NewLife.Model`）—— `Init(identity, provider)` 返回 bool。
- **标记特性**：`[Plugin("HostIdentity")]`，支持重复标注多个宿主。
- **管理器**：`PluginManager`（`NewLife.Model`）—— `Load()`/`Init()`/`Dispose()`；`Identity`/`Provider`/`Plugins`。
- **生命周期**：插件可实现 `IDisposable`；`PluginManager.Dispose()` 倒序调用。

## 参考资料

- `NewLife.Core/Model/IPlugin.cs`
- `NewLife.Core/Model/PluginManager.cs`
- 相关技能：`dependency-injection-ioc`（`ObjectContainer.Provider` 传递给 PluginManager）、`hosted-services-lifecycle`（插件随宿主服务一起启停）
