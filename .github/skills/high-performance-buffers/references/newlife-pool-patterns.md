# 对象池模式（Object Pool）

## 适用场景

减少高频对象创建/销毁造成的 GC 压力：网络缓冲区、消息解析对象、`StringBuilder`、`MemoryStream`、自定义序列化对象。

## 模式结构

```
IPool<T>
  └─ Pool<T>（无锁 CAS 数组，大小 CPU*2）
       ├─ Get()         — 取出对象（池空时调用 OnCreate() 新建）
       ├─ Return(T)     — 归还对象（超出容量时直接丢弃）
       ├─ Clear()       — 清空对象池
       └─ OnCreate()    — 工厂方法（virtual，子类重写）
```

## 核心 API（NewLife.Collections）

```csharp
// 1. 基本使用
var pool = new Pool<MyObject>();

var obj = pool.Get();
try
{
    obj.Value = 42;
    obj.Process();
}
finally
{
    obj.Reset();          // 重置状态（重要！）
    pool.Return(obj);
}

// 2. 自定义对象池（重写工厂方法）
public class BufferPool : Pool<Byte[]>
{
    public Int32 BufferSize { get; set; } = 4096;

    protected override Byte[] OnCreate() => new Byte[BufferSize];

    public override Boolean Return(Byte[] value)
    {
        if (value.Length != BufferSize) return false;  // 大小不匹配不入池
        Array.Clear(value, 0, value.Length);
        return base.Return(value);
    }
}

// 3. 内置 StringBuilder 池（推荐方式）
var sb = Pool.StringBuilder.Get();
sb.Append("Name: ").Append(name);
var result = sb.Return(true);   // 归还并返回字符串
// 或
sb.Return(false);               // 仅归还，不需要内容
```

## 关键属性与参数

| 属性 / 参数 | 默认值 | 说明 |
|------------|-------|------|
| `Max` | `CPU * 2`（最小 8） | 对象池最大容量 |
| `InitialCapacity`（StringBuilder 专用） | 100 | 初始字符串容量 |
| `MaximumCapacity`（StringBuilder 专用） | 4096 | 超过此容量归还时直接丢弃 |

## 设计规则

| 规则 | 说明 |
|------|------|
| 归还前必须重置状态 | 不重置会导致下次取出时数据污染 |
| 用 `try/finally` 保证归还 | 异常路径也必须归还，否则池越用越少 |
| 大小不匹配时返回 false | `Pool<T>.Return` 返回 false 表示未入池，调用方无需关心 |
| 不要存储对象引用 | 归还后立即放弃引用；继续使用属于 use-after-return |
| 池大小不宜过大 | 默认值通常足够；过大会占用内存且不会提升性能 |

## 与 ArrayPool 的对比

| 对比点 | `Pool<T>` | `ArrayPool<T>` |
|--------|----------|----------------|
| 适用类型 | 任意 `class` | 仅 `T[]` |
| 实现 | 无锁 CAS 数组 | 分层桶设计 |
| GC 清理 | 支持二代 GC 自动清理 | 不支持 |
| 内置池 | `Pool.StringBuilder` 等 | 仅 `ArrayPool<T>.Shared` |
| 使用场景 | 业务对象复用 | 字节缓冲区 |

## 来源

- `D:\X\NewLife.Core\Doc\对象池Pool.md`
- `D:\X\NewLife.Core\NewLife.Core\Collections\Pool.cs`（命名空间 `NewLife.Collections`）
