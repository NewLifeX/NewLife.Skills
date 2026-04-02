# Actor 并行模型模式

## 适用场景

需要在不使用锁的情况下实现线程安全的异步处理：日志收集器、消息处理器、批量写入、状态隔离的后台任务。每个 Actor 独占一个处理循环，外部只通过 `Tell` 发送消息，无需协调锁。

## 模式结构

```
IActor
  └─ Actor（基类）
       ├─ 内部消息队列（BlockingCollection / Channel）
       ├─ 独立处理线程（LongRunning Task）
       └─ ReceiveAsync（子类重写）
```

## 核心 API（NewLife.Model）

```csharp
// 1. 定义 Actor
public class LogActor : Actor
{
    public LogActor()
    {
        Name = "LogActor";
        BatchSize = 100;            // 批量消费
        BoundedCapacity = 10000;    // 限制队列防止内存溢出
    }

    // 批量处理（BatchSize > 1）
    protected override async Task ReceiveAsync(ActorContext[] contexts, CancellationToken ct)
    {
        foreach (var ctx in contexts)
            if (ctx.Message is String line)
                await _writer.WriteLineAsync(line);
        await _writer.FlushAsync();
    }

    // 单条处理（BatchSize == 1）
    protected override Task ReceiveAsync(ActorContext context, CancellationToken ct)
    {
        // 处理 context.Message
        return Task.CompletedTask;
    }
}

// 2. 使用 Actor
var actor = new LogActor();

actor.Tell("第一条日志");               // 自动启动，入队
actor.Tell(new {Id = 1, Data = "x"});  // 可发送任意类型

var done = actor.Stop(5000);            // 等待最多5秒处理完毕
```

## 关键属性

| 属性 | 默认值 | 说明 |
|------|-------|------|
| `Name` | 类名 | Actor 标识，用于追踪 |
| `BatchSize` | 1 | 每次处理消息数；>1 时调用批量重载 |
| `BoundedCapacity` | Int32.MaxValue | 队列最大容量；溢出时 `Tell` 阻塞 |
| `LongRunning` | true | 使用独立线程而非线程池 |
| `Tracer` | null | 集成 `ITracer` 链路追踪 |

## 停止语义

```csharp
actor.Stop(0);      // 立即停止，不等待队列清空
actor.Stop(-1);     // 无限等待，直到队列为空
actor.Stop(5000);   // 最多等 5 秒，超时返回 false
```

## 选型对比

| 对比点 | Actor | Channel / BlockingCollection | lock |
|--------|-------|------------------------------|------|
| 线程安全 | 天然隔离 | 需手动管理 | 显式加锁 |
| 批量处理 | 内置 BatchSize | 手动 | 手动 |
| 背压控制 | BoundedCapacity | 需配置 | 无 |
| 适用规模 | 单消费者场景 | 多消费者场景 | 低竞争小对象 |

## 注意事项

- `Tell` 不阻塞（队列未满时），适合高频入队场景
- `ReceiveAsync` 内部异常不会吞掉：Actor 会记录并继续处理下一条
- 不要在 `ReceiveAsync` 中调用 `actor.Tell()`（自投可能死锁）
- 继承 `DisposeBase` 时需在 `Dispose(bool)` 中调用 `actor.Stop(-1)`

## 来源

- `D:\X\NewLife.Core\Doc\并行模型Actor.md`
- `D:\X\NewLife.Core\NewLife.Core\Model\Actor.cs`（命名空间 `NewLife.Model`）
