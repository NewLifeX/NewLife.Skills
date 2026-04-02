---
name: ip-location
description: >
  使用 NewLife.IP 对 IPv4 地址进行本地高速归属地查询（省市区 + 运营商），
  涵盖 Ip/IpDatabase 初始化与查询、IpResolver.Register() 注入 NewLife.Net 生态、
  IpHelper 扩展方法（IPToAddress/ToUInt32IP）、内存映射文件（MMF）+ 二分查找架构，
  以及自动下载/更新 IP 数据库的机制。
  适用于 Web 访问日志归属地分析、用户注册地域统计、风控 IP 黑名单等场景。
argument-hint: >
  说明你的 IP 查询场景：单次查询还是批量处理；是否集成到 NewLife.Net 生态；
  是否需要自定义 IP 数据库文件路径；是否有并发高频查询需求。
---

# IP 地址归属地查询技能（NewLife.IP）

## 适用场景

- 用户注册/登录时记录 IP 归属地（省市区 + 运营商）。
- Web API 访问日志分析，统计用户地域分布。
- 风控系统识别异地登录、境外 IP 访问。
- 高并发网关/代理服务中对每个请求做 IP 地域标记（O(log N) 查询，不影响主路径性能）。
- 与 NewLife.Net 框架集成，Session 连接信息自动附带 IP 归属地。

## 核心原则

1. **`IpResolver.Register()` 是集成 NewLife.Net 的最简方式**：调用一次后，`NetHelper.GetAddress(ip)` / `IPAddress.IPToAddress()` 均使用本地数据库查询；无需每次实例化 `Ip` 对象。
2. **`Ip` 对象线程安全，可全局共享**：底层使用 `MemoryMappedFile`（MMF）只读访问 + `ThreadStatic` 缓冲区，高并发环境下无锁竞争；不要在每次查询时 `new Ip()`，开销大。
3. **`Init()` 幂等可重复调用**：内部有懒加载锁，重复调用不会重复加载；但第一次 `Init()` 若数据库文件不存在，会自动从 `PluginServer` 下载，建议应用启动阶段主动调用。
4. **`GetAddress` 返回元组 `(area, addr)`**：`area` 是地区部分（"中国–广东–深圳"），`addr` 是附加信息（运营商/机房 ISP 描述）；两者均为 GB2312 解码后的中文字符串。
5. **数据库文件自动下载条件**：本地 `ip.gz` 不存在、文件大小 < 3MB、或文件最后修改时间早于内置基线日期；生产离线部署时预先复制 `ip.gz` 到 `DataPath` 目录，避免运行时下载。
6. **仅支持 IPv4**：库不处理 IPv6 地址（返回空字符串）；混合 IPv4/IPv6 环境中需先做地址类型判断。

## 执行步骤

### 一、最简集成（推荐：注册到 NewLife.Net）

```csharp
using NewLife.IP;

// 应用启动时调用一次（注册到全局 NetHelper.IpResolver）
IpResolver.Register();

// 之后在任意位置使用扩展方法
var addr = "116.234.91.199".IPToAddress();
// 输出: "中国–上海–上海 <运营商描述>"

// 或用 IPAddress 对象
var ip = IPAddress.Parse("39.144.10.35");
var fullAddr = ip.IPToAddress();
// 输出: "中国–广东–深圳 <运营商描述>"
```

### 二、独立实例查询

```csharp
var ipService = new Ip();
ipService.Init();  // 首次调用，加载/下载数据库

// 查询（返回 area + addr 元组）
var (area, addr) = ipService.GetAddress("61.160.219.25");
Console.WriteLine($"地区: {area}");   // "中国–江苏–常州"
Console.WriteLine($"附加: {addr}");   // "<运营商描述>"

// 联合字符串
var full = $"{area} {addr}".Trim();
```

### 三、自定义数据库路径

```csharp
// 指定自定义 IP 数据库（支持 .gz 压缩）
var ip = new Ip { DbFile = @"D:\data\ip2025.gz" };
ip.Init();

var (area, addr) = ip.GetAddress("223.5.5.5");
```

### 四、批量查询（高并发场景）

```csharp
// IpResolver.Register() 后，线程安全的全局查询
Parallel.ForEach(logEntries, entry =>
{
    entry.Region = entry.IpAddress.IPToAddress();
});
```

### 五、Web API 中间件集成

```csharp
// Startup.cs / Program.cs
IpResolver.Register();  // 启动时注册，只需一次

// Controller 中
[HttpPost("login")]
public IActionResult Login([FromBody] LoginRequest req)
{
    var clientIp   = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "";
    var ipLocation = clientIp.IPToAddress();

    _logger.Info($"登录IP: {clientIp} | 归属地: {ipLocation}");
    // ...
}
```

### 六、IP 地址数值转换（IpHelper 扩展）

```csharp
using NewLife.IP;

// 字符串 IP → UInt32（Big-Endian 数值，用于范围查询）
var uint32Ip = "192.168.1.1".ToUInt32IP();   // 0xC0A80101

// UInt32 → IPAddress
var ipAddr = uint32Ip.ToAddress();            // 192.168.1.1

// UInt32 → 格式化字符串（3 位补零）
var formatted = uint32Ip.ToStringIP();        // "192.168.001.001"

// IPAddress → UInt32
var uint32 = IPAddress.Parse("10.0.0.1").ToUInt32();
```

### 七、离线部署（无网络环境）

```csharp
// 方式 1：预先将 ip.gz 文件放到应用的 DataPath 目录
// DataPath 默认为应用运行目录（由 NewLife.Core Setting.DataPath 决定）

// 方式 2：指定绝对路径
var ip = new Ip { DbFile = "/opt/app/data/ip.gz" };
ip.Init();

// 方式 3：修改 Setting.DataPath
NewLife.Setting.Current.DataPath = "/opt/app/data";
IpResolver.Register();
```

## 数据库格式说明

| 属性 | 说明 |
|------|------|
| 格式 | 纯真 IPv4 库格式（兼容 qqwry.dat/ip.gz） |
| 压缩 | GZip（`.gz`），首次使用自动解压到临时文件 |
| 编码 | GB2312（仅命中记录时解码，不全表加载） |
| 索引 | 7 字节/记录，二分查找 O(log N)，~18 次比较 |
| 存储 | MemoryMappedFile 只读映射，零 GC 压力 |

## 自动更新触发条件

| 条件 | 触发动作 |
|------|---------|
| 本地文件不存在 | 从 `PluginServer` 下载 |
| 文件大小 < 3MB | 重新下载（认为文件损坏） |
| 最后修改时间早于基线 | 重新下载（可能数据过旧） |

## 常见错误与注意事项

- **每次查询 `new Ip()` 导致内存映射文件重复打开**：`Ip` 对象应单例化或使用 `IpResolver.Register()` 全局注册。
- **IPv6 返回空字符串**：`::1`（localhost IPv6）或纯 IPv6 地址无法查询，调用方需先判断 `IPAddress.AddressFamily`。
- **GB2312 在 .NET Core 下需注册编码**：框架内部已处理（调用 `Encoding.RegisterProvider`），但如果宿主应用有自定义编码配置，需确认不会覆盖。
- **`PluginServer` 默认指向 NewLife 官方 CDN**：内网/离线环境需预先放置 `ip.gz`，或通过 `Setting.PluginServer` 指向内网镜像。
- **`Init()` 的下载过程是同步阻塞的**：第一次调用若触发下载，会阻塞当前线程；建议在应用启动阶段（非请求路径）预热调用。
