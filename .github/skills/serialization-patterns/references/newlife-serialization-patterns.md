# NewLife.Core 序列化模式证据

> 来源：`Doc/JSON序列化.md`（GBK，代码片段可读）+ `Doc/二进制序列化Binary.md`（GBK）+ `Doc/XML序列化.md`（GBK）
> `Doc/高级二进制序列化.md` 存在编码损坏，未作为主要来源。

---

## 1. JSON — 核心 API（从文档代码片段恢复）

```csharp
// 序列化
string ToJson(this Object value, Boolean indented = false)
string ToJson(this Object value, Boolean indented, Boolean nullValue, Boolean camelCase)
string ToJson(this Object value, JsonOptions jsonOptions)

// 反序列化
T? ToJsonEntity<T>(this String json)
Object? ToJsonEntity(this String json, Type type)

// 解析为字典
IDictionary<String, Object?>? DecodeJson(this String json)
```

**全部命名空间**：`using NewLife.Serialization;`

---

## 2. XML — 核心 API（从文档代码片段恢复）

```csharp
// 序列化
string ToXml(this Object obj, Encoding? encoding = null,
    Boolean attachComment = false, Boolean useAttribute = false)
void ToXmlFile(this Object obj, String file, Encoding? encoding = null,
    Boolean attachComment = true)  // 文件版默认开启注释

// 反序列化
T? ToXmlEntity<T>(this String xml)
```

**全部命名空间**：`using NewLife.Xml;`  
**注释来源**：`[Description("...")]` 或 `[DisplayName("...")]` 特性 → XML `<!-- ... -->` 注释

---

## 3. Binary — 核心属性（从文档代码片段恢复）

```csharp
// 快速序列化（静态方法）
IPacket FastWrite(Object value, Boolean encodeInt = true)
Int64 FastWrite(Object value, Stream stream, Boolean encodeInt = true)

// 快速反序列化（静态方法）
T? FastRead<T>(Stream stream, Boolean encodeInt = true)

// Binary 实例属性
Boolean EncodeInt        // 7位变长整数（默认 false；FastWrite 静态默认 true）
Boolean IsLittleEndian   // 字节序（默认 false = 大端，即网络字节序）
Boolean UseFieldSize     // 读取 [FieldSize] 特性（默认 false）
Int32 SizeWidth          // 字符串长度前缀（0=压缩，1/2/4=固定字节数）
Boolean TrimZero         // 字符串末尾 \0 裁剪（默认 false）
String? Version          // 协议版本（支持多版本分支序列化）
Boolean FullTime         // 完整时间格式（8字节，默认 false = 紧凑 4字节）
Int64 Total              // 读写字节计数
```

---

## 4. 格式对比（研究结论）

| 维度 | JSON | XML | Binary |
|------|------|-----|--------|
| 体积 | 中 | 大 | 小（变长整数）|
| 人类可读 | ✅ | ✅（有注释更佳）| ❌ |
| 互操作性 | ✅ 跨语言 | ✅ 跨语言 | ⚠️ NewLife 专有 |
| 性能 | 中 | 低 | 高 |
| 流式无 Schema | ❌ | ❌ | ✅ |
| 版本兼容 | 需额外逻辑 | 需额外逻辑 | ✅（Version 属性）|
| 配置文件注释 | ❌ | ✅ | ❌ |

---

## 5. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| JSON 互操作性最好 | ✅ 通用 | 普遍规律，非 NewLife 特有 |
| `ToJson(camelCase)` 驼峰 | ✅ 通用概念 | 参数方式是 NewLife 特有 |
| Binary 7位变长整数 | ⚠️ 近似通用 | ProtoBuf 也用此编码，但二进制格式不兼容 |
| `[FieldSize]` 注解控制位数 | ⚠️ NewLife 特有 | 概念通用，特性名 NewLife 专定 |
| `Binary.Version` 多版本 | ⚠️ NewLife 特有 | 可启用基于版本的条件序列化 |
| `FastWrite` 返回 `IPacket` | ⚠️ NewLife 特有 | 零拷贝数据包接口 |
