---
name: pipeline-handler-model
description: >
  设计或使用 IPipeline/IPipelineHandler 管道处理器模型，将编解码、加密、压缩、日志等横切逻辑
  拆分为独立的双向链式处理器节点，在网络或消息场景中实现可组合的责任链。
  适用于网络协议栈设计、消息编解码、中间件链路构建与管道代码审查任务。
argument-hint: >
  说明你的管道使用场景：网络收发粘包处理还是消息编解码；
  是否需要加密/压缩处理器；是否需要为每个连接独立状态（有状态处理器）；
  是否基于 NetServer/NetClient 集成还是独立管道。
---

# 管道处理器模型技能

## 适用场景

- 设计网络协议栈，需要将粘包/拆包、加密/解密、序列化/反序列化拆分为独立节点。
- 多个业务协议共用相同的底层编解码层（如 LengthFieldCodec），只替换上层应用处理器。
- 需要在 `NetServer`/`NetClient` 中注入自定义处理器（日志、鉴权、限流）。
- 代码审查：检查处理器顺序是否合理、有状态处理器是否正确隔离、链路截断时资源是否释放。

## 核心原则

1. **进站正序、出站逆序**：`Read`（收包）从 `Head` 顺序传向 `Tail`；`Write`（发包）从 `Tail` 逆序传向 `Head`。生命周期事件：`Open`/`Error` 正向传播，`Close` 逆向传播。
2. **必须传递/截断选一**：每个处理器要么调用 `base.Read/Write` 继续传递，要么有意截断；截断时必须释放持有的 `IPacket` 或资源。
3. **有状态处理器必须按连接实例化**：持有解析缓冲区、加密状态等内部状态的处理器，不能跨连接共享——每次 `NewSession` 必须 `new` 新实例。
4. **顺序决定行为**：拆包器（`LengthFieldCodec`）必须在解码器（`StandardCodec`）前面；顺序错误会导致残包或无法识别的消息。
5. **上下文（`IHandlerContext`）贯穿整链**：携带会话、管道、Owner 等信息；在链路末端用 `context.FireRead(message)` 向业务层投递消息。

## 数据流方向

```
收包（Read，Head → Tail 正向）:
  Socket → Handler[0].Read → Handler[1].Read → … → Handler[n] → context.FireRead(msg) → 业务层

发包（Write，Tail → Head 逆向）:
  业务层.WriteAsync → Handler[n].Write → … → Handler[0].Write → Socket.Send(pk)

Open / Error（正向）    Close（逆向）
```

## 执行步骤

### 一、组装管道

```csharp
var pipeline = new Pipeline();
// 1. 拆包器（处理 TCP 粘包）
pipeline.Add(new LengthFieldCodec { Size = 4 });  // 4字节头部长度字段

// 2. 消息编解码器
pipeline.Add(new StandardCodec());

// 3. 可选：自定义横切处理器（日志、鉴权等）
pipeline.Add(new LogHandler());
```

### 二、实现自定义只读处理器

```csharp
// 适用场景：拦截读取的消息，做日志/统计后继续传递
public class LogHandler : Handler
{
    public override Object? Read(IHandlerContext context, Object message)
    {
        XTrace.WriteLine("收包: {0}", message);
        return base.Read(context, message);  // ← 必须继续传递
    }

    public override Object? Write(IHandlerContext context, Object message)
    {
        XTrace.WriteLine("发包: {0}", message);
        return base.Write(context, message);  // ← 必须继续传递
    }
}
```

### 三、实现有转换逻辑的处理器

```csharp
// 适用场景：加解密，输入/输出类型均为 IPacket
public class AesHandler : Handler
{
    private readonly Byte[] _key;
    public AesHandler(Byte[] key) => _key = key;

    public override Object? Read(IHandlerContext context, Object message)
    {
        if (message is not IPacket pk) return base.Read(context, message);
        var decrypted = AesDecrypt(pk.GetSpan(), _key);
        return base.Read(context, new ArrayPacket(decrypted));  // 传递解密后的包
    }

    public override Object? Write(IHandlerContext context, Object message)
    {
        if (message is not IPacket pk) return base.Write(context, message);
        var encrypted = AesEncrypt(pk.GetSpan(), _key);
        return base.Write(context, new ArrayPacket(encrypted));
    }
}
```

### 四、处理一进多出（粘包场景）

```csharp
// 当一个原始包包含多条业务消息时：
public override Object? Read(IHandlerContext context, Object message)
{
    // 解析出多条消息
    foreach (var msg in ParseMessages(message))
    {
        // 对每条消息独立传递给链路下游，并投递到业务层
        Next?.Read(context, msg);
    }
    return null;  // 返回 null 表示已处理多条，上层无需再处理
}
```

### 五、与 NetServer 集成

```csharp
var server = new NetServer { Port = 9000 };

server.NewSession += (sender, e) =>
{
    // 每条连接独立的管道实例
    var pipeline = e.Session.Host.Pipeline;
    pipeline.Add(new LengthFieldCodec { Size = 4 });   // 有状态，每连接新建
    pipeline.Add(new AesHandler(sharedKey));            // 无状态，可共享
    pipeline.Add(new MyProtocolCodec());
};

server.Start();
```

### 六、Open/Close/Error 生命周期

```csharp
public class AuthHandler : Handler
{
    public override Boolean Open(IHandlerContext context)
    {
        // 正向传播（先自己处理再传下去）
        // ... 初始化鉴权状态
        return base.Open(context);
    }

    public override Boolean Close(IHandlerContext context, String reason)
    {
        // 逆向传播（先传下去再自己处理）
        var result = base.Close(context, reason);
        // ... 清理鉴权状态
        return result;
    }
}
```

## 重点检查项

- [ ] 处理器添加顺序是否正确（拆包 → 解码 → 业务，而非颠倒）？
- [ ] 有状态处理器（持有缓冲区/状态）是否为每个连接创建独立实例？
- [ ] 截断链路前是否释放了持有的 `IPacket` 或托管资源（防内存泄漏）？
- [ ] `Read` 返回多消息时是否正确返回 `null` 并调用 `Next.Read` 多次？
- [ ] `Open`/`Close`/`Error` 中是否也调用了 `base.*` 以保证事件继续传播？

## 输出要求

- **接口**：`IPipeline`（管道）、`IPipelineHandler`（处理器节点）、`IHandlerContext`（上下文）。
- **基类**：`Handler` 提供默认 pass-through 实现；业务类继承后只覆写关心的方法。
- **内置处理器**：`LengthFieldCodec`（长度字段拆包）、`StandardCodec`（标准消息编解码）。
- **测试**：可脱离 `NetServer` 独立测试管道：手动 `new Pipeline()`，手动 `pipeline.Read(ctx, msg)` 验证输出。

## 参考资料

参考示例与模式证据见 `references/newlife-pipeline-patterns.md`。
