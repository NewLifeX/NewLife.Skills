---
name: network-server-sessions
description: >
  使用 NewLife.Net 构建高性能网络服务器，涵盖 NetServer/NetSession 生命周期管理、
  管道编解码配置、TCP/UDP 协议选择、SSL/TLS、会话数据存储、异步请求-响应，
  以及泛型强类型会话设计。适用于即时通讯、游戏服务器、IoT 数据采集、自定义协议服务等场景。
argument-hint: >
  说明你的网络服务场景：TCP 还是 UDP；是否需要自定义消息协议（粘包处理）；
  是否需要自定义会话类型（持有业务状态）；是否需要 SSL/TLS；
  是否需要异步请求-响应模式（SendMessageAsync）。
---

# 网络服务器与会话管理技能

## 适用场景

- 构建自定义 TCP/UDP 服务器，需要管理客户端连接生命周期（连接/断开/数据收发）。
- 需要为每个连接维护业务状态（登录信息、用户 ID、会话 Token 等）—— 自定义 `NetSession`。
- 需要做协议编解码（粘包处理、JSON 消息、二进制协议）—— 配置管道 `Pipeline`。
- 需要异步请求-响应模式（发送消息并等待特定响应）—— `SendMessageAsync`。
- 代码审查：检查会话是否及时释放、管道处理器顺序是否正确、会话数据存储是否线程安全。

## 核心原则

1. **每连接独立会话**：每个客户端连接由一个 `INetSession` 实例管理；有内部状态的处理器（如拆包缓冲区）必须为每个连接独立创建。
2. **管道负责编解码**：业务层接收到的 `e.Message` 是经过管道解码后的对象；发送时 `SendMessage` 经管道编码后才写入 Socket。
3. **事件 vs 继承**：简单服务用 `server.Received += ...`（事件）；复杂业务逻辑继承 `NetSession` 并覆写 `OnReceive/OnConnected/OnDisconnected`。
4. **泛型服务器提供强类型访问**：`NetServer<MySession>` + `NetSession<MyServer>` 使会话内通过 `Host.SomeProperty` 访问自定义服务器属性，无需强制转型。
5. **生命周期顺序**：`OnConnected → 数据收发循环 → OnDisconnected → Dispose`；覆写生命周期方法必须调用 `base.*`。

## 数据流

```
接收：Socket → ProcessEvent → OnPreReceive → Pipeline.Read → OnReceive/Received事件 → 业务层
发送：业务层.SendMessage → Pipeline.Write → OnSend → Socket发送
```

## 执行步骤

### 一、最简 Echo 服务器

```csharp
var server = new NetServer
{
    Name = "EchoServer",
    Port = 12345,
    Log = XTrace.Log,
};

server.Received += (sender, e) =>
{
    if (sender is INetSession session)
        session.Send(e.Packet);  // Echo 原样回复
};

server.Start();
// server.Stop("Shutdown");  // 停止时
```

### 二、自定义会话（推荐复杂业务）

```csharp
public class GameSession : NetSession<GameServer>
{
    public Int32 PlayerId { get; set; }
    public String? Nickname { get; set; }

    protected override void OnConnected()
    {
        base.OnConnected();
        WriteLog("玩家连接：{0}", Remote);
        Send("Welcome!");
    }

    protected override void OnDisconnected(String reason)
    {
        base.OnDisconnected(reason);
        WriteLog("玩家断开：{0} 原因：{1}", Remote, reason);
        // 清理玩家房间数据等
    }

    protected override void OnReceive(ReceivedEventArgs e)
    {
        base.OnReceive(e);
        var msg = e.Message as GameRequest;    // 经管道解码后的消息对象
        if (msg == null) return;

        // 访问服务器自定义属性（强类型，无强制转型）
        var db = Host.Database;
        ProcessCommand(msg, db);
    }
}

public class GameServer : NetServer<GameSession>
{
    public IDatabase Database { get; set; }  // 注入到所有会话

    protected override void OnStart()
    {
        base.OnStart();
        // 注册管道编解码器（按正向处理顺序）
        Add(new LengthFieldCodec { Size = 4 });
        Add(new MessageCodec<GameRequest>());
    }
}
```

### 三、配置服务器参数

```csharp
var server = new GameServer
{
    Port = 9000,
    ProtocolType = NetType.Tcp,              // 仅 TCP；Udp / Unknown（同时监听）
    AddressFamily = AddressFamily.Unspecified,  // 同时 IPv4 + IPv6
    SessionTimeout = 600,                    // 会话超时秒数（默认 1200）
    SslProtocol = SslProtocols.Tls12,       // 启用 TLS
    Certificate = cert,                      // X509 证书
    Tracer = DefaultTracer.Instance,         // APM 链路追踪
    ServiceProvider = serviceProvider,       // 注入 DI 容器
};
```

### 四、配置编解码器管道

```csharp
// 简单内置方案（4字节头部长度 + 标准消息）
server.Add<StandardCodec>();

// 或 JSON 编解码器
server.Add<JsonCodec>();

// 或自定义粘包处理链
server.Add(new LengthFieldCodec { Size = 2 });  // 2字节头部
server.Add(new MyProtocolCodec());              // 自定义消息解析
```

### 五、发送数据的多种方式

```csharp
// 在 NetSession 子类中
Send(bytes);                                // 字节数组（原始包）
Send("消息文本");                            // 字符串（UTF-8）
SendMessage(new GameResponse { Code = 0 }); // 经管道编码后发送（同步）
var resp = await SendMessageAsync(request); // 异步发送并等待关联响应
SendReply(response, receivedEventArgs);     // 回复当前请求（关联原请求上下文）
```

### 六、会话存储与管理

```csharp
// 会话内存储数据
this["userId"] = 12345;
var userId = (Int32)this["userId"];

// 获取全部会话
foreach (var kv in server.Sessions)
    Console.WriteLine($"[{kv.Key}] {kv.Value.Remote}");

// 获取指定 ID 的会话（强类型）
var session = server.GetSession(sessionId) as GameSession;
session?.Send("Server push message");

// 查看当前/历史峰值会话数
Console.WriteLine($"当前 {server.SessionCount} / 峰值 {server.MaxSessionCount}");
```

## 重点检查项

- [ ] 有状态的管道处理器（持有拆包缓冲区）是否在 `NewSession` 事件中每次 `new` 一个新实例？
- [ ] `OnConnected`/`OnDisconnected`/`OnReceive` 覆写是否都调用了 `base.*`？
- [ ] 会话超时（`SessionTimeout`）是否设置合理（避免僵尸连接占用资源）？
- [ ] `SendMessageAsync` 是否有超时（`CancellationToken`），避免无限等待？
- [ ] 服务器停止（`Stop`）时，是否等待所有活跃会话优雅退出，还是强制断链？
- [ ] SSL 证书是否在应用启动时加载并验证（而非每连接重新读文件）？

## 输出要求

- **接口**：`INetSession`（会话接口）、`INetHandler`（处理器接口）、`ISocketServer`（底层服务器）。
- **基类**：`NetServer`/`NetServer<TSession>`（服务器）、`NetSession`/`NetSession<TServer>`（会话）。
- **内置编解码器**：`LengthFieldCodec`（粘包拆包）、`StandardCodec`（默认消息格式）、`JsonCodec`（JSON 编解码）。
- **测试**：可在 loopback 地址启动服务，用 `NetUri.CreateRemote()` 创建测试客户端验证行为。

## 参考资料

参考示例与模式证据见 `references/newlife-netserver-patterns.md`。
