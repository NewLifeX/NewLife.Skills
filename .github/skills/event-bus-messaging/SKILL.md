---
name: event-bus-messaging
description: >
  设计进程内发布/订阅事件总线、按主题路由的事件枢纽，以及基于队列的跨进程投递总线。
  适用于需要解耦生产者与消费者、处理链路追踪上下文传递、或实现类 MQ 场景的设计与代码审查任务。
argument-hint: >
  描述你的事件总线需求：进程内 / 按主题路由 / 队列驱动；
  说明订阅者类型（接口/委托）、是否需要上下文传递、对异常策略的要求。
---

# 事件总线设计技能

## 适用场景

- 在单一进程内实现低延迟"发布 → 多订阅者"广播，需要与业务逻辑解耦。
- 收到带主题的网络消息，需要路由到各自的局部事件总线或回调处理器。
- 生产者与消费者速率不匹配，需要借助外部缓存队列（如 Redis List）做削峰/持久化后再分发。
- 需要透传链路追踪 ID（TraceId）或自定义上下文数据跨越消费者边界。

## 核心原则

1. **接口分层**：非泛型 `IEventBus` 用于中间层统一持有；泛型 `IEventBus<TEvent>` 用于强类型发布/订阅；`IAsyncEventBus<TEvent>` 用于订阅本身需要异步初始化（如远程注册）的场景。
2. **幂等订阅**：相同 `clientId` 重复订阅覆盖旧注册，而不是叠加；明确约定取消订阅方式，防止处理器泄漏。
3. **快照分发**：分发时对订阅集合做快照，避免分发过程中的并发修改引发枚举错误；分发期间新增/移除的订阅者在本轮不可见。
4. **最佳努力与严格模式两档**：默认单处理器异常记录日志并续发，需要强一致时才切换为遇错立即抛出并中断；选择应在总线构造时确定，而非分散到处理器中。
5. **上下文对象池化**：自动创建的上下文来自对象池，分发结束后会被重置并归还；处理器内不得将上下文引用保存到字段、闭包或异步流中，需要保存时应提前复制所需字段。
6. **排除发送方**：在枢纽/回环场景中，可以通过 `clientId` 让分发器跳过"自己发布的消息返回给自己"的情况，避免死循环或重复处理。

## 执行步骤

### 一、确定总线类型

| 需求 | 推荐类型 |
|------|----------|
| 同进程广播，无持久化 | `EventBus<TEvent>` |
| 按网络主题路由到局部总线 | `EventHub<TEvent>` |
| 生产者 / 消费者速率解耦 | `QueueEventBus<TEvent>`（需外部缓存） |

### 二、定义接口契约

1. 判断事件类型是否需要序列化（队列场景强制需要）；选择轻量 DTO（`record` 或简单 `class`）。
2. 明确 `IEventHandler<TEvent>` 实现：是否需要 `CancellationToken`；至少提供一种委托包装路径减少样板代码。
3. 确认是否需要 `IAsyncEventBus<TEvent>` 的 `SubscribeAsync`（如订阅需要远程握手）。

### 三、实现并发安全

- 订阅集合使用 `ConcurrentDictionary<String, IEventHandler<TEvent>>`（`clientId` 为键）。
- 分发前将字典值通过 `.Values.ToArray()` 或 `GetEnumerator()` 做快照，**不**在迭代器持有期间修改字典。
- `EventHub<TEvent>` 的主题总线表和分发器表均使用并发字典，`GetOrAdd` 时可能多次创建，最终只保留一份；被替换的实例需要处理资源释放（如 `QueueEventBus<TEvent>`）。

### 四、上下文设计

1. 定义 `IEventContext`：至少包含 `Topic`（多主题）、`ClientId`（排除发送方）、可扩展的 `Items` 字典。
2. 若需要透传 TraceId，在发布入口检测 `ITraceMessage.TraceId` 是否为空，空则自动写入当前活跃埋点的 TraceId。
3. 在 `EventHub<TEvent>` 的 `HandleAsync` 中，将原始网络报文保存到 `context["Raw"]`，便于订阅者零拷贝转发或故障诊断。

### 五、队列型总线的消费循环

1. 消费任务以 `TaskCreationOptions.LongRunning` 创建，不占用 `ThreadPool` 线程池。
2. 通过内部 `CancellationTokenSource` 控制循环；`Dispose()` 时取消并等待任务退出（建议设上限，如 3 秒）。
3. 释放后发布的消息仍会写入外部队列，但本实例不再消费，需在文档或接口注释中明确说明。

### 六、委托订阅扩展

提供 `Subscribe(Action<TEvent>)`、`Subscribe(Func<TEvent, Task>)` 等扩展方法，内部统一包装为 `IEventHandler<TEvent>` 实现；确保包装类型的 `ToString()` 或 `clientId` 可识别，便于调试和取消订阅。

## 重点检查项

- [ ] 订阅集合是否并发安全，分发路径是否基于快照？
- [ ] 是否存在处理器泄漏（订阅未取消、`clientId` 不一致导致无法覆盖）？
- [ ] 自动创建的上下文是否来自对象池？处理器是否保存了池化上下文引用？
- [ ] 严格模式（`ThrowOnHandlerError`）的设置是在构造时确定，而不是运行时随意切换？
- [ ] `QueueEventBus` 释放后，外部队列中未消费的消息如何处理（是否有文档说明）？
- [ ] `EventHub` 中，当某主题已无订阅者时，是否主动清理主题总线（避免内存增长）？

## 输出要求

- **接口文件**：`IEventBus.cs`（包含非泛型接口和泛型接口）、`IEventHandler.cs`、`IEventContext.cs`。
- **实现文件**：`EventBus<TEvent>.cs`（进程内分发）、`EventHub<TEvent>.cs`（主题路由）；队列型独立文件。
- **扩展方法**：`EventBusExtensions.cs`，集中所有委托包装和便捷订阅方法。
- **单元测试**：覆盖幂等订阅、快照分发、处理器异常策略（两档）、上下文传递、队列消费并停止。
- **文档**：说明三种总线的选型建议、上下文对象池注意事项、`QueueEventBus` 的生命周期。

## 参考资料

参考示例与模式证据见 `references/newlife-eventbus-patterns.md`。
