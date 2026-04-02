# NewLife.Core EventBus 模式证据

> 来源：`d:\X\NewLife.Core\Doc\事件总线EventBus.md` + `NewLife.Core\Messaging\IEventBus.cs`、`EventHub.cs`、`QueueEventBus.cs`
> 用途：为 `event-bus-messaging` SKILL.md 提供代码层面的证据，以及 NewLife.Core 特有 API 的适用边界说明。

---

## 1. 接口层次（源码校验）

```text
IEventBus                          // 非泛型，持有引用
  ↓
IEventBus<TEvent>                  // 发布 + 同步订阅/取消
  ↓ (可选)
IAsyncEventBus<TEvent>             // 异步订阅/取消

IEventHandler<TEvent>              // 处理器接口
IEventContext / EventContext       // 上下文接口 + 默认实现
IOwnerPacket（与 IEventContext 解耦，见 IPacket）
```

**通用可复用**：接口层次本身与 NewLife 命名空间无关，可直接照搬到其它库中。

---

## 2. `EventBus<TEvent>` 关键实现细节

### 订阅集合

```csharp
// 内部：ConcurrentDictionary<String, IEventHandler<TEvent>>
Subscribe(handler, clientId)  // 覆盖同 clientId
Unsubscribe(clientId)         // 移除
```

### 快照分发

```csharp
// 分发时枚举字典快照，不在迭代期间修改
foreach (var handler in _handlers.Values.ToArray())
    await handler.HandleAsync(e, context, ct);
```

### 异常策略双档

```csharp
// ThrowOnHandlerError = false（默认）：记录日志续发
// ThrowOnHandlerError = true：第一个异常立即抛出
```

### 对象池化上下文

```csharp
// 若调用方未传 context，系统从对象池获取
// 分发完毕调用 context.Reset() 并归还池
// 处理器内：禁止保存 context 到比本次分发更长的生命周期
```

### TraceId 自动写入

```csharp
// 若 event 实现 ITraceMessage 且 TraceId 为空，发布时写入当前活跃埋点 TraceId
if (e is ITraceMessage tm && tm.TraceId.IsNullOrEmpty())
    tm.TraceId = DefaultTracer.Current?.TraceId;
```

---

## 3. `EventHub<TEvent>` 关键实现细节

### 消息格式（仅处理此前缀）

```
event#<topic>#<clientId>#<message>
```

- `message` 为 JSON 字符串或控制指令 `subscribe`/`unsubscribe`。

### 主题总线懒创建

```csharp
GetEventBus(topic, clientId)
// GetOrAdd，Factory 为 null 时默认 new EventBus<TEvent>()
// 并发下可能多创建，最终仅缓存一份
```

### subscribe 指令的 Handler 传递方式（NewLife 特例）

```csharp
// context 需实现 IExtend，且 context["Handler"] = myHandler
var handler = (context as IExtend)?["Handler"] as IEventHandler<TEvent>;
bus.Subscribe(handler, clientId);
```

> **适用范围**：IExtend 是 NewLife.Core 特有接口，不应不经适配推广到其他框架。通用替代：直接传 `IEventHandler<TEvent>` 参数或用闭包。

### 主题总线清理（内存防泄漏）

```csharp
// Unsubscribe 后，若总线为 EventBus<TEvent> 且已无订阅者，
// 从 _eventBuses / _dispatchers 中移除该主题
```

### 上下文写入

```csharp
// 如果 context 是 EventContext：直接写 .Topic / .ClientId
// 否则若实现 IExtend：写 context["Topic"] / ["ClientId"]
// 网络消息原始字节：context["Raw"] = rawInput
```

---

## 4. `QueueEventBus<TEvent>` 关键实现细节

### 消费循环

```csharp
// 继承 EventBus<TEvent>
// PublishAsync → 写入外部 ICache 队列（如 Redis List），不直接分发
// 首次 Subscribe → 启动 Task.Factory.StartNew(LongRunning) 消费循环
// 消费循环调用 base.DispatchAsync(event, context)
```

### 生命周期

```csharp
Dispose()
// 取消内部 CancellationTokenSource
// await task（最多约 3 秒）
// 释放 CTS
// 注意：Dispose 后发布的消息仍进入队列，但本实例不再消费
```

### 创建方式

```csharp
var bus = new QueueEventBus<MyEvent>(cache, "topic-name");
```

---

## 5. 委托扩展（`EventBusExtensions`）

| 委托签名 | 说明 |
|---|---|
| `Action<TEvent>` | 同步无上下文 |
| `Action<TEvent, IEventContext>` | 同步带上下文 |
| `Func<TEvent, Task>` | 异步无取消令牌 |
| `Func<TEvent, IEventContext, CancellationToken, Task>` | 完整异步（可获取 `CancellationToken`） |

> 仅最后一种签名可直接拿到 `CancellationToken`，其他需要通过 `IEventContext.Items` 传递。

---

## 6. 线程安全与并发

- `EventBus<TEvent>` 和 `EventHub<TEvent>` 订阅集合均为 `ConcurrentDictionary`。
- `EventHub.GetEventBus` 并发下可能多次创建总线，但最终只缓存一个实例；被替换的额外实例需考虑资源释放。

---

## 7. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| 接口分层（泛型 + 非泛型） | ✅ 通用 | 任何事件系统均适用 |
| 幂等订阅（clientId） | ✅ 通用 | 可用字符串 key 或对象引用替代 |
| 快照分发 | ✅ 通用 | 任何并发订阅场景 |
| 两档异常策略 | ✅ 通用 | 生产推荐记录+续发，调试可选严格 |
| 对象池化 EventContext | ⚠️ 半通用 | 需要对象池基础设施（NewLife 内置） |
| `IExtend` 传 Handler | ❌ NewLife 专属 | 不应照搬；通用替代：参数传递 |
| `QueueEventBus` 消费循环 | ⚠️ 半通用 | 思路通用；队列实现依赖 `ICache` |
| TraceId 自动写入 | ⚠️ 半通用 | 依赖 `DefaultTracer`，可替换为 `Activity` |
