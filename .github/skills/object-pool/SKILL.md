---
name: object-pool
description: >
  使用 NewLife.Core 的 Pool<T>（无锁 CAS 对象池）复用高频短生命周期对象（如 StringBuilder/MemoryStream），
  以及 PooledByteBufferWriter（基于 ArrayPool<byte> 的动态扩容写入缓冲区，实现 IBufferWriter<byte>）减少 GC 压力。
  适用于高并发序列化、网络帧构建、大块临时字节缓冲区的写入场景。
argument-hint: >
  说明你的场景：复用哪种对象（StringBuilder / MemoryStream / 自定义类型）；
  还是需要动态写入字节缓冲区（用 PooledByteBufferWriter）与序列化库（System.Text.Json / MessagePack）配合。
---

# 对象池技能（Pool<T> + PooledByteBufferWriter）

## 适用场景

- **`Pool<T>`**：高频创建/销毁的 `class` 对象，如 `StringBuilder`、`MemoryStream`、连接包装器、消息对象。
- **`Pool.StringBuilder`**：内置 `StringBuilder` 专用池，`Return(true)` 同时返回字符串内容并归还。
- **`PooledByteBufferWriter`**：动态扩容、零拷贝的字节写入缓冲区，实现 `IBufferWriter<byte>`，与 `Utf8JsonWriter`、`MessagePackSerializer` 等标准序列化库配合。
- 代码审查：确认 `Return()`/`Dispose()` 在 `finally` 中调用，避免对象泄漏；`PooledByteBufferWriter.Dispose()` 才能归还 `ArrayPool` 内存。

## 核心原则

1. **`Get()` 与 `Return()` 成对**：任何从池取出的对象都必须在 `finally` 中 `Return()`，否则池容量持续缩减直至每次都新建。
2. **无锁 CAS**：`Pool<T>` 用 `Interlocked.CompareExchange` 实现无锁，高并发下扩展良好，但 `Max` 默认为 `CPU × 2`（最少 8）—— 并发超过 Max 时多余对象被丢弃而非等待。
3. **`PooledByteBufferWriter` 必须 `Dispose`**：内部持有 `ArrayPool<byte>` 租借的数组，不 `Dispose` 会导致池内存泄漏。
4. **归还前清空**：`StringBuilder` 在 `Return()` 时自动 `Clear()`；自定义类型需在 `Return()` 前手动重置状态，避免后续 `Get()` 取到含上次数据的对象。
5. **避免扩容损耗**：`PooledByteBufferWriter` 初始容量设为预估写入量的 1~2 倍，减少扩容次数（每次扩容约 2 倍增长，旧缓冲区归还池）。

## 执行步骤

### 一、Pool<T> — 自定义对象池

```csharp
using NewLife.Collections;

// 定义全局共享池（静态字段，生命周期与应用相同）
private static readonly Pool<MyBuffer> _pool = new Pool<MyBuffer>(max: 32);

// 使用模式（始终用 try/finally 保证归还）
var obj = _pool.Get();
try
{
    obj.Reset();          // 清空上次状态！
    obj.DoWork(data);
    return obj.Result();
}
finally
{
    _pool.Return(obj);    // 或 _pool.Put(obj)（别名）
}
```

#### 自定义创建逻辑

```csharp
public class MyPool : Pool<MyExpensiveObject>
{
    // 重写工厂方法
    protected override MyExpensiveObject? OnCreate()
        => new MyExpensiveObject(initialSize: 4096);
}

// GC 回收时自动清空池（减少内存碎片）
var pool = new MyPool(max: 16, useGcClear: true);  // 通过 protected 构造函数
```

### 二、Pool.StringBuilder — 内置字符串池

```csharp
using NewLife.Collections;

// 从共享 StringBuilder 池取出
var sb = Pool.StringBuilder.Get();
try
{
    sb.Append("Hello, ");
    sb.Append(userName);
    sb.Append('!');

    // 方式1：Return(true) 同时获取字符串并归还（推荐）
    var result = sb.Return(true);   // 返回 "Hello, 张三!"，内部已 Clear() 并归还池
    return result;
}
catch
{
    sb.Return(false);               // 不需要返回值时直接归还
    throw;
}
```

> `sb.Return(true/false)` 是扩展方法：`true` = `ToString()` 后归还；`false` = 直接归还。

### 三、PooledByteBufferWriter — 字节写入缓冲区

```csharp
using NewLife.Buffers;

// 基本使用
using var writer = new PooledByteBufferWriter(initialCapacity: 1024);

// 获取可写区域（自动扩容）
Span<byte> span = writer.GetSpan(64);
span[0] = 0x01;
span[1] = 0x02;
writer.Advance(2);

// 读取已写入数据
ReadOnlyMemory<byte> data = writer.WrittenMemory;
ReadOnlySpan<byte>   span2 = writer.WrittenSpan;
int count = writer.WrittenCount;

// 写入到 Stream
await writer.WriteToAsync(networkStream);

// 复用实例（清空内容，不归还内存）
writer.Clear();
WriteMoreData(writer);
```

### 四、与序列化库配合

```csharp
// 与 System.Text.Json 配合（无额外字节拷贝）
using var writer = new PooledByteBufferWriter(4096);
using var jsonWriter = new Utf8JsonWriter(writer);

jsonWriter.WriteStartObject();
jsonWriter.WriteString("name", userName);
jsonWriter.WriteNumber("age", age);
jsonWriter.WriteEndObject();
jsonWriter.Flush();

var jsonBytes = writer.WrittenMemory;
await stream.WriteAsync(jsonBytes);
// using 结束时自动 Dispose，归还 ArrayPool 内存
```

### 五、属性速查

**Pool<T>**

| 成员 | 说明 |
|------|------|
| `Max` | 池最大容量，默认 `CPU × 2`（最少 8） |
| `Get()` | 取出对象，池空时调用 `OnCreate()` 新建 |
| `Return(T)` / `Put(T)` | 归还对象 |
| `Clear()` | 清空池（返回清除数量） |
| `OnCreate()` | 可重写的工厂方法 |

**PooledByteBufferWriter**

| 属性 | 说明 |
|------|------|
| `WrittenMemory` | 已写入区域（`ReadOnlyMemory<byte>`） |
| `WrittenSpan` | 已写入区域（`ReadOnlySpan<byte>`） |
| `WrittenCount` | 已写入字节数 |
| `Capacity` | 当前缓冲区总容量 |
| `FreeCapacity` | 剩余可写字节数 |
| `GetMemory(hint)` | 获取可写 `Memory<byte>`（至少 hint 字节） |
| `GetSpan(hint)` | 获取可写 `Span<byte>` |
| `Advance(count)` | 标记已写入 count 字节 |
| `Clear()` | 仅清空内容，保留底层数组 |
| `ClearAndReturnBuffers()` | 清空并归还 `ArrayPool` 数组 |
| `Dispose()` | 归还底层数组到池 **（必须调用）** |

## 重点检查项

- [ ] `Pool<T>.Get()` 后是否在 `finally` 里调用 `Return()`？
- [ ] 自定义类型归还前是否已重置内部状态（防止下次 `Get()` 取到脏数据）？
- [ ] `PooledByteBufferWriter` 是否通过 `using` 或手动 `Dispose()` 释放（归还 `ArrayPool` 内存）？
- [ ] `PooledByteBufferWriter` 初始容量是否接近实际写入量（避免多次扩容）？
- [ ] `Pool.StringBuilder` 的 `Return(true)` / `Return(false)` 使用是否正确（只有需要字符串结果时才传 `true`）？
- [ ] 池 `Max` 是否根据并发量调整（默认 `CPU×2` 对超高并发可能不够）？

## 输出要求

- **通用对象池**：`Pool<T>`（`NewLife.Collections`）—— `Get()`/`Return()`；`OnCreate()` 重写；`Pool.StringBuilder` 内置实例。
- **字节写入缓冲区**：`PooledByteBufferWriter`（`NewLife.Buffers`）—— `IBufferWriter<byte>` 实现；`WrittenMemory`/`WrittenSpan`；必须 `Dispose()`。

## 参考资料

- `NewLife.Core/Collections/Pool.cs`
- `NewLife.Core/Buffers/PooledByteBufferWriter.cs`
- 相关技能：`high-performance-buffers`（IPacket/IOwnerPacket 内存所有权）、`span-reader-writer`（SpanWriter 与池化缓冲区配合）
