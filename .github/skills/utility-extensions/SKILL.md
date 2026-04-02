---
name: utility-extensions
description: >
  使用 NewLife.Core 提供的工具扩展方法：类型安全转换（ToInt/ToDateTime/ToBoolean）、
  字符串操作（IsNullOrEmpty/EqualIgnoreCase/Split/Join/Substring 提取/模糊搜索）、
  路径处理（GetFullPath/CombinePath/EnsureDirectory）、流与字节操作（IOHelper），
  以及高性能反射（Reflect：CreateInstance/Invoke/GetValue/SetValue/Copy）。
  适用于日常编码、参数解析、文件操作、数据格式化与代码审查任务。
argument-hint: >
  说明你的场景：类型转换（字符串转数字/日期）、字符串处理（拆分/拼接/截取/模糊匹配）、
  文件路径操作（全路径/目录确保/合并路径）、流/字节操作（编解码/压缩），还是反射操作（动态调用/属性读写）。
---

# 工具扩展方法技能

## 适用场景

- 用户输入或配置项需要安全转换（失败返回默认值，而不是抛出异常）—— `ToInt`/`ToDateTime` 等。
- 字符串操作需要忽略大小写比较、一次性拆分为数字数组、枚举 Join 等 —— `StringHelper`。
- 文件路径需要跨平台统一（`\` vs `/`）、相对路径转绝对路径 —— `PathHelper`。
- 流/字节数组处理：读写定长字节、压缩/解压、大小端整数互转 —— `IOHelper`。
- 需要通过名称动态调用方法/读写属性，避免大量反射样板代码 —— `Reflect`。

## 核心原则

1. **安全转换不抛异常**：`ToInt`/`ToDouble`/`ToDateTime` 转换失败时返回默认值（可指定），调用侧无需 `try-catch`。
2. **空值安全**：`StringHelper` 所有方法对 `null` 输入均有正确处理，不会 `NullReferenceException`。
3. **路径统一用 `GetFullPath`**：相对路径基于 `PathHelper.BaseDirectory`（优先读命令行 `-BasePath` 参数），而非任意当前目录。
4. **反射用 `Reflect`，不用原生 API**：`Reflect` 内置缓存，多次调用性能优于每次 `GetMethod()`；支持忽略大小写匹配。
5. **字节序明确传参**：`IOHelper` 的 `ToUInt16`/`ToUInt32` 等默认小端序（`isLittleEndian = true`）；网络协议通常大端，需手动传 `false`。

## 执行步骤

### 一、类型安全转换（Utility）

```csharp
using NewLife;

// 整数转换（失败返回默认值，不抛异常）
int n = "123".ToInt();               // 123
int n2 = "abc".ToInt(-1);            // -1
int n3 = "1,234,567".ToInt();        // 1234567（自动去千分位）
int n4 = "１２３".ToInt();           // 123（全角数字）
long l = "99999999999".ToLong();

// 浮点转换
double d = "3.14".ToDouble();

// 布尔转换（"true"/"1"/"yes"/"on" → true）
bool b = "1".ToBoolean();            // true
bool b2 = "yes".ToBoolean();         // true
bool b3 = "off".ToBoolean();         // false

// 日期时间转换
DateTime dt = "2024-01-15 09:30".ToDateTime();
DateTime dt2 = "invalid".ToDateTime(DateTime.Now);  // 失败返回 DateTime.Now

// 日期格式化（空值保护）
string s = dt.ToFullString();              // "2024-01-15 09:30:00"
string s2 = DateTime.MinValue.ToFullString("N/A");  // "N/A"

// 数据大小可读格式（Bytes → KB/MB/GB）
string size = 1234567L.ToGMK();      // "1.18 MB"
```

### 二、字符串扩展（StringHelper）

```csharp
using NewLife;

// 空值判断
"".IsNullOrEmpty()                   // true
"  ".IsNullOrWhiteSpace()            // true

// 忽略大小写比较（支持可变参数，任意一个匹配返回 true）
"GET".EqualIgnoreCase("get")         // true
"GET".EqualIgnoreCase("post", "get") // true
"Hello".StartsWithIgnoreCase("hel")  // true
"config.json".EndsWithIgnoreCase(".JSON", ".xml")  // true

// 字符串拆分
string[] parts = "a,b,c".Split(",");               // ["a","b","c"]
int[] nums = "1,2,3".SplitAsInt();                 // [1,2,3]（跳过非数字项）
var dic = "key1=v1;key2=v2".SplitAsDictionary();   // {key1:v1, key2:v2}

// 枚举/集合 Join
string csv = new[] { 1, 2, 3 }.Join(",");          // "1,2,3"
string names = users.Join(", ", u => u.Name);

// 截取子字符串（最常用：按前后边界提取）
string val = "Name: Alice, Age: 30".Substring("Name: ", ",");  // "Alice"
string end = "prefix_content".Substring("prefix_");            // "content"

// 长度截断（超出时追加省略符）
string tip = longText.Cut(50, "...");

// 前后缀保证
"/api/users".EnsureStart("/")    // "/api/users"（已有不重复加）
"api/users".EnsureStart("/")     // "/api/users"

// TrimStart/TrimEnd 按字符串而非字符
"<p>text</p>".TrimStart("<p>").TrimEnd("</p>")  // "text"

// 字符串格式化（简写 String.Format）
"Hello, {0}!".F("World")        // "Hello, World!"

// 模糊搜索（Levenshtein 编辑距离）
var matched = StringHelper.LevenshteinSearch("smple", new[] { "simple", "sample", "example" });
// → ["sample", "simple"]（按相似度排序）
```

### 三、路径操作（PathHelper）

```csharp
using System.IO;

// 相对路径转绝对路径（基于 BaseDirectory，跨平台安全）
var fullPath = "config/app.json".GetFullPath();

// 专用基础路径（区分应用目录与数据目录）
var dataPath = "data/users.db".GetBasePath();   // 基于 BasePath（通过 -BasePath 参数设置）

// 合并路径（自动处理分隔符）
var file = "data".CombinePath("2024", "01", "log.txt");  // data/2024/01/log.txt

// 确保目录存在（isfile=true：取文件的父目录；false：将路径本身当目录）
"logs/2024/01/app.log".EnsureDirectory();      // 确保 logs/2024/01/ 存在
"logs/2024/01/".EnsureDirectory(false);        // 确保目录本身存在

// FileInfo / DirectoryInfo 快速创建
var fi = "config.json".AsFile();               // 等价于 new FileInfo("config.json".GetFullPath())
var di = "output".AsDirectory();

// 目录遍历（按扩展名过滤）
var csharpFiles = di.GetAllFiles("*.cs", allSub: true);

// 目录复制
di.CopyTo("backup/", exts: "*.xml;*.json", allSub: true);

// 文件哈希校验（格式：算法名$哈希值，如 "md5$abc123"）
bool ok = "app.exe".AsFile().VerifyHash("sha256$abc123def456...");
```

### 四、流与字节操作（IOHelper）

```csharp
using NewLife;

// 字节数组 ↔ 字符串
string text = bytes.ToStr();                       // UTF-8 解码（默认）
string text2 = bytes.ToStr(Encoding.ASCII);
byte[] data = stream.ReadBytes(1024);              // 从流读取指定字节数

// 整数 ↔ 字节（默认小端序）
ushort val16 = buf.ToUInt16(offset: 2);            // 从偏移 2 读取 2 字节
uint val32 = buf.ToUInt32(offset: 0, isLittleEndian: false);  // 大端（网络字节序）

// 字节写入整数
byte[] packet = new byte[4];
packet.Write(0xABCD1234u, offset: 0, isLittleEndian: false);

// 流操作
stream.Write(header, payload);                     // 连续写多个字节数组
byte[] arr = stream.ReadArray();                   // 读取 WriteArray 写入的长度前缀数组

// Deflate 压缩/解压（字节数组）
byte[] compressed = rawData.Compress();
byte[] original = compressed.Decompress();

// GZip 压缩（byte[]）
byte[] gz = rawData.CompressGZip();
byte[] restored = gz.DecompressGZip();

// 精确读取（不足字节数时抛出 EndOfStreamException）
byte[] exact = stream.ReadExactly(16);
```

### 五、高性能反射（Reflect）

```csharp
using NewLife.Reflection;

// 通过类型名获取 Type（自动搜索当前目录 DLL）
var type = "MyApp.Models.User".GetTypeEx();

// 创建实例（自动匹配构造函数参数）
var obj = type.CreateInstance("Alice", 30);

// 调用方法（忽略大小写，自动匹配参数）
obj.Invoke("Save");
obj.Invoke("UpdateEmail", "alice@example.com");

// 读写属性/字段（按名称，支持私有成员）
var name = obj.GetValue("Name");           // 读取
obj.SetValue("Email", "new@email.com");   // 写入

// 对象拷贝（浅拷贝，跳过指定字段）
target.Copy(source, excludes: "Id", "CreateTime");
target.Copy(dictionary);  // 从字典赋值

// 类型检查
typeof(List<String>).IsList()        // true
typeof(int?).IsNullable()            // true
typeof(double).IsNumber()            // true
typeof(long).IsInt()                 // true

// 子类查找
var impls = typeof(IPlugin).GetAllSubclasses();

// 类型兼容检查
typeof(MyClass).As(typeof(IDisposable))  // 是否实现接口
typeof(MyClass).As<IDisposable>()       // 泛型版本
```

## 重点检查项

- [ ] 类型转换是否使用了 `int.Parse()`（可能抛异常），而应换 `ToInt()` 加默认值保护？
- [ ] 字符串比较是否用了 `== "GET"` 而应该用 `.EqualIgnoreCase("get")`（HTTP method 等场景需忽略大小写）？
- [ ] 路径拼接是否用了 `Path.Combine` 后再手动处理，而应换 `CombinePath` 自动处理跨平台分隔符？
- [ ] `GetFullPath` 的基准目录是 `BaseDirectory`——是否在应用启动时通过命令行 `-BasePath` 正确配置了数据目录？
- [ ] `IOHelper.ToUInt32` 等字节序参数是否与对端协议（大端/小端）一致？
- [ ] 反射调用热路径是否有缓存（`Reflect` 内置缓存，但每次按名称查找仍有开销，极高频场景应缓存 `MethodInfo`）？

## 输出要求

- **类型转换**：`Utility`（`NewLife` 命名空间）—— `ToInt`/`ToLong`/`ToDouble`/`ToBoolean`/`ToDateTime`/`ToGMK`。
- **字符串**：`StringHelper`（`NewLife` 命名空间）—— 约 30 个扩展方法；`EqualIgnoreCase`/`Split`/`SplitAsInt`/`Join`/`Substring`/`Cut` 最常用。
- **路径**：`PathHelper`（`System.IO` 命名空间）—— `GetFullPath`/`GetBasePath`/`CombinePath`/`EnsureDirectory`/`AsFile`/`AsDirectory`。
- **流/字节**：`IOHelper`（`NewLife` 命名空间）—— 压缩解压、整数字节互转、精确读取。
- **反射**：`Reflect`（`NewLife.Reflection` 命名空间）—— `CreateInstance`/`Invoke`/`GetValue`/`SetValue`/`Copy`/`As`/`GetAllSubclasses`。

## 参考资料

参考示例与模式证据见 `references/newlife-utility-patterns.md`。
