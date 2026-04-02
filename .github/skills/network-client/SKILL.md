---
name: network-client
description: >
  使用 NewLife.Net.NetClient 构建带自动重连的通用网络客户端（TCP/UDP/WebSocket），
  以及使用 NewLife.Web.WebClientX 进行 HTTP 文件下载、网页抓取和目录式文件探测。
  适用于物联网设备连接、服务间通信、配置文件拉取和安装包自动更新等场景。
argument-hint: >
  说明你的客户端场景：TCP/UDP/WebSocket 长连接（用 NetClient），
  还是 HTTP 下载/抓取/CDN（用 WebClientX）。
  如需断线重连，说明 AutoReconnect/ReconnectDelay/MaxReconnect 配置意图。
---

# 网络客户端技能（NetClient + WebClientX）

## 适用场景

- `NetClient`：IoT 设备到服务端的长连接；微服务间 TCP/UDP 通信；WebSocket 双向推送客户端侧；需要管道编解码（粘包/拆包处理）的自定义协议。
- `WebClientX`：从远端拉取配置文件或安装包；按文件名通配符探测目录并下载最新版本；CDN 签名鉴权下载；下载后自动解压。
- 代码审查：确认 `AutoReconnect=true` 时 `MaxReconnect` 已设置防止无限循环；`Close()` 主动调用以阻止不必要的重连。

## 核心原则

1. **`NetClient` 是 `ISocketClient` 的应用层封装**：不直接持有底层 Socket —— 重连时 `_client` 会被静默替换，**不要在外部长持 `Client` 属性引用**。
2. **协议字符串驱动选择**：`Server = "tcp://…"` / `"udp://…"` / `"ws://…"` 自动决定底层实现，无需手动判断。
3. **管道先于 Open**：`Add<T>()` 必须在 `Open()` 之前调用；`SendMessageAsync` 依赖管道的请求-响应匹配，无管道时不可用。
4. **主动关闭阻止重连**：`client.Close("reason")` 设置 `_userClosed = true`，自动重连被拦截；`Dispose()` 也会停止重连计时器。
5. **`WebClientX` 原子写盘**：`DownloadFileAsync` 先写 `.tmp`，完成后重命名，中途失败不污染目标文件。

## 执行步骤

### 一、NetClient — 长连接事件驱动

```csharp
using NewLife.Net;
using NewLife.Log;

var client = new NetClient("tcp://127.0.0.1:8080")
{
    Log            = XTrace.Log,
    AutoReconnect  = true,
    ReconnectDelay = 5_000,  // 5 秒重连间隔
    MaxReconnect   = 0,      // 无限重连
    Timeout        = 3_000,
};

// 注册管道（粘包处理，必须在 Open 之前）
client.Add<StandardCodec>();

client.Opened   += (s, e) => XTrace.WriteLine("已连接");
client.Closed   += (s, e) => XTrace.WriteLine("已断开，等待重连");
client.Received += (s, e) =>
{
    var msg = e.Message ?? e.Packet?.ToStr();
    XTrace.WriteLine("收到：{0}", msg);
};
client.Error += (s, e) => XTrace.WriteLine("错误[{0}]：{1}", e.Action, e.Exception?.Message);

await client.OpenAsync();

// 发送并等待响应（需管道支持 RequestReply）
var reply = await client.SendMessageAsync(request);

// 主动关闭时阻止重连
client.Close("任务完成");
client.Dispose();
```

### 二、NetClient — 请求响应模式

```csharp
var client = new NetClient("tcp://127.0.0.1:8080");
client.Add<StandardCodec>();
await client.OpenAsync();

// 等待匹配响应，直到 Timeout
var resp = await client.SendMessageAsync(myRequest);
XTrace.WriteLine("响应：{0}", resp);
```

### 三、NetClient — UDP 单包模式

```csharp
var client = new NetClient("udp://127.0.0.1:9090");
// UDP 无连接，Open 成功后直接发送
client.Open();
client.Send("ping"u8);

using var pkt = await client.ReceiveAsync();
XTrace.WriteLine("收到：{0}", pkt?.ToStr());
client.Close("done");
```

### 四、属性速查

| 属性 | 默认值 | 说明 |
|------|--------|------|
| `Server` | `null` | 服务端地址（`tcp://host:port`） |
| `Timeout` | `3000` | 连接与读写超时（毫秒） |
| `AutoReconnect` | `true` | 意外断线后自动重连 |
| `ReconnectDelay` | `5000` | 重连等待间隔（毫秒） |
| `MaxReconnect` | `0` | 最大重连次数，`0` = 无限 |
| `Active` | —— | 当前是否已连接（只读） |
| `Items` | 懒加载 | 扩展数据字典（附加业务状态） |
| `Tracer` | `null` | APM 追踪器 |

### 五、WebClientX — HTTP 下载

```csharp
using NewLife.Web;

var wc = new WebClientX
{
    Timeout   = 60_000,
    UserAgent = "MyApp/1.0",
};

// 下载到磁盘（先 .tmp 后原子重命名）
await wc.DownloadFileAsync("https://cdn.example.com/data.zip", @"d:\downloads\data.zip");

// 下载文本（带编码自动识别）
var html = await wc.DownloadStringAsync("https://example.com/");

// 通用请求（GET/POST）
var json = await wc.SendAsync("https://api.example.com/status");
var resp = await wc.SendAsync("https://api.example.com/data", jsonBody, "POST");
```

### 六、WebClientX — 目录探测与最新版本下载

```csharp
var wc = new WebClientX { Timeout = 120_000 };

// 解析目录页所有 <a href> 链接
var links = wc.GetLinks("http://files.example.com/release/");

// 按通配符找最新版 → 下载到本地目录
var localFile = wc.DownloadLink(
    "http://files.example.com/release/",
    "MyApp*.zip",
    @"d:\downloads\");

// 下载并自动解压（zip / tar.gz / 7z）
wc.DownloadLinkAndExtract(
    "http://files.example.com/release/",
    "MyApp*.zip",
    @"d:\app\");
```

### 七、WebClientX — CDN 鉴权

```csharp
// 阿里云 CDN 鉴权 A 型：URL?auth_key=timestamp-rand-uid-md5hash
var wc = new WebClientX
{
    AuthKey = Environment.GetEnvironmentVariable("CDN_AUTH_KEY"),
};

await wc.DownloadFileAsync(
    "https://cdn.example.com/configs/appsettings.json",
    @"d:\app\appsettings.json");
```

### 八、WebClientX — 网页抓取（编码自动识别）

```csharp
var wc = new WebClientX();
// GetHtml 自动读取 Content-Type / <meta charset> 决定解码方式
var html = wc.GetHtml("https://legacy.example.com/gbk-page.html");

// GetLinksInDirectory 过滤父目录 ../ 链接，只返回子项
var files = wc.GetLinksInDirectory("http://mirror.example.com/release/");
```

## 重点检查项

- [ ] `Add<T>()` 是否在 `Open()` / `OpenAsync()` **之前**调用？（管道必须先于连接注册）
- [ ] `MaxReconnect` 是否设置了合理上限（`0` 为无限重连，后台服务通常 `0` 允许，客户端工具建议设限）？
- [ ] `Dispose()` 是否在不再使用时调用（防止重连定时器泄漏）？
- [ ] `SendMessageAsync` 是否依赖管道 `RequestReply` 匹配？无管道时该方法行为未定义。
- [ ] `WebClientX.DownloadFileAsync` 是否处理了异常（`.tmp` 文件会保留，需清理逻辑）？
- [ ] CDN `AuthKey` 是否通过环境变量注入而非硬编码？

## 输出要求

- **长连接**：`NetClient`（`NewLife.Net`）—— 透明重连、管道编解码、事件驱动接收。
- **HTTP 下载**：`WebClientX`（`NewLife.Web`）—— 原子写盘、CDN 鉴权、目录探测。
- **管道注册**：`client.Add<StandardCodec>()` 必须在 `Open()` 前调用。
- **主动关闭**：`Close()` 阻止重连；`Dispose()` 释放所有资源。

## 参考资料

- `NewLife.Core/Net/NetClient.cs`
- `NewLife.Core/Web/WebClientX.cs`
- 相关技能：`network-server-sessions`（服务端）、`http-client-loadbalancer`（多端点 HTTP 客户端）、`pipeline-handler-model`（管道编解码）
