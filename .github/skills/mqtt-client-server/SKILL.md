---
name: mqtt-client-server
description: >
  使用 NewLife.MQTT 构建 MQTT 客户端（MqttClient）和内嵌 Broker（MqttServer），
  涵盖连接管理、发布/订阅、QoS 0/1/2、遗嘱消息、保留消息、断线自动重连重订阅，
  支持 MQTT 3.1/3.1.1/5.0 协议，以及集群/桥接/规则引擎/WebHook/ACL 企业功能。
  适用于 IoT 设备接入、实时消息推送、设备影子同步等场景。
argument-hint: >
  说明你的 MQTT 场景：客户端连接发布订阅还是搭建 Broker；
  协议版本（3.1.1 还是 5.0）；QoS 等级需求；是否需要 TLS/SSL；
  是否需要遗嘱消息、保留消息；Broker 是否需要认证/集群/规则引擎。
---

# MQTT 客户端与服务端技能（NewLife.MQTT）

## 适用场景

- IoT 设备（传感器、网关、工业设备）通过 MQTT 上报数据、接收指令。
- 需要内嵌轻量级 Broker，不依赖第三方 MQTT 服务（如 Mosquitto/EMQ）。
- 设备异常断线需要自动重连并恢复全部订阅关系。
- 需要企业级功能：ACL 权限控制、消息桥接（跨集群转发）、规则引擎（消息路由/处理）。
- 代码审查：确认 QoS 使用正确、遗嘱消息配置规范、断线重连策略合理。

## 核心原则

1. **`MqttClient` 自动重连重订阅**：设置 `Reconnect = true`（默认）后，连接断开时框架自动按指数退避重连，并恢复 `SubscribeAsync` 注册的全部订阅关系，业务层无需手动实现断线恢复。
2. **QoS 级别按需选择**：`AtMostOnce(0)` 高吞吐/可接受丢消息（传感器遥测）；`AtLeastOnce(1)` 可靠投递适合指令下发；`ExactlyOnce(2)` 四次握手开销大，仅用于支付/告警等幂等性场景。
3. **遗嘱消息在 `Connect` 前配置**：`WillTopic`/`WillMessage`/`WillQoS` 属性必须在 `ConnectAsync()` 调用前设置，连接后无法更改。
4. **保留消息用于状态同步**：发布时设置 `Retain = true`，Broker 保留该主题最后一条消息，新订阅者连接后立即收到最新状态，无需等待下一次发布。
5. **服务端必须注入 `IMqttExchange`**：`MqttExchange` 是消息路由中枢，负责发布/订阅匹配、保留消息存储、QoS 消息持久化；不注入则服务端只能接收消息但无法路由分发。
6. **通配符订阅 `+` 和 `#` 区别**：`+` 匹配单层（`sensor/+/temperature` 匹配 `sensor/device1/temperature`），`#` 匹配多层（`sensor/#` 匹配 `sensor/device1/data/raw`）；`#` 只能出现在末尾。
7. **遗嘱消息 vs 正常断开**：正常 `DisconnectAsync()` 不触发遗嘱；异常断线（网络超时、进程崩溃）才触发遗嘱消息发布。

## 执行步骤

### 一、客户端连接与发布订阅

```csharp
using NewLife.MQTT;
using NewLife.MQTT.Messaging;

// 创建客户端
var client = new MqttClient
{
    Server    = "tcp://127.0.0.1:1883",
    ClientId  = Guid.NewGuid().ToString(),
    UserName  = "admin",
    Password  = "admin",
    KeepAlive = 60,          // 心跳间隔（秒）
    Reconnect = true,        // 自动重连（默认 true）
    Version   = MqttVersion.V311,
    Log       = XTrace.Log,
};

// 连接
await client.ConnectAsync();

// 订阅主题（通配符 + 回调）
await client.SubscribeAsync("sensor/+/temperature", msg =>
{
    var payload = msg.Payload.ToStr();
    Console.WriteLine($"主题: {msg.Topic}, 数据: {payload}");
});

// 发布消息（QoS 1）
await client.PublishAsync("sensor/device1/temperature", "25.6",
    QualityOfService.AtLeastOnce);

// 发布保留消息（新订阅者立即可见最新状态）
await client.PublishAsync(new PublishMessage
{
    Topic   = "device/online-status",
    Payload = Encoding.UTF8.GetBytes("online"),
    QoS     = QualityOfService.AtLeastOnce,
    Retain  = true,
});
```

### 二、连接字符串配置

```csharp
// 等价于上面的属性配置
client.Init("Server=tcp://127.0.0.1:1883;UserName=admin;Password=admin;ClientId=client01");
await client.ConnectAsync();
```

### 三、遗嘱消息配置

```csharp
// 遗嘱消息：设备异常掉线时 Broker 自动发布
var client = new MqttClient
{
    Server      = "tcp://127.0.0.1:1883",
    ClientId    = "device-001",
    WillTopic   = "device/device-001/status",
    WillMessage = Encoding.UTF8.GetBytes("offline"),
    WillQoS     = QualityOfService.AtLeastOnce,
    WillRetain  = true,    // 遗嘱消息也作为保留消息存储
};
await client.ConnectAsync();
```

### 四、MQTT 5.0 特性

```csharp
var client = new MqttClient
{
    Server  = "tcp://127.0.0.1:1883",
    Version = MqttVersion.V500,  // 启用 MQTT 5.0
};
await client.ConnectAsync();

// 共享订阅（负载均衡，多个消费者）
await client.SubscribeAsync("$share/group1/sensor/#", msg =>
{
    Console.WriteLine($"[5.0 共享订阅] {msg.Topic}: {msg.Payload.ToStr()}");
});
```

### 五、TLS/SSL 安全连接

```csharp
var client = new MqttClient
{
    Server      = "ssl://broker.example.com:8883",
    SslProtocol = System.Security.Authentication.SslProtocols.Tls12,
    Certificate = new X509Certificate2("client.pfx", "password"),
};
await client.ConnectAsync();
```

### 六、搭建内嵌 Broker（MqttServer）

```csharp
using NewLife.MQTT;
using NewLife.MQTT.Handlers;
using NewLife.Remoting;

// IoC 容器注册
var services = ObjectContainer.Current;
services.AddSingleton<ILog>(XTrace.Log);
services.AddTransient<IMqttHandler, MqttHandler>();   // 协议处理器
services.AddSingleton<IMqttExchange, MqttExchange>(); // 消息路由（必须）

// 创建并启动 Broker
var server = new MqttServer
{
    Port             = 1883,
    ServiceProvider  = services.BuildServiceProvider(),
    Log              = XTrace.Log,
};
server.Start();
```

### 七、自定义认证与 ACL

```csharp
public class MyAuthenticator : IMqttAuthenticator
{
    public Boolean Authenticate(ConnectMessage message, out String? reason)
    {
        var valid = CheckCredentials(message.Username, message.Password);
        reason = valid ? null : "用户名或密码错误";
        return valid;
    }

    public Boolean CanPublish(String clientId, String topic)
        => topic.StartsWith($"device/{clientId}/");  // 设备只能发布自己的主题

    public Boolean CanSubscribe(String clientId, String topicFilter)
        => topicFilter.StartsWith("sensor/");
}

// 注册
services.AddSingleton<IMqttAuthenticator, MyAuthenticator>();
```

### 八、规则引擎（消息路由/处理）

```csharp
// 规则引擎在 MqttExchange 内配置
var exchange = new MqttExchange();

// 规则：匹配主题 sensor/# → 转发到另一主题
exchange.AddRule(new MqttRule
{
    TopicFilter = "sensor/#",
    Action      = RuleAction.Republish,
    TargetTopic = "log/sensor",
});

// 规则：匹配告警主题 → 触发 WebHook
exchange.AddRule(new MqttRule
{
    TopicFilter = "alarm/#",
    Action      = RuleAction.WebHook,
    WebHookUrl  = "https://api.example.com/alarm",
});
```

### 九、集群部署

```csharp
var server = new MqttServer
{
    Port         = 1883,
    ClusterPort  = 2883,
    ClusterNodes = new[] { "192.168.1.2:2883", "192.168.1.3:2883" },
};
server.Start();
```

## 配置参数速查（MqttClient）

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `Server` | — | 服务器地址（`tcp://host:1883`，`ssl://` 表示 TLS） |
| `ClientId` | 随机 GUID | 客户端唯一标识（断线重连建议固定） |
| `KeepAlive` | `600` | 心跳间隔（秒），0 = 禁用 |
| `CleanSession` | `true` | false = 断线后服务端保留会话（离线消息） |
| `Version` | `V311` | MQTT 协议版本 |
| `Reconnect` | `true` | 自动重连 |
| `MaxReconnectAttempts` | `0` | 0 = 无限重连 |
| `InitialReconnectDelay` | `1000` | 初始重连延迟（ms） |
| `MaxReconnectDelay` | `60000` | 最大重连延迟（ms，指数退避上限） |
| `Timeout` | `15000` | 操作超时（ms） |

## 常见错误与注意事项

- **`CleanSession=false` 时 `ClientId` 必须固定**：持久会话靠 `ClientId` 识别；每次用随机 ID 会导致离线消息永远堆积，服务端会话膨胀。
- **QoS 2 不支持 Retain + 消息幂等场景**：QoS 2 保证恰好一次，但网络抖动时四次握手可能被重复触发；业务层仍需做幂等处理。
- **`IMqttExchange` 是 Broker 的必要组件**：不注入 `MqttExchange` 则消息无法在客户端间路由，所有消息只进不出。
- **通配符 `#` 订阅所有主题有性能风险**：`#` 匹配全部消息，高吞吐场景下回调处理不及时会导致内存积压。
- **遗嘱消息不要设置过大 Payload**：遗嘱消息在 CONNECT 报文中一次性传输，过大（>256KB）会拒绝连接。
