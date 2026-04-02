# 源码纵深扫描进度追踪（第五轮）

## 总体目标

对 `NewLife.Core` 7 个核心模块的源码进行纵深扫描，验证并增强现有技能库。
每个模块输出：①关键设计决策；②与现有 SKILL.md 的差异（缺失/有误）；③新增 references 或补丁。

## 模块文件清单

| 模块目录 | 关键文件 | 对应技能 | 扫描状态 |
|---------|---------|---------|---------|
| `Configuration/` | `IConfigProvider.cs`, `Config.cs`, `ConfigAttribute.cs`, `HttpConfigProvider.cs`, `ApolloConfigProvider.cs` | `config-provider-system` | ✅ 已完成，技能准确 |
| `Caching/` | `ICache.cs`, `Cache.cs`, `MemoryCache.cs`, `IProducerConsumer.cs`, `CacheProvider.cs` | `cache-provider-architecture` | ✅ 已修复3处错误 |
| `Log/` | `ILog.cs`, `ITracer.cs`, `ISpan.cs`, `XTrace.cs`, `TextFileLog.cs` | `logging-tracing-system` | ✅ 已修复1处错误 |
| `Model/` | `IObjectContainer.cs`, `ObjectContainer.cs`, `ObjectContainerHelper.cs` | `dependency-injection-ioc` | ✅ 已完成，技能准确 |
| `Serialization/` | `SerialHelper.cs`, `XmlHelper.cs`, `IJsonHost.cs` | `serialization-patterns` | ✅ 已修复1处错误 |
| `Net/` | `NetServer.cs`, `NetSession.cs`, `INetSession.cs` | `network-server-sessions` | ✅ 已完成，技能准确 |
| `Remoting/` | `ApiHttpClient.cs`, `ILoadBalancer.cs`, `ServiceEndpoint.cs` | `http-client-loadbalancer` | ✅ 已完成，技能准确 |

## 扫描顺序（按价值/风险排序）

1. ✅ **Configuration** — 技能准确，`ConfigAttribute`/`HttpConfigAttribute`/`ConfigCacheLevel` 全部吻合
2. ✅ **Caching** — 已修复 `IProducerConsumer` 队列 API（删除不存在的 `AddAsync`/`TakeAsync`/`AckAsync`，改为实际的 `Add()`/`Take()`/`TakeOneAsync()`/`Acknowledge()`）；新增 `IncrementWithTtl` 说明；补充 `AcquireLock` 完整重载
3. ✅ **Log** — 修复 `GetCurrentSpan()` 错误，正确访问方式为 `DefaultSpan.Current?.TraceId`
4. ✅ **Model** — 技能准确，`AddSingleton`/`AddTransient`/`AddScoped`/`TryAdd*` 全部经源码验证
5. ✅ **Serialization** — 修复 XML 从文件反序列化，`XmlHelper.LoadXml<T>()` 不存在，正确为 `"path".ToXmlFileEntity<T>()`
6. ✅ **Net** — 技能准确，`UseSession`（布尔属性）、`NetServer<TSession>`、`Add<THandler>()` 全部吻合
7. ✅ **Remoting** — 技能准确，`ILoadBalancer`、`ServiceEndpoint`、`ApiHttpClient` 方法签名全部吻合

## 修复汇总

| 文件 | 问题 | 修复方式 |
|------|------|---------|
| `cache-provider-architecture/SKILL.md` | 队列 API 使用不存在的 `AddAsync`/`TakeAsync`/`AckAsync` | 改为真实接口 `Add()`/`Take()`/`TakeOneAsync()`/`Acknowledge()` |
| `cache-provider-architecture/SKILL.md` | 缺少 `IncrementWithTtl` 返回 `(Value, Ttl)` 元组 | 在原子递增示例中新增说明 |
| `cache-provider-architecture/SKILL.md` | 缺少 `AcquireLock(key, msTimeout, msExpire, throwOnFailure)` 完整重载 | 在分布式锁章节补充完整重载示例 |
| `logging-tracing-system/SKILL.md` | `DefaultTracer.Instance?.GetCurrentSpan()` 方法不存在 | 改为 `DefaultSpan.Current?.TraceId`（AsyncLocal 静态属性）|
| `serialization-patterns/SKILL.md` | `XmlHelper.LoadXml<T>()` 静态方法不存在 | 改为 `"filePath".ToXmlFileEntity<T>()` 扩展方法 |

## 每轮扫描输出格式

```
### {模块}
**扫描文件**：列出实际读取的文件
**发现问题**：技能中有误/缺失的内容
**新增内容**：reference 或 skill 补丁
**已验证**：技能中正确的关键断言
```

## 停止条件

- 同一轮涉及超过 2 个模块时，标记为"待继续"后暂停总结
- 某文件超过 300 行只读关键部分（接口定义、关键构造、公共方法）

---

*最后更新：第五轮扫描全部完成，共发现并修复 5 处技能错误*
