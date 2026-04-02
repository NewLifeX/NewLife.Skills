---
name: span-reader-writer
description: >
  使用 NewLife.Core 的 SpanReader / SpanWriter（ref struct，零分配）解析或构建二进制协议帧；
  使用 PacketCodec 处理 TCP 粘包/拆包，通过 GetLength2 委托从帧头读取完整包长度。
  适用于自定义二进制协议、网络帧编解码、高性能序列化等场景。
argument-hint: >
  说明你的场景：读取还是写入二进制数据；是否需要大/小端切换；
  是否处理 TCP 粘包（用 PacketCodec + GetLength2）；帧头长度字段的字节数和偏移。
---

# SpanReader / SpanWriter / PacketCodec 技能

## 适用场景

- 解析自定义二进制协议帧（Redis RESP、MQTT、私有协议）：用 `SpanReader` 零分配读取字段。
- 构建要发送的二进制帧：用 `SpanWriter` 在 `stackalloc` 或池化缓冲区上直接写入。
- TCP 长连接粘包/拆包处理：每个连接维护一个 `PacketCodec` 实例，`Parse()` 返回完整业务包列表。
- 代码审查：确认 `PacketCodec` 每连接独立实例（共享会导致状态混乱）；`GetLength2` 返回 `0`/负值表示数据不足（不能返回错误值）。

## 核心原则

1. **`SpanReader`/`SpanWriter` 是 `ref struct`**：不可装箱、不可存字段、不可跨 `await` 使用。必须在同步方法内栈上使用，完成后立即提取结果。
2. **零分配切片**：在同一底层内存上前移 `Position`，不复制数据；`ReadString(-1)` 读剩余全部字节。
3. **`IsLittleEndian` 默认 `true`**：大端协议（如 TCP 标准帧）需显式设置 `reader.IsLittleEndian = false`。
4. **`PacketCodec` 快速路径**：内部缓存为空时 `Parse` 在原始包上切片，零分配；有残余才走慢速路径（`MemoryStream` 合并）。
5. **`MaxCache` 防惩罚**：设置合理上限（如 4 MB），防止恶意畸形包耗尽内存；`Expire` 防止半包永久驻留（默认 5 秒过期清除）。

## 执行步骤

### 一、SpanReader — 读取二进制协议帧

```csharp
using NewLife.Buffers;

// 方式1：从字节数组/Span
var reader = new SpanReader(receivedBytes.AsSpan());

// 方式2：从 IPacket（零拷贝）
var reader = new SpanReader(packet);

// 基本读取
byte  opcode  = reader.ReadByte();
short length  = reader.ReadInt16();        // 小端（默认）
int   seq     = reader.ReadInt32();

// 大端协议（如 MySQL/MQTT）
reader.IsLittleEndian = false;
uint  bigLen  = reader.ReadUInt32();
reader.IsLittleEndian = true;

// 字符串读取
// length = -1: 读剩余全部
// length = 0:  先读 7 位压缩长度前缀
// length > 0:  固定长度
string all      = reader.ReadString(-1);
string prefixed = reader.ReadString(0);    // 带长度前缀
string fixed16  = reader.ReadString(16);   // 固定 16 字节

// 结构体反序列化（MemoryMarshal 直接映射，零拷贝）
MyHeader hdr = reader.Read<MyHeader>();

// 读取剩余字节为子包
ReadOnlySpan<byte> payload = reader.GetSpan();

// 确保剩余可读字节数（流模式时自动从 Stream 补齐）
reader.EnsureSpace(10);

Console.WriteLine($"已读 {reader.Position} / 总 {reader.Capacity} 字节");
```

### 二、SpanWriter — 构建二进制协议帧

```csharp
using NewLife.Buffers;

// 方式1：栈分配（适合小帧，< ~1KB）
Span<byte> buf = stackalloc byte[256];
var writer = new SpanWriter(buf);

// 方式2：池化缓冲区（大帧）
using var owner = Pool.Shared.Rent(4096);
var writer = new SpanWriter(owner.Memory.Span);

// 写入基础字段
writer.WriteByte(0x01);              // opcode
writer.Write((short)0);              // length 占位，稍后回填
var lenPos = writer.Position - 2;    // 记录 length 字段偏移

writer.Write(seqId);                 // int32
writer.WriteUInt64(timestamp);       // uint64

// 写入字符串
writer.WriteString(0, name);         // 0 = 7位压缩前缀
writer.WriteString(16, fixedField);  // 固定 16 字节，不足补零
writer.WriteString(-1, rawBytes);    // 不加前缀，写完为止

// 结构体直接序列化
writer.Write(ref myStruct);

// 回填 length 字段
int payloadLen = writer.Position - lenPos - 2;
MemoryMarshal.Write(buf.Slice(lenPos), ref payloadLen);

// 获取已写入部分
ReadOnlySpan<byte> frame = writer.WrittenSpan;
socket.Send(frame);
```

### 三、PacketCodec — TCP 粘包/拆包处理

```csharp
using NewLife.Messaging;
using NewLife.Net;

// 每个 TCP 连接创建独立实例（不可共享！）
var codec = new PacketCodec
{
    // 从帧头读取完整包长度的委托
    // 返回 0 / 负值 = 数据不足，继续等待
    // 返回正值 = 完整包字节数（含帧头）
    GetLength2 = span =>
    {
        if (span.Length < 4) return 0;           // 帧头 4 字节：int32 小端长度
        return (int)(span[0] | (span[1] << 8) | (span[2] << 16) | (span[3] << 24));
    },
    MaxCache = 4 * 1024 * 1024,   // 最大缓存 4MB
    Expire   = 10_000,             // 10 秒超时清除残余
};

// 在 NetServer 的 OnReceive 或 NetClient 的 Received 事件中调用
void OnReceive(IPacket rawPacket)
{
    var packets = codec.Parse(rawPacket);
    foreach (var pk in packets)
    {
        // pk 是一个完整的业务数据包，可安全解析
        using (pk)
        {
            var reader = new SpanReader(pk);
            ProcessFrame(ref reader);
        }
    }
}
```

### 四、完整协议解析示例

```csharp
// 帧格式：[4字节总长] [1字节Opcode] [2字节SeqId] [变长Payload]
void ProcessFrame(ref SpanReader reader)
{
    int   total  = reader.ReadInt32();   // 帧总长（含帧头）
    byte  opcode = reader.ReadByte();
    short seq    = reader.ReadInt16();
    var payload  = reader.GetSpan();     // 剩余全部为 Payload

    switch (opcode)
    {
        case 0x01: HandleLogin(payload);   break;
        case 0x02: HandleData(payload);    break;
        default:   XTrace.WriteLine("未知 opcode={0}", opcode); break;
    }
}

// 帧格式：[4字节总长] [1字节Opcode] [2字节SeqId] [变长Payload]
IPacket BuildFrame(byte opcode, short seq, ReadOnlySpan<byte> payload)
{
    var owner = Pool.Shared.Rent(7 + payload.Length);
    var writer = new SpanWriter(owner.Memory.Span);
    writer.Write(7 + payload.Length);   // 总长
    writer.WriteByte(opcode);
    writer.Write(seq);
    writer.GetSpan(payload.Length);
    payload.CopyTo(writer.GetSpan(payload.Length));
    writer.Advance(payload.Length);
    return owner.Slice(0, writer.Position);
}
```

## 重点检查项

- [ ] `SpanReader`/`SpanWriter` 是否在 `async` 方法中跨 `await` 保存？（`ref struct` 不能跨 await，必须在同步块内完成）
- [ ] `PacketCodec` 是否每个连接独立实例？（全局共享会导致不同连接的缓存互相污染）
- [ ] `GetLength2` 是否在数据不足时返回 `0` 或负值而非抛异常？
- [ ] `GetLength2` 返回的长度是否包含帧头本身（`PacketCodec` 切片时使用该值作为完整帧长度）？
- [ ] `MaxCache` 是否设置了合理上限（默认 1 MB，大包场景适当调高）？
- [ ] `IsLittleEndian` 是否与协议规范对齐（大端协议需显式设 `false`）？

## 输出要求

- **读取**：`SpanReader`（`NewLife.Buffers`）—— `ReadByte/Int16/Int32/Int64/String/Read<T>`；`Position`/`FreeCapacity`；`EnsureSpace`。
- **写入**：`SpanWriter`（`NewLife.Buffers`）—— `WriteByte/Write/WriteString/Write<T>`；`WrittenSpan`/`WrittenCount`；`Advance`/`GetSpan`。
- **粘包处理**：`PacketCodec`（`NewLife.Messaging`）—— `GetLength2` 委托；`Parse()` 返回完整包列表；每连接独立实例。

## 参考资料

- `NewLife.Core/Buffers/SpanReader.cs`
- `NewLife.Core/Buffers/SpanWriter.cs`
- `NewLife.Core/Messaging/PacketCodec.cs`
- 相关技能：`high-performance-buffers`（IPacket/IOwnerPacket 所有权模型）、`pipeline-handler-model`（PacketCodec 作为管道处理器）
