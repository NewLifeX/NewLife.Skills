---
name: rocketmq-messaging
description: >
  使用 NewLife.RocketMQ 接入 Apache RocketMQ（4.x/5.x）进行消息生产与消费，
  涵盖 Producer/Consumer 生命周期、五种消息类型（普通/顺序/事务/延迟/批量）、
  Pop 消费模式（5.x）、四大云厂商适配（阿里/腾讯/华为/Apache ACL）、
  gRPC 代理、消息轨迹追踪，以及消费重试与死信队列。
  适用于电商订单、支付通知、IoT 数据接入等高可靠消息场景。
argument-hint: >
  说明你的消息场景：发送还是消费；消息类型（普通/顺序/事务/延迟/批量）；
  RocketMQ 版本（4.x 还是 5.x）；是否使用云服务（阿里/腾讯/华为）还是自建；
  是否需要 gRPC 代理（5.x 专用）；消费是集群模式还是广播模式。
---

# RocketMQ 消息收发技能（NewLife.RocketMQ）

## 适用场景

- 电商、支付场景中，需要通过消息队列解耦服务，保证消息可靠投递。
- 需要事务消息（二阶段提交）保证数据库操作与消息发送的原子性。
- IoT 设备数据接入，需要高吞吐、顺序消费。
- 迁移或部署在阿里云/腾讯云/华为云的 RocketMQ 实例，需要特定认证适配。
- 升级到 RocketMQ 5.x，需要使用 Pop 消费模式或 gRPC 代理。

## 核心原则

1. **Producer 和 Consumer 独立生命周期**：`Start()` 后才能收发；程序退出前必须 `Stop()` 优雅关闭，否则消费位点不会及时提交，重启后可能重复消费。
2. **消费回调返回 `false` 触发重试**：`OnConsume` 委托返回 `true` 表示消费成功；返回 `false` 或抛出异常时，消息会按 `MaxReconsumeTimes`（默认 16 次）重试，超次进死信队列（`%DLQ%{Group}`）。
3. **顺序消费必须锁定队列**：设置 `OrderConsume = true` 后，框架会调用 `LockBatchMQAsync` 在 Broker 端加锁，同一队列内消息串行消费；锁定失败的队列消息延后处理。
4. **事务消息两步发送**：先 `PublishTransaction`（半消息）执行本地事务，再通过 `OnCheckTransaction` 回查委托告知 Broker 提交还是回滚；Broker 1 分钟内发起回查，回查超 15 次视为回滚。
5. **云厂商适配通过 `CloudProvider` 插入认证逻辑**：不同云厂商签名算法不同（HMAC-SHA1/MD5/AK-SK），通过 `ICloudProvider` 接口注入，不改变业务代码。
6. **RocketMQ 5.x 使用 gRPC 需设置 `GrpcProxyAddress`**：5.x 支持 Remoting 和 gRPC 双协议，`GrpcProxyAddress` 优先，不设则使用 Remoting（兼容 4.x）。

## 执行步骤

### 一、发送普通消息

```csharp
using NewLife.RocketMQ;

var producer = new Producer
{
    Topic             = "order-topic",
    NameServerAddress = "127.0.0.1:9876",
    Group             = "order-producer-group",
};
producer.Start();

// 同步发送（带标签和业务键）
var result = producer.Publish(
    body: new { OrderId = 42, Amount = 100.0m },
    tags: "create",
    keys: "order-42"
);
Console.WriteLine($"MsgId: {result.MsgId}, Status: {result.SendStatus}");

// 异步发送
var asyncResult = await producer.PublishAsync(new Message
{
    Topic = "order-topic",
    Tags  = "pay",
    Body  = Encoding.UTF8.GetBytes(order.ToJson()),
});

// 单向发送（不等结果，适合日志/监控）
producer.PublishOneway(message, queue: null);

producer.Stop();
```

### 二、批量发送

```csharp
var messages = orders.Select(o => new Message
{
    Topic = "order-topic",
    Tags  = "batch",
    Body  = Encoding.UTF8.GetBytes(o.ToJson()),
}).ToList();

var result = producer.PublishBatch(messages);
```

### 三、延迟消息

```csharp
// RocketMQ 4.x：18 级预设延迟（1s/5s/10s/30s/1m/2m/3m/4m/5m/6m/7m/8m/9m/10m/20m/30m/1h/2h）
var msg = new Message
{
    Topic           = "order-topic",
    Body            = Encoding.UTF8.GetBytes(order.ToJson()),
    DelayTimeLevel  = 3,  // 第 3 级 = 10 秒后投递
};
producer.Publish(msg);

// RocketMQ 5.x：精确延迟时间（毫秒）
var msg5 = new Message
{
    Topic            = "order-topic",
    Body             = Encoding.UTF8.GetBytes(order.ToJson()),
    DeliveryTimestamp = DateTimeOffset.UtcNow.AddMinutes(5).ToUnixTimeMilliseconds(),
};
```

### 四、事务消息

```csharp
producer.OnCheckTransaction = (msg, transId) =>
{
    // 回查本地事务状态（查询数据库等）
    var state = CheckOrderInDb(transId);
    return state == OrderState.Success
        ? TransactionState.Commit
        : TransactionState.Rollback;
};
producer.Start();

// 发送事务消息
var result = producer.PublishTransaction(new Message
{
    Topic = "finance-topic",
    Body  = Encoding.UTF8.GetBytes(transfer.ToJson()),
});

// 执行本地事务（数据库落库）
using var tx = db.BeginTransaction();
db.InsertTransfer(transfer);
tx.Commit();

// 提交事务消息（告知 Broker 提交）
producer.ConfirmTransaction(result.TransactionId, TransactionState.Commit);
```

### 五、消费消息

```csharp
var consumer = new Consumer
{
    Topic             = "order-topic",
    Group             = "order-consumer-group",
    NameServerAddress = "127.0.0.1:9876",
    BatchSize         = 32,           // 每批拉取数量
    FromLastOffset    = false,        // false = 从头消费（首次）
    MaxReconsumeTimes = 16,           // 失败最大重试次数
};

// 同步消费回调（返回 false = 消费失败，触发重试）
consumer.OnConsume = (queue, messages) =>
{
    foreach (var msg in messages)
    {
        try
        {
            ProcessOrder(Encoding.UTF8.GetString(msg.Body));
        }
        catch
        {
            return false;  // 消费失败，重试
        }
    }
    return true;
};

consumer.Start();

// 异步消费回调
consumer.OnConsumeAsync = async (queue, messages, ct) =>
{
    await ProcessBatchAsync(messages, ct);
    return true;
};
```

### 六、顺序消费

```csharp
var consumer = new Consumer
{
    Topic         = "order-topic",
    Group         = "order-seq-group",
    NameServerAddress = "127.0.0.1:9876",
    OrderConsume  = true,  // 启用顺序消费
};
consumer.OnConsume = (queue, messages) => { /* 串行处理 */ return true; };
consumer.Start();
```

### 七、Pop 消费（RocketMQ 5.x）

```csharp
var consumer = new Consumer
{
    Topic             = "order-topic",
    Group             = "order-consumer-group",
    NameServerAddress = "127.0.0.1:9876",
    Version           = MQVersion.V5_2_0,  // 指定 5.x
};

// Pop 模式：消息不再归属某个 Broker 队列，消费后 Ack
consumer.OnConsumeAsync = async (queue, messages, ct) =>
{
    foreach (var msg in messages)
    {
        await ProcessAsync(msg);
        // PopConsume 模式下 Ack 由框架自动完成（ConsumerState.Success）
    }
    return true;
};
consumer.Start();
```

### 八、云厂商适配

```csharp
// 阿里云公共云 RocketMQ
var producer = new Producer
{
    Topic             = "topic-xxx",
    NameServerAddress = "http://xxx.mq.aliyuncs.com:80",
    CloudProvider     = new AliyunProvider
    {
        AccessKey  = "LTAI5t...",
        SecretKey  = "xxx",
        OnsChannel = "ALIYUN",
    },
};

// Apache ACL（自建集群）
var producer2 = new Producer
{
    Topic             = "topic-xxx",
    NameServerAddress = "127.0.0.1:9876",
    CloudProvider     = new AclProvider
    {
        AccessKey = "rocketmq_ak",
        SecretKey = "rocketmq_sk",
    },
};

// gRPC 代理（RocketMQ 5.x Proxy）
var producer3 = new Producer
{
    Topic            = "topic-xxx",
    GrpcProxyAddress = "http://localhost:8081",
    Group            = "test-group",
};
```

## 配置参数速查

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `NameServerAddress` | — | NameServer 地址（必填） |
| `Topic` | — | 主题名（必填） |
| `Group` | — | 生产/消费组 |
| `Version` | `V4_9_7` | 协议版本（V5_2_0 = 5.x） |
| `RequestTimeout` | `3000` | 请求超时（ms） |
| `RetryTimesWhenSendFailed` | `3` | 发送失败重试次数 |
| `MaxMessageSize` | `4MB` | 消息体最大限制 |
| `CompressOverBytes` | `4096` | 超过此大小自动 ZLIB 压缩 |
| `BatchSize` | `32` | Consumer 每批拉取数量 |
| `MaxReconsumeTimes` | `16` | 消费失败最大重试次数 |
| `FromLastOffset` | `false` | 首次消费起始位置 |
| `EnableMessageTrace` | `false` | 是否开启消息轨迹 |

## 常见错误与注意事项

- **`Stop()` 必须调用**：消费位点通过心跳维护，不调用 `Stop()` 会导致重复消费。
- **事务消息 Broker 回查最多 15 次**：超限视为回滚；回查委托内不要有耗时 I/O，应直接查库状态。
- **延迟级别从 1 开始（不是 0）**：`DelayTimeLevel=0` 表示不延迟，与 `1`（1 秒）不同。
- **顺序消费与多线程冲突**：`OrderConsume=true` 时框架串行处理同一队列，不要在 `OnConsume` 内再起并发任务。
- **批量消息超 4MB 会被拒绝**：发批量消息前检查总大小，建议每批 < 1MB。
- **5.x gRPC 代理需单独部署 Proxy 组件**：`GrpcProxyAddress` 指向 RocketMQ Proxy，而非 Broker 直连地址。
