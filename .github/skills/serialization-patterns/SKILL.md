---
name: serialization-patterns
description: >
  在 .NET 应用中选择并使用 NewLife.Core 的序列化方案：JSON（ToJson/ToJsonEntity）、
  XML（ToXml/ToXmlEntity）和高性能二进制（Binary.FastWrite/FastRead）。
  涵盖各格式选型标准、关键 API、扩展点和常见配置，适用于 API 数据交换、
  配置文件持久化、网络协议编码、缓存序列化等场景。
argument-hint: >
  说明你的序列化场景：Web API 数据交换 vs 网络协议编码 vs 配置文件；
  是否需要驼峰命名、忽略空值、附加注释；对性能/体积是否有高要求；
  是否需要版本兼容性（Binary 的 Version 属性）。
---

# 序列化模式技能

## 适用场景

- Web API 返回 JSON 响应，需要驼峰命名、忽略 null 字段。
- 配置文件持久化到 XML，需要附加属性注释（`[Description]`）辅助维护。
- 网络协议编码，需要最小字节流（7位变长整数 + 二进制字段），高吞吐场景。
- 缓存序列化：对象→字节，需要快速、无需 Schema 的方案。
- 代码审查：检查序列化格式是否与使用场景匹配，是否有不必要的反射开销。

## 格式选型

| 场景 | 推荐格式 | 理由 |
|------|---------|------|
| Web API / HTTP 前后端 | JSON | 互操作性最好 |
| 配置文件需人工编辑 | XML（`attachComment=true`）| 可附加字段注释 |
| 网络协议/二进制帧 | Binary | 体积最小，无文本开销 |
| 缓存字节序列化 | Binary | 速度快，无额外依赖 |
| 跨语言数据交换 | JSON | 普遍支持 |
| 调试/日志结构化输出 | JSON（indented）| 可读性好 |

## 执行步骤

### 一、JSON 序列化

```csharp
using NewLife.Serialization;

// 序列化（默认：有缩进=false，包含null值=true，驼峰=false）
var json = obj.ToJson();

// 格式化输出（调试/日志）
var jsonIndented = obj.ToJson(indented: true);

// Web API 风格（驼峰 + 过滤null）
var jsonApi = obj.ToJson(indented: false, nullValue: false, camelCase: true);

// 反序列化为强类型
var user = json.ToJsonEntity<User>();

// 反序列化为动态字典（处理未知结构）
var dict = json.DecodeJson();
var code = dict?["code"].ToInt();
var nested = dict?["data"] as IDictionary<String, Object?>;
```

**常用参数说明**：
- `indented`：格式化缩进（true = 多行，false = 单行）
- `nullValue`：是否序列化 null 字段（false = 忽略 null）
- `camelCase`：驼峰命名（`UserName` → `userName`）

### 二、XML 序列化

```csharp
using NewLife.Xml;

// 序列化为 XML 字符串
var xml = config.ToXml();

// 附加注释版（从 [Description] 特性读取，适合配置文件）
var xmlWithComments = config.ToXml(attachComment: true);

// 使用 XML 属性模式（<Item id="1" name="a"/>）
var xmlAttr = config.ToXml(useAttribute: true);

// 直接序列化到文件（默认附加注释）
config.ToXmlFile("config/app.xml");

// 从文件反序列化（扩展方法：this String file）
var config = "config/app.xml".ToXmlFileEntity<AppConfig>();

// 从字符串反序列化
var config = xml.ToXmlEntity<AppConfig>();
```

**注释生成规则**：  
字段/属性上的 `[Description("说明文字")]` 或 `[DisplayName("显示名")]` 特性会自动写入 XML 注释，方便运维人员理解配置文件。

### 三、二进制序列化

```csharp
using NewLife.Serialization;

// 快速序列化（默认启用7位变长整数，减小体积）
var packet = Binary.FastWrite(obj);             // → IPacket
var bytes = packet.ToArray();

// 写入流
using var ms = new MemoryStream();
Binary.FastWrite(obj, ms, encodeInt: true);

// 快速反序列化
using var ms2 = new MemoryStream(bytes);
var obj2 = Binary.FastRead<MyClass>(ms2, encodeInt: true);
```

**高级配置（自定义 Binary 实例）**：

```csharp
var bn = new Binary
{
    EncodeInt    = true,   // 7位变长整数（小值整数体积更小）
    IsLittleEndian = false, // 大端字节序（网络字节序，协议常用）
    UseFieldSize = false,  // 是否读取 [FieldSize] 特性指定字段大小
    SizeWidth    = 0,      // 字符串长度前缀宽度（0=压缩，1/2/4=固定宽度）
    Version      = "2.0",  // 协议版本，支持多版本序列化分支
};

bn.Stream = new MemoryStream();
bn.Write(obj);
var bytes = bn.GetBytes();
```

### 四、二进制协议中的字段大小控制

```csharp
// [FieldSize(n)] 指定字段使用固定字节数（UseFieldSize=true 时生效）
public class Packet
{
    [FieldSize(4)]
    public String Command { get; set; }  // 精确占用4字节

    public Int32 Length { get; set; }    // 7位变长整数（EncodeInt=true）

    public Byte[] Payload { get; set; }  // 由 Length 指定的负载
}
```

### 五、JSON 与 System.Text.Json 切换

```csharp
// 全局切换：使用 System.Text.Json 作为 JSON 实现（而非默认 FastJson）
JsonHelper.Default = new SystemTextJson();

// 之后 ToJson() / ToJsonEntity<T>() 自动使用新实现
```

## 重点检查项

- [ ] JSON 场景：是否误用了二进制序列化（通常 JSON 更符合 HTTP 语义）？
- [ ] XML 配置文件是否开启 `attachComment`（帮助运维理解配置项含义）？
- [ ] 网络协议中的字节序（大端 vs 小端）是否与对端协议规范一致？
- [ ] `Binary.FastWrite/FastRead` 的 `encodeInt` 参数两端是否保持相同（不一致会解析错误）？
- [ ] 是否在热路径上频繁创建 `new Binary()` 实例（可考虑对象池或复用）？
- [ ] JSON `DecodeJson` 返回值需要 null 检查（输入为非法 JSON 时返回 null）？

## 输出要求

- **JSON**：`JsonHelper.ToJson()`/`ToJsonEntity<T>()`/`DecodeJson()` 扩展方法（位于 `NewLife.Serialization`）。
- **XML**：`XmlHelper.ToXml()`/`ToXmlEntity<T>()`/`ToXmlFile()`（位于 `NewLife.Xml`）。
- **Binary**：`Binary` 类（位于 `NewLife.Serialization`）：`FastWrite`/`FastRead` 静态快捷方法 + 实例详细配置。
- **`IPacket`**：`Binary.FastWrite` 返回此接口，避免内存拷贝；调用 `ToArray()` 仅在需要 `byte[]` 时使用。

## 参考资料

参考示例与模式证据见 `references/newlife-serialization-patterns.md`。
