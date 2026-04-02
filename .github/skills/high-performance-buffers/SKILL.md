---
name: high-performance-buffers
description: >
  设计零拷贝或少拷贝的二进制缓冲区抽象，覆盖切片共享底层内存、链式拼接、所有权（Owner）转移与释放、Span/Memory 的短生命周期约束，
  以及 ArrayPool 的租借/归还模式。适用于网络收发、协议解析、二进制组包等高频场景的设计与代码审查。
argument-hint: >
  描述你的缓冲区场景：Socket 接收/发送、协议解析切片、跨层传递数据段；
  说明是否需要池化、是否需要所有权转移、多段拼接还是单段读取。
---

# 高性能缓冲区设计技能

## 适用场景

- 需要对接收到的网络字节流做零拷贝协议头/协议体切片，并将不同段传递给不同层处理。
- 组装多段数据（头部 + 负载 + 尾部）并发送，希望避免聚合复制。
- 使用 `ArrayPool<T>` 租借缓冲区用于接收并在完成后归还，需要明确释放责任归属。
- 多个消费者需要对同一段数据做只读访问，或者某一段必须禁止修改。
- 已有连续数组缓冲区，需要包装为统一抽象对外暴露，不产生额外复制。

## 核心原则

1. **减少分配**：优先复用缓冲区（`ArrayPool<T>.Shared`）；切片时共享底层数组，而不是复制到新数组。
2. **减少拷贝**：`Slice(offset, count)` 始终共享底层内存，仅记录偏移和长度；只有在确实需要独立副本时才调用 `ToArray()` 或 `Clone()`。
3. **链式而非聚合**：通过 `Next` 串接多段数据（`Append`），避免为大包预分配一块连续内存再复制；在需要连续内存时按需调用 `ToArray()`。
4. **明确所有权**：池化缓冲区必须有且只有一方负责释放；所有权通过 `IOwnerPacket.Dispose()` 语义表达，非池化缓冲区不需要也不应强加释放责任。
5. **Span/Memory 短生命周期**：`GetSpan()` / `GetMemory()` 是借用视图；禁止将其保存到字段、闭包、队列、异步回调中——仅在调用栈内同步使用。

## 执行步骤

### 一、选择包类型

| 场景 | 推荐类型 |
|------|----------|
| 高频、无池化、传递方式多样 | `ArrayPacket`（值类型，轻量）|
| 从 `ArrayPool` 租借缓冲区 | `OwnerPacket`（需 `Dispose`）|
| 已有 `Memory<Byte>` 外部来源 | `MemoryPacket`（无所有权）|
| 多线程共享只读常量数据 | `ReadOnlyPacket` |

> 同一链中混合类型需谨慎：`ArrayPacket` 跨段切片假设 `Next` 也是 `ArrayPacket`，混链可能导致转型异常。

### 二、实现切片语义

1. **共享切片（默认）**：`Slice(offset, count)` — 返回共享底层缓冲区的新视图，不分配。
2. **视图借用**：`Slice(offset, count, transferOwner: false)` — 明确表达"仅借视图、不转移责任"。
3. **所有权转移**：`Slice(offset, count, transferOwner: true)` — 新包成为所有者，原包失去释放权；**只能发生一次**，且必须明确记录哪一方最终负责 `Dispose`。

> `OwnerPacket.Slice(offset, count)` 的**默认行为是转移所有权**，与一般共享切片语义相反。在多次切片时应显式传入 `transferOwner: false`。

### 三、链式拼接

1. 使用 `Append(next)` 在链尾追加，时间复杂度 O(n)；链条极长时改为构建链节点树或预先规划结构。
2. `Length` 仅反映当前段；`Total` 反映整链总长——判断是否为空应看 `Total`。
3. `ToArray()` 总是复制；`ToSegments()` 保持分段结构（适合 Scatter/Gather IO）。
4. 头部扩展使用 `ExpandHeader(size)`：有前置空间时原地扩展，否则生成新头节点并挂载原包为 `Next`。

### 四、所有权管理

1. 持有 `IOwnerPacket` 的一方负责最终释放；`Dispose()` 通常会递归释放 `Next` 链。
2. 在流水线场景（如：接收 → 解析 → 应用层触发），最好在最外层用 `using` 声明所有权，内层函数通过 `transferOwner: false` 传递视图；仅在最终返回/保存的结果上转移。
3. 调用 `Free()` 会清空引用但**不**归还池化内存，存在泄漏风险；仅在确实需要"放弃但不释放"的特殊场景中使用。

### 五、Span/Memory 使用约束

1. `GetSpan()` / `GetMemory()` 只能在方法同步栈帧内使用。
2. 不要将 `Span<Byte>` 或 `Memory<Byte>` 存入字段、捕获到 `async` 方法闭包、放入 `Channel`/`Queue` 或作为 `Task` 的完成值。
3. 跨层传递数据时应传递 `IPacket`（而非 `Span`/`Memory`），由接收方在其作用域内自行调用 `GetSpan()`。
4. `MemoryPacket` 底层可能来自 `MemoryPool`，有效期由调用方控制；不比 `Span` 宽松。

### 六、调试与诊断

- `ToHex(maxLength, separator, groupSize)`：打印十六进制预览（跨链连续分组）。
- `ToStr(encoding, offset, count)`：按编码读取文本内容。
- `Clone()`：深拷贝当前链为独立 `ArrayPacket`，用于断点观察数据快照。

### 七、零分配解析（SpanReader）

`SpanReader` 是 `ref struct`，从 `Span<Byte>` / `IPacket` / `Stream` 零分配读取二进制数据：

```csharp
// 从 IPacket 构造，直接在原始内存上解析
var reader = new SpanReader(packet);

// 读取基础类型（默认大端，IsLittleEndian=true 切换小端）
var magic  = reader.ReadUInt32();
var length = reader.ReadEncodedInt();           // 7位变长整数
var name   = reader.ReadString(0);              // 带长度前缀的字符串（长度=0表示读前缀）
var body   = reader.ReadBytes(length);          // 固定长度切片

// 读取结构体（直接内存布局，零拷贝）
[StructLayout(LayoutKind.Sequential, Pack = 1)]
struct PacketHeader { ... }
var header = reader.Read<PacketHeader>();
```

**关键约束**：`SpanReader` 是 `ref struct`，禁止存入字段、`async` 方法、`Task`、队列。

### 八、零分配写入（SpanWriter / PooledByteBufferWriter）

```csharp
// 固定缓冲区写入（栈上分配，Size 小于 1KB 时推荐）
Span<Byte> buf = stackalloc Byte[256];
var w = new SpanWriter(buf);
w.Write((UInt32)0x12345678);          // 写 Magic
w.WriteEncodedInt(messageId);         // 7位变长整数
w.Write(content, 0);                  // 带长度前缀的字符串
var written = buf[..w.WrittenCount];  // 已写入的切片

// 动态池化写入（大包或不定长，实现 IBufferWriter<Byte>）
using var pw = new PooledByteBufferWriter(initialCapacity: 1024);
var sw = new SpanWriter(pw.GetSpan(256));
sw.Write(payload);
pw.Advance(sw.WrittenCount);
var memory = pw.WrittenMemory;  // ReadOnlyMemory<Byte>，零拷贝输出
```

### 九、TCP 粘包拆包（PacketCodec）

每个 TCP 连接独立一个 `PacketCodec`，解决粘包/半包问题：

```csharp
// 在 NetSession 中
private readonly PacketCodec _codec = new PacketCodec
{
    // 从头部读取完整包长度（返回 0 / 负数 = 数据不足）
    GetLength2 = span =>
    {
        if (span.Length < 4) return 0;
        return (span[0] << 24 | span[1] << 16 | span[2] << 8 | span[3]) + 4;
    },
    MaxCache = 4 * 1024 * 1024,  // 防止恶意大包耗尽内存
    Expire   = 5_000,             // 5秒内未收到完整包则丢弃残余缓存
};

protected override void OnReceive(ReceivedEventArgs e)
{
    // 一包可能包含多条消息，或不足一条
    foreach (var pk in _codec.Parse(e.Packet))
        ProcessMessage(pk);  // pk 是一个完整的业务帧
}

protected override void OnDisconnected(String reason)
{
    base.OnDisconnected(reason);
    _codec.Dispose();  // 释放内部 MemoryStream
}
```

**快速路径**：无残余缓存时，`Parse` 直接在原始 `IPacket` 上切片，不分配内存；**慢速路径**：有残余缓存时合并到 `MemoryStream` 后继续解析（有锁保护）。

## 重点检查项

- [ ] `OwnerPacket` 的释放路径是否完整？是否有 `using` 或等效的 `Dispose` 确保归还池？
- [ ] 是否存在对同一 `OwnerPacket` 多次调用默认 `Slice`（即多次默认转移所有权）？
- [ ] 是否将 `GetSpan()` / `GetMemory()` 的返回值存入了字段或 `async` 方法？
- [ ] `MemoryPacket` 是否在有 `Next` 的情况下调用了 `Slice`（将抛 `NotSupportedException`）？
- [ ] 链中是否混合了 `ArrayPacket` 和非 `ArrayPacket` 类型，同时存在跨段切片路径？
- [ ] 是否错误地调用 `Free()` 替代 `Dispose()`，导致缓冲区泄漏？
- [ ] 链式遍历是否是性能热路径？若是，考虑提前聚合为连续缓冲区（`ToArray()` / `GetStream()`）。

## 输出要求

- **接口**：`IPacket.cs`（含 `IOwnerPacket`），定义切片、所有权、链式、Span/Memory 方法签名。
- **实现**：按场景分类：`ArrayPacket`（值类型）、`OwnerPacket`（池化）、`MemoryPacket`（外部内存）、`ReadOnlyPacket`（只读）。
- **扩展**：`PacketHelper.cs`，集中链式拼接、格式转换、流操作、头部扩展等工具方法。
- **单元测试**：覆盖所有权转移、多次切片防重复释放、跨段索引、`MemoryPacket + Next` 异常路径、池内存归还验证。
- **文档**：明确说明各实现的生死周期、`Slice` 所有权默认行为差异、链式包的适用范围。

## 参考资料

参考示例与设计决策证据见 `references/newlife-ipacket-patterns.md`。
