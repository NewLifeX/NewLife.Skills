---
name: configuration
description: 使用 NewLife 配置系统管理应用配置，支持本地文件、配置中心和命令行参数
---

# NewLife 配置系统使用指南

## 适用场景

- 应用程序配置管理（替代 appsettings.json）
- 强类型配置绑定
- 远程配置中心集成（Stardust / Apollo）
- 配置热更新和变更通知
- 命令行参数解析

## 业务配置类命名与存储选择

### 命名约定

业务应用的配置类一般命名为 `xxxSetting` 或 `xxxConfig`，继承 `Config<xxxSetting>`。

| 元素 | 说明 |
|------|------|
| 类名 | `XxxSetting` 或 `XxxConfig`，PascalCase |
| `[Config("Xxx")]` | 指定配置文件名，默认保存到 `./Config/Xxx.config` |
| `[DisplayName("Xxx设置")]` | 用于 Cube 配置页面的标题显示 |
| `[Description("...")]` | 每个属性的中文说明，配置页面和 XML 注释会用到 |
| `[Category("分类名")]` | 属性分组，配置页面按分组展示 |
| `OnLoaded()` | 校验与修正默认值，每次加载后触发 |

### 存储方式选择

| 应用场景 | 推荐存储 | 说明 |
|----------|---------|------|
| 服务端应用 + 使用 Membership 数据库 | `DbConfigProvider`（数据库） | 配置保存在 Parameter 表，后台可直接编辑 |
| 服务端应用 + 使用星尘配置中心 | `HttpConfigProvider`（远程） | 集中管理，多实例共享 |
| 客户端应用 / 无数据库 | 默认（本地文件） | 保存为 `./Config/Xxx.config` 文件 |
| 重型客户端 + 使用 Membership 数据库 | `DbConfigProvider`（数据库） | 同服务端模式 |

### 完整业务配置类示例

```csharp
using System.ComponentModel;
using NewLife.Configuration;
using XCode.Configuration;

/// <summary>订单设置</summary>
[DisplayName("订单设置")]
[Config("Order")]
public class OrderSetting : Config<OrderSetting>
{
    #region 静态
    /// <summary>指向数据库参数字典表。服务端应用使用数据库存储</summary>
    static OrderSetting() => Provider = new DbConfigProvider { UserId = 0, Category = "Order" };
    #endregion

    #region 属性
    /// <summary>订单超时时间。默认30分钟</summary>
    [Description("订单超时时间。默认30分钟")]
    [Category("通用")]
    public Int32 OrderTimeout { get; set; } = 30;

    /// <summary>最大退款次数。默认3次</summary>
    [Description("最大退款次数。默认3次")]
    [Category("通用")]
    public Int32 MaxRefundCount { get; set; } = 3;

    /// <summary>启用自动确认收货。默认true</summary>
    [Description("启用自动确认收货。默认true")]
    [Category("系统功能")]
    public Boolean AutoConfirm { get; set; } = true;
    #endregion

    #region 方法
    /// <summary>加载后校验</summary>
    protected override void OnLoaded()
    {
        if (OrderTimeout <= 0) OrderTimeout = 30;
        if (MaxRefundCount <= 0) MaxRefundCount = 3;

        base.OnLoaded();
    }
    #endregion
}
```

> **客户端配置**：如果是客户端应用不使用数据库，只需删除静态构造函数即可，其余代码不变，配置自动保存为 `./Config/Order.config` 文件。

---

## 强类型配置（Config\<T\>）

### 定义配置类

```csharp
public class AppConfig : Config<AppConfig>
{
    /// <summary>应用名称</summary>
    public String AppName { get; set; } = "MyApp";

    /// <summary>数据库连接字符串</summary>
    public String ConnectionString { get; set; } = "Data Source=app.db";

    /// <summary>服务端口</summary>
    public Int32 Port { get; set; } = 8080;

    /// <summary>启用调试模式</summary>
    public Boolean Debug { get; set; }

    /// <summary>加载后校验</summary>
    protected override void OnLoaded()
    {
        if (Port <= 0 || Port > 65535) Port = 8080;
    }
}
```

### 使用配置

```csharp
// 首次访问自动从文件加载（默认 AppConfig.json）
var config = AppConfig.Current;

var name = config.AppName;
var port = config.Port;

// 修改并保存
config.Debug = true;
config.Save();

// 首次运行生成默认配置文件
if (config.IsNew)
    XTrace.WriteLine("已生成默认配置文件，请修改后重启");
```

## IConfigProvider 直接使用

### JSON 配置文件

```csharp
var provider = new JsonConfigProvider { FileName = "config.json" };
provider.LoadAll();

// 读取值（冒号分隔多级 key）
var connStr = provider["Database:ConnectionString"];

// 绑定到对象
var dbConfig = provider.Load<DatabaseConfig>("Database");

// 监听变更
provider.Changed += (s, e) => XTrace.WriteLine("配置已变更");
```

### XML / INI 配置

```csharp
// XML
var provider = new XmlConfigProvider { FileName = "config.xml" };

// INI
var provider = new IniConfigProvider { FileName = "config.ini" };
```

## 远程配置中心

### Stardust 配置中心

```csharp
var provider = new HttpConfigProvider
{
    Server = "http://star.newlifex.com:6600",
    AppId = "MyApp",
    Secret = "xxx",
    Scope = "production",    // 环境标识
    Period = 60,             // 轮询间隔秒数
};
provider.LoadAll();

// 替换全局 Config 提供者
AppConfig.Provider = provider;

// 之后通过 AppConfig.Current 自动从配置中心获取
```

### Apollo 配置中心

```csharp
var provider = new ApolloConfigProvider
{
    Server = "http://apollo-server:8080",
    AppId = "MyApp",
};
```

## 数据库配置（DbConfigProvider）

当服务端应用使用了 Membership 数据库时，推荐将业务配置保存到数据库的 Parameter 表中，便于运维在后台直接修改，无需重启。

### 基本用法

在配置类的**静态构造函数**中设置 `Provider` 为 `DbConfigProvider`：

```csharp
using XCode.Configuration;

[DisplayName("支付设置")]
[Config("Pay")]
public class PaySetting : Config<PaySetting>
{
    /// <summary>指向数据库参数字典表</summary>
    static PaySetting() => Provider = new DbConfigProvider { UserId = 0, Category = "Pay" };

    /// <summary>支付超时时间。默认900秒</summary>
    [Description("支付超时时间。默认900秒")]
    [Category("通用")]
    public Int32 PayTimeout { get; set; } = 900;
}
```

### 关键参数

| 参数 | 说明 |
|------|------|
| `UserId` | 用户ID。`0` 表示系统级全局配置，非零值表示特定用户的个性化配置 |
| `Category` | 分类名。对应 Parameter 表的 Category 字段，一般用配置类去掉 `Setting` 后缀的名称（如 `OrderSetting` → `"Order"`） |
| `CacheLevel` | 本地缓存级别。默认 `Json`，数据库不可用时从 `Data/dbConfig_{Category}.json` 加载 |
| `Period` | 定时刷新间隔（秒）。默认 15 秒，配置变更后自动同步到内存 |

### 存储位置

- **数据库表**：XCode Membership 模块的 `Parameter` 表，属于 `Membership` 连接名
- **本地缓存**：`Data/dbConfig_{Category}.json`（自动生成，数据库不可用时兜底）
- **首次迁移**：如果数据库中无数据但本地 `Config/xxx.config` 文件存在，`DbConfigProvider` 会自动将文件配置保存到数据库

---

## 自动绑定与热更新

```csharp
var provider = new JsonConfigProvider { FileName = "app.json" };
provider.LoadAll();

var config = new AppConfig();
provider.Bind(config, autoReload: true);  // 文件变更时自动更新对象

// 或带变更回调
provider.Bind(config, "AppConfig", section =>
{
    XTrace.WriteLine("配置已更新：{0}", section["AppName"]);
});
```

## 命令行参数

```csharp
var parser = new CommandParser { IgnoreCase = true };
var args = parser.Parse(Environment.GetCommandLineArgs());

// 命令行: --port 8080 --debug -v
var port = args["port"].ToInt();     // 8080
var debug = args.ContainsKey("debug"); // true
var verbose = args.ContainsKey("v"); // true

// 字符串分割为参数数组
var parts = CommandParser.Split("--port 8080 --name \"My App\"");
```

## 内置全局配置

```csharp
// Setting 类（全局应用设置，对应 Config/Core.config）
var setting = Setting.Current;
setting.LogPath = "Logs";
setting.TempPath = "Temp";
setting.PluginPath = "Plugins";
setting.Save();

// SysConfig（系统配置，应用名/版本/显示名等元数据）
var sys = SysConfig.Current;
sys.Name = "MyApp";
sys.DisplayName = "我的应用";
```

## 注意事项

- `Config<T>.Current` 是线程安全的单例
- 默认使用 JSON 格式，文件名为 `Config/{类名}.json`
- `OnLoaded()` 在每次加载后调用，适合做校验和默认值修正
- `IsNew = true` 表示配置文件首次创建，可提示用户修改
- `HttpConfigProvider` 会本地缓存（加密），即使配置中心不可用也能启动
- 不要在静态构造函数中访问 `Config<T>.Current`（可能死锁）；但在静态构造函数中**赋值 `Provider`** 是安全的（只是设置提供者引用，不触发加载）
- `DbConfigProvider` 有本地缓存兜底机制：数据库不可用时从 `Data/dbConfig_{Category}.json` 自动加载上次缓存
- 属性加 `[Description]` 和 `[Category]` 后，在 Cube 配置页面和 XML 配置文件中都会生成对应的说明和分组
