# NewLife.Core Config 模式证据

> 来源：`configuration.instructions.md` + `Configuration/IConfigProvider.cs` + `Configuration/Config.cs`
> 配置文档（`Doc/配置系统Config.md`）存在编码损坏，以源码为准。

---

## 1. 接口层次（源码校验）

```text
IConfigProvider
├── Name / Root / Keys / IsNew
├── this[key]          冒号多级路径读写
├── GetSection(key)    返回节点对象
├── Changed event      文件变更/远端推送/SaveAll 后触发
├── GetConfig          委托访问入口
├── LoadAll / SaveAll  全量加载/保存
├── Load<T>            加载到强类型模型
├── Save<T>            保存强类型模型
└── Bind<T>            绑定模型 + autoReload 热更新

IConfigSection
├── Key / Value / Childs
└── 树状节点，GetSection(key) 向下遍历
```

---

## 2. `Config<T>` 静态初始化顺序（源码关键路径）

```csharp
// 静态构造器（类首次访问时触发）
static Config()
{
    // 1. 读取 [ConfigAttribute] 获取文件名 / 提供者类型
    var att = typeof(TConfig).GetCustomAttribute<ConfigAttribute>(true);

    // 2. 创建提供者：ConfigProvider.Create(att?.Provider)
    //    默认 → XmlConfigProvider，可通过特性指定

    // 3. 若为 HttpConfigProvider，写入 Server/AppId/Secret 等参数
    // 4. 调用 prv.Init(name) 完成配置文件路径解析

    Provider = prv;
}

// Current 属性（DCL 双重检测锁）
public static TConfig Current
{
    get
    {
        if (_Current != null) return _Current;
        lock (typeof(TConfig)) {
            if (_Current != null) return _Current;
            var config = new TConfig();
            prv.Bind(config, true);  // 立即加载并监听变更
            config.OnLoaded();       // 校验/修正钩子
            _Current = config;       // 赋值（若 IsNew，Save 到磁盘）
        }
    }
}
```

**陷阱：不要在 `TConfig` 的构造函数中访问 `Config<TConfig>.Current`**  
→ 静态构造尚未完成 / DCL 被同一线程递归 → `NullReferenceException` 或死锁。

---

## 3. `IConfigProvider` 核心方法语义

| 方法 | 调用时机 | 副作用 |
|------|---------|--------|
| `LoadAll()` | 启动时、手动刷新 | 覆盖 `Root` 树 |
| `SaveAll()` | 手动保存、`Config<T>.Save()` | 持久化 `Root` 树到数据源 |
| `Load<T>(path)` | 提取子模型 | 无持久化 |
| `Save<T>(model, path)` | 写回子模型 | 触发 `SaveAll()` |
| `Bind<T>(model, autoReload)` | 初始化时 | `Changed` 时自动同步属性 |
| `Changed` event | 文件 FSW / 远端推送 / `SaveAll` | 通知所有订阅方 |

**重要**：`Bind` 后修改模型属性 **不会** 自动持久化，必须显式调用 `Save()`。

---

## 4. HttpConfigProvider 参数速查

```csharp
var prv = new HttpConfigProvider
{
    Server     = "http://stardust:6600",  // 配置中心地址
    AppId      = "myapp",                 // 应用标识（必填，否则服务端拒绝）
    Secret     = "xxxxx",                // 密钥
    Scope      = "production",           // 环境/作用域
    Period     = 60,                     // 轮询间隔（秒）
    CacheLevel = ConfigCacheLevel.Json,  // 本地明文缓存（断网兜底）
    Action     = "Config/GetAll",        // API 路径（默认匹配星尘）
};
```

- `AppId` 未设置：服务端返回 401/403 → 加载失败 → 使用本地缓存（若有）或默认值。
- `CacheLevel = Encrypted`：加密存储本地缓存，防止敏感配置明文落盘。

---

## 5. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| 接口优先（面向 `IConfigProvider`）| ✅ 通用 | 适用任何配置系统设计 |
| 强类型单例 + `OnLoaded` 校验 | ✅ 通用 | 与 `IOptions<T>` 思路一致 |
| 冒号分隔多级 Key | ✅ 通用 | `.NET` `IConfiguration` 同约定 |
| `Bind` + `Changed` 热更新 | ✅ 通用 | 观察者模式，可替换 |
| `Client.Current` DCL 双重检测 | ⚠️ 半通用 | 静态单例模式，须防递归 |
| `[Config]` / `[Description]` 推动 XML 注释 | ⚠️ NewLife 特有 | 不同框架注释机制不同 |
| `ConfigProvider.Create` 工厂 | ⚠️ NewLife 特有 | 通用替代：手动选择并实例化 |
