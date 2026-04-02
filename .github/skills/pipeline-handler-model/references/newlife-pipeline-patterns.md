# NewLife.Core 管道模型模式证据

> 来源：`Doc/管道模型Pipeline.md`（UTF-8，编码正常）+ `Model/IPipeline.cs` + `Model/IHandler.cs`

---

## 1. 接口层次（源码校验）

```text
IPipeline
├── Add(IPipelineHandler)
├── Remove(IPipelineHandler) → Boolean
├── Clear()
├── Read(context, message) → Object?   （正向 Head→Tail）
├── Write(context, message) → Object?  （逆向 Tail→Head）
├── Open(context) → Boolean            （正向）
├── Close(context, reason) → Boolean   （逆向）
└── Error(context, exception) → Boolean（正向）

Pipeline : IPipeline
├── Handlers: IList<IPipelineHandler>
├── Head: IPipelineHandler?
└── Tail: IPipelineHandler?

IPipelineHandler
├── Prev: IPipelineHandler?  （逆向下一跳）
├── Next: IPipelineHandler?  （正向下一跳）
├── Read / Write / Open / Close / Error

Handler : IPipelineHandler（抽象基类）
├── 默认实现：Read → Next?.Read(...) 或 context.FireRead(message)
├── 默认实现：Write → Prev?.Write(...)
└── 子类覆写任一方法即可
```

> `IHandler` 已被 `[Obsolete]` 废弃，迁移到 `IPipelineHandler`。

---

## 2. 源码关键注释（直接引用）

`IPipelineHandler.Read` 注释：
> *"处理得到单个消息时，调用一次下一级处理器，返回下级结果给上一级；处理得到多个消息时，调用多次下一级处理器，返回null给上一级。"*

---

## 3. 数据流方向（来自 Doc）

```
收包（Read，正向 Head → Tail）:
  Socket → Handler[0].Read → Handler[1].Read → ... → context.FireRead → 业务层

发包（Write，逆向 Tail → Head）:
  业务层 → Handler[n].Write → ... → Handler[0].Write → Socket

生命周期：
  Open, Error  → 正向（Head → Tail）
  Close        → 逆向（Tail → Head）
```

---

## 4. 内置处理器速查（来自 Doc）

| 处理器 | 功能 |
|--------|------|
| `LengthFieldCodec` | 基于帧长度字段的粘包拆包（Size=2/4字节）|
| `StandardCodec` | 标准消息编解码（序列化/反序列化）|
| `MessageCodec<T>` | 泛型消息编解码，对应具体消息类型 T |

---

## 5. NetServer 集成模式（来自 Doc）

```csharp
server.NewSession += (sender, e) =>
{
    var pipeline = e.Session.Host.Pipeline;
    pipeline.Add(new LengthFieldCodec { Size = 4 });   // 有状态 → new 实例
    pipeline.Add(new StandardCodec());                  // 无状态 → 可共享
    pipeline.Add(new LogHandler());                     // 无状态 → 可共享
};
```

---

## 6. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| 责任链/管道模式 | ✅ 通用 | 与 ASP.NET Core Middleware 管道思路一致 |
| 双向流（Read/Write）| ✅ 通用 | 网络编解码场景的标准模式 |
| 进站顺序/出站逆序 | ✅ 通用 | 同 Netty ChannelPipeline 设计 |
| `IHandlerContext.FireRead` | ⚠️ NewLife 特有 | 通用替代：直接回调业务委托 |
| `LengthFieldCodec` 具体实现 | ⚠️ NewLife 特有 | 概念通用（帧长度拆包），API 特有 |
| `IHandler` 已废弃 | ⚠️ NewLife 特有 | 使用 `IPipelineHandler` 替代 |
