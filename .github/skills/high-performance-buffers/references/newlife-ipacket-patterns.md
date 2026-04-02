# NewLife.Core IPacket 模式证据

> 来源：`d:\X\NewLife.Core\Doc\数据包IPacket.md` + `NewLife.Core\Data\IPacket.cs`
> 用途：为 `high-performance-buffers` SKILL.md 提供代码层证据，记录各实现类型的设计决策和适用边界。

---

## 1. 接口层次（源码校验）

```text
IPacket
├── Length / Next / Total / this[index]
├── GetSpan()  / GetMemory()
├── Slice(offset, count)
├── Slice(offset, count, transferOwner)
└── TryGetArray(out ArraySegment<Byte>)

IOwnerPacket : IPacket, IDisposable
  → 标记"有释放责任"的接口，无新成员
```

**通用可复用**：接口设计本身与 NewLife 命名空间无关，可迁移到其他项目。

---

## 2. 四种实现类型对比

| 类型 | kind | 所有权 | 链式 `Next` | Slice 跨段 | 主要约束 |
|------|------|--------|------------|-----------|----------|
| `ArrayPacket` | `record struct` | 无 | ✅ | ⚠️ 假设 `Next` 也是 `ArrayPacket` | 混链跨段切片可能抛 `InvalidCastException` |
| `OwnerPacket` | `sealed class` | ✅ IOwnerPacket | ✅ | ✅ | Slice 默认转移所有权（与 ArrayPacket 语义相反） |
| `MemoryPacket` | `struct` | 无 | ✅ | ❌ `Next != null` 时 Slice 抛 `NotSupportedException` | 生命周期由外部控制 |
| `ReadOnlyPacket` | `readonly record struct` | 无 | ❌ `Next` 恒为 null | ✅（单段内） | 禁止写入，`set` 抛异常 |

---

## 3. `OwnerPacket` 设计决策（源码注释整理）

### 为什么是 class 而不是 struct？

所有权语义依赖引用同一性：
- `struct` 赋值产生值拷贝 → 切片转移所有权时修改的是副本而非原实例 → double-free 风险。
- `IDisposable + struct` 在装箱场景下无法正确释放资源。

### 为什么 sealed？

JIT 可对 `GetSpan`/`GetMemory` 等热路径方法去虚拟化并内联，显著提升协议解析性能。

### 为什么不继承 `MemoryManager<T>`？

只需 `IPacket + IDisposable`；`Pin`/`Unpin`/`IMemoryOwner.Memory` 均未使用，继承会引入死代码和额外 vtable 开销。

---

## 4. `OwnerPacket.Slice` 所有权陷阱

```csharp
// 默认（transferOwner: true）——原包失去释放权！
var payload = ownerPk.Slice(4, 512);      // ⚠️ ownerPk._hasOwner = false

// 安全借视图
var header = ownerPk.Slice(0, 4, transferOwner: false);

// 正确的多次切片模式：
using var pk = new OwnerPacket(1024);
var h = pk.Slice(0, 4, transferOwner: false);    // 借视图
var body = pk.Slice(4, 512, transferOwner: true); // 最终要持有/返回的那一段转移所有权
// pk 此后不再有释放权；body.Dispose() 归还池
```

---

## 5. `ArrayPacket` 的跨段切片陷阱

```csharp
// 混合链示例（危险）
var a = new ArrayPacket(bufA);
var b = new OwnerPacket(64);  // 非 ArrayPacket
a.Next = b;

// 当切片 offset 超出 buf A 范围时，ArrayPacket.Slice 内部会强转
// (ArrayPacket)a.Next.Slice(...)  → 抛 InvalidCastException

// 安全做法：链中保持同类（或改用 OwnerPacket 链）
```

---

## 6. `MemoryPacket` 的 `Next` 限制

```csharp
var mp = new MemoryPacket(memory);
mp.Next = someOtherPacket;        // 可以设

// 此时对 mp 调用 Slice：
mp.Slice(0, 4);  // → NotSupportedException: "Slice with Next"
```

---

## 7. `PacketHelper` 关键方法速查

| 方法 | 分配 | 说明 |
|------|------|------|
| `Append(next)` | O(1) 无分配 | 追加到链尾，O(n) 遍历 |
| `ToStr(encoding)` | 单包快路径无额外分配 | 多包走 StringBuilder |
| `ToHex(maxLength)` | 逐段遍历 | maxLength=-1 全量 |
| `ToArray()` | **总是产生新数组** | 单包 Span.ToArray，多包池化聚合 |
| `ToSegment()` | 单包尽量零拷贝 | 多包复制聚合 |
| `GetStream(writable)` | 单包 TryGetArray 成功零拷贝 | 否则聚合复制 |
| `ExpandHeader(size)` | 有前置空间时原地扩展 | 否则新 OwnerPacket 挂链 |
| `Clone()` | 总是深拷贝 | 用于快照调试 |

---

## 8. `Free()` 与 `Dispose()` 的本质区别

```csharp
// Dispose()：正确归还 ArrayPool，并递归 Next.TryDispose()
ownerPk.Dispose();  // ✅ 正常释放路径

// Free()：仅清空引用，不归还池
ownerPk.Free();     // ❌ 内存泄漏风险，仅用于"放弃但不释放"的特殊场景
```

---

## 9. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| 减少分配（ArrayPool 复用） | ✅ 通用 | `System.Buffers.ArrayPool<T>.Shared` |
| Slice 共享底层缓冲区 | ✅ 通用 | 适用任何支持 Span 的设计 |
| 链式 `Next` 避免聚合复制 | ✅ 通用 | 思路通用；具体实现可替换 |
| `IOwnerPacket.Dispose()` 归还池 | ✅ 通用 | 与 `IDisposable` 模式完全一致 |
| `OwnerPacket.Slice` 默认转移所有权 | ⚠️ NewLife 特有语义 | 与标准切片习惯相反，务必明确文档化 |
| `ArrayPacket` 链假设同类 | ⚠️ NewLife 特有约束 | 外部实现可自由设计 |
| `AggressiveInlining` 热路径优化 | ✅ 通用 | 适用任何高频 struct 方法 |
