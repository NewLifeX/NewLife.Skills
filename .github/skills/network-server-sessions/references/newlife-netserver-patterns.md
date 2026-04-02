# NewLife.Core 网络服务器模式证据

> 来源：`Doc/网络服务端NetServer.md`（UTF-8，编码正常，全文读取）

---

## 1. 架构层次（来自文档）

```text
NetServer / NetServer<TSession>
├── ISocketServer[] Servers          → TcpServer / UdpServer
├── IDictionary<Int32, INetSession> Sessions
└── IPipeline Pipeline               → 共享管道（所有连接）

INetSession (每客户端连接一个实例)
├── ISocketSession Session            → 底层 Socket 会话
├── NetServer Host                    → 所属服务器（泛型为强类型 TServer）
└── INetHandler Handler               → 可选的数据预处理器
```

---

## 2. 服务器生命周期（来自文档）

```
[客户端连接] → [创建 ISocketSession] → [Server_NewSession]
                                             ↓
                      [OnNewSession] → [CreateSession] → [AddSession]
                                             ↓
                               [NetSession.Start()] → [OnConnected]
                                             ↓
                                     [数据收发循环]
                                             ↓
  [客户端断开/超时] → [Close(reason)] → [OnDisconnected] → [Dispose]
```

---

## 3. 关键配置属性（来自文档，完整列表）

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `Port` | Int32 | 0（随机）| 监听端口 |
| `ProtocolType` | NetType | Unknown | Tcp/Udp/Unknown（双监听）/Http |
| `AddressFamily` | AddressFamily | Unspecified | IPv4/IPv6/Unspecified（双栈）|
| `SessionTimeout` | Int32 | 1200 | 会话超时秒数 |
| `UseSession` | Boolean | true | 是否维护会话集合 |
| `SslProtocol` | SslProtocols | None | SSL/TLS 加密版本 |
| `StatPeriod` | Int32 | 600 | 统计周期（秒），0=禁用 |
| `ReuseAddress` | Boolean | false | SO_REUSEADDR |
| `Tracer` | ITracer? | null | APM 追踪器 |
| `ServiceProvider` | IServiceProvider? | null | 依赖注入容器 |

---

## 4. 发送 API 速查（来自文档）

```csharp
session.Send(Byte[]);            // 原始字节
session.Send(String, Encoding);  // 字符串（默认UTF-8）
session.Send(IPacket);           // 数据包（零拷贝）
session.Send(Stream);            // 流
session.Send(ReadOnlySpan<Byte>);// Span（高性能）

// 经过管道编码
session.SendMessage(obj);        // 同步，经编解码器
await session.SendMessageAsync(req);            // 异步请求并等待响应
await session.SendMessageAsync(req, cts.Token); // 带取消令牌
session.SendReply(resp, eventArgs);             // 回复请求报文
```

---

## 5. 自定义处理器（管道）模式（来自文档）

```csharp
// 旧版文档中 Handler.Read 返回 Boolean（文档版本与 IHandler.cs 源码 Object? 不一致）
// 以 IPipelineHandler 源码为准：Read/Write 返回 Object?
public class MyHandler : Handler
{
    public override Object? Read(IHandlerContext context, Object message) ...
    public override Object? Write(IHandlerContext context, Object message) ...
}

server.Add(new MyHandler());
```

---

## 6. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| 每连接独立会话对象 | ✅ 通用 | 任何网络框架均如此 |
| 管道处理协议编解码 | ✅ 通用 | 同 Netty ChannelPipeline |
| 泛型服务器 + 泛型会话 | ✅ 通用 | 减少类型转换，通用设计 |
| `NetType.Unknown` 双监听 | ⚠️ NewLife 特有 | 同时绑定 TCP+UDP |
| `WriteLog` 会话日志方法 | ⚠️ NewLife 特有 | 组件级日志快捷方法 |
| `INetHandler` + `CreateHandler` | ⚠️ NewLife 特有 | 会话级别预处理器注入 |
