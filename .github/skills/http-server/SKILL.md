---
name: http-server
description: >
  使用 NewLife.Http.HttpServer 构建轻量级 HTTP 服务端，涵盖路由注册（Map/MapController/MapStaticFiles）、
  委托处理器（Lambda 直接映射为路由）、控制器处理器（ControllerHandler）、静态文件服务，
  以及基于 NewLife.Net 的 WebSocket 服务端与客户端（WebSocketClient/WebSocketSession）。
  适用于内嵌式 HTTP API、物联网设备管理界面、WebSocket 实时推送等场景。
argument-hint: >
  说明你的 HTTP 服务场景：简单 REST API（用 Lambda Map 或 Controller）；
  静态文件服务；WebSocket 双向推送；还是需要 HTTPS（TLS）。
  说明是服务端还是客户端，以及是否需要自定义请求头/认证。
---

# HTTP 服务端与 WebSocket 技能

## 适用场景

- 在应用内嵌入轻量级 HTTP API（健康检查、管理接口、Webhook 接收），无需引入 ASP.NET Core。
- 物联网设备管理界面：提供静态文件 + REST API，`HttpServer` 开箱即用。
- WebSocket 实时消息推送或设备双向通信 —— `WebSocketSession`（服务端）/ `WebSocketClient`（客户端）。
- 代码审查：确认路由注册在启动阶段完成（运行期并发修改 Routes 字典不线程安全）。

## 核心原则

1. **HttpServer 继承 NetServer**：所有 TCP 层能力（会话管理、管道编解码、APM、日志）均复用 NetServer，`HttpServer` 只负责路由注册与 HTTP 协议处理。
2. **路由按注册顺序匹配**：精确匹配优先于通配符（含 `*` 的路由 key），通配符路由用 `IsMatch` 模糊匹配。
3. **路由注册非线程安全**：`Routes` 是普通 `Dictionary`，仅支持启动阶段批量注册，运行期不要动态增删路由。
4. **控制器路由约定**：`MapController<T>("/api")` 注册为 `/api/*`，控制器方法名即路由后缀；方法参数从 QueryString / Body 自动绑定。
5. **WebSocket 复用 NetServer 管道**：`WebSocketCodec` 作为管道处理器，处理握手和帧编解码；`WebSocketClient` 继承 `TcpSession`，自动发送 Ping 心跳（默认 120 秒）。

## 执行步骤

### 一、最简 HTTP 服务（Lambda 路由）

```csharp
using NewLife.Http;
using NewLife.Log;

var server = new HttpServer
{
    Port = 8080,
    Log  = XTrace.Log,
};

// 无参返回
server.Map("/health", () => "OK");

// 带参数（从 QueryString 自动绑定）
server.Map("/greet", (string name) => $"Hello, {name}!");

// 多参
server.Map("/add", (int a, int b) => a + b);

// 原始 HttpProcessDelegate（获取完整 HttpContext）
server.Map("/raw", (HttpRequest req, HttpResponse res) =>
{
    res.SetHeader("Content-Type", "text/plain");
    res.WriteBody("Raw response");
});

server.Start();
// server.Stop("shutdown");
```

### 二、控制器路由

```csharp
// 定义控制器（方法名即路由，参数自动绑定）
public class UserController
{
    // GET /api/list?page=1
    public List<User> List(int page = 1, int pageSize = 20)
        => UserService.GetPage(page, pageSize);

    // POST /api/create（Body JSON 自动反序列化为 User）
    public User Create(User user)
    {
        UserService.Insert(user);
        return user;
    }

    // GET /api/get?id=1
    public User Get(int id) => UserService.FindById(id);
}

// 注册控制器（路由前缀 /api/*）
server.MapController<UserController>("/api");
```

### 三、静态文件服务

```csharp
// 将 ./wwwroot 目录挂载到 /static 路径
server.MapStaticFiles("/static", "./wwwroot");

// 组合：API + 静态文件
server.Map("/health", () => "OK");
server.MapController<ApiController>("/api");
server.MapStaticFiles("/", "./wwwroot");          // 根路径兜底静态文件
```

### 四、自定义 IHttpHandler

```csharp
public class MyHandler : IHttpHandler
{
    public void ProcessRequest(IHttpContext context)
    {
        var req = context.Request;
        var res = context.Response;

        // 读取请求
        var method = req.Method;           // GET/POST/...
        var path = req.Path;
        var body = req.BodyStream;

        // 写入响应
        res.StatusCode = 200;
        res.SetHeader("Content-Type", "application/json");
        res.WriteBody("{\"code\":0}");
    }
}

server.Map("/custom", new MyHandler());
```

### 五、WebSocket 服务端

```csharp
using NewLife.Http;
using NewLife.Net;

// HttpServer 内置对 Upgrade: websocket 的支持
// 只需注册路径，会话类继承 WebSocketSession
public class ChatSession : WebSocketSession
{
    protected override void OnTextMessage(String text)
    {
        // 收到文本消息
        XTrace.WriteLine("收到：{0}", text);

        // 广播给所有连接
        Server.SendAllMessage(text);
    }

    protected override void OnConnected()
    {
        base.OnConnected();
        SendText("Welcome!");
    }
}

var httpServer = new HttpServer { Port = 8080 };
httpServer.Map("/ws", new WebSocketSessionHandler<ChatSession>());
httpServer.Start();
```

### 六、WebSocket 客户端

```csharp
using NewLife.Net;

var client = new WebSocketClient("ws://127.0.0.1:8080/ws");
client.KeepAlive = TimeSpan.FromSeconds(30);   // 心跳间隔

// 设置自定义请求头（认证）
client.SetRequestHeader("Authorization", "Bearer " + token);

// 收消息
client.Received += (sender, e) =>
{
    if (e.Message is WebSocketMessage msg)
    {
        switch (msg.Type)
        {
            case WebSocketMessageType.Text:
                Console.WriteLine(msg.Payload?.ToStr());
                break;
            case WebSocketMessageType.Binary:
                ProcessBinary(msg.Payload);
                break;
        }
    }
};

await client.OpenAsync();

// 发送
await client.SendTextAsync("Hello!");
await client.SendBinaryAsync(binaryPacket);

// 关闭
client.Dispose();
```

### 七、HTTPS / TLS

```csharp
// HttpServer 继承 NetServer，TLS 配置方式相同
server.SslProtocol = SslProtocols.Tls12;
server.Certificate = new X509Certificate2("server.pfx", "password");
// Port 建议改为 443
```

## 重点检查项

- [ ] 路由是否在 `server.Start()` 之前完成注册（Routes 字典非线程安全，运行期修改有并发风险）？
- [ ] `MapController` 的控制器方法是否为 `public`（非 public 方法不会被路由注册）？
- [ ] 委托路由的参数类型与 QueryString 字段名是否匹配（大小写不敏感，但参数名需对应）？
- [ ] WebSocket `WebSocketCodec.UserPacket = false` 时，`e.Message` 是 `WebSocketMessage` 而非原始字节—— Handler 里的类型断言是否正确？
- [ ] `WebSocketClient.KeepAlive` 是否与服务端超时配置互相兼容（客户端 Ping 频率 < 服务端 SessionTimeout）？
- [ ] 静态文件是否使用了 `MapStaticFiles` 而非手动读取文件（后者绕过了路径遍历防护）？

## 输出要求

- **HTTP 服务端**：`HttpServer`（`NewLife.Http`）—— 继承 `NetServer`；`Map`/`MapController`/`MapStaticFiles` 三种路由注册方式。
- **处理器接口**：`IHttpHandler`（自定义）、`DelegateHandler`（Lambda）、`ControllerHandler`（控制器）。
- **WebSocket 服务端**：`WebSocketSession`（继承 `NetSession`）；在 HttpServer 上注册路径。
- **WebSocket 客户端**：`WebSocketClient`（继承 `TcpSession`，`NewLife.Net`）；`SendTextAsync`/`SendBinaryAsync`；自动 Ping 心跳。
- **消息模型**：`WebSocketMessage`（`NewLife.Http`）—— `Type`/`Payload`/`CloseStatus`。

## 参考资料

参考示例与模式证据见 `references/newlife-httpserver-patterns.md`。
