---
name: data-file-formats
description: >
  使用 NewLife.Core 读写结构化数据文件：CsvFile（RFC4180 流式 CSV 读写）、
  ExcelReader（轻量级 xlsx 导入，无需第三方组件）、DbTable（内存数据表，支持二进制/JSON/CSV序列化）。
  适用于数据导入导出、批量 Excel 读取、跨格式数据交换等场景。
argument-hint: >
  说明你的场景：读取还是写入 CSV；导入 Excel（.xlsx）；
  还是在内存中操作行列数据集（DbTable）并序列化为二进制/JSON/CSV。
  是否需要超大文件流式处理、异步读取、或与数据库查询结果对接。
---

# 数据文件格式技能（CsvFile + ExcelReader + DbTable）

## 适用场景

- **`CsvFile`**：超大 CSV 流式逐行读取（不把整个文件加载进内存）；正确处理含逗号/换行/双引号的 RFC4180 字段；导出时自动转义；支持自定义分隔符（Tab 分隔）。
- **`ExcelReader`**：服务端/无界面环境批量导入 `.xlsx`，不依赖 COM/Office/Interop；只需逐行读取数据，不需要公式计算、合并单元格等高级特性。
- **`DbTable`**：承载数据库查询结果（从 `IDataReader` 读取）；在内存中做多次遍历/筛选；序列化为二进制（高效，可压缩）/JSON/XML/CSV；与模型列表相互映射。
- 代码审查：确认 `CsvFile`/`ExcelReader` 使用 `using` 确保流关闭；`DbTable` 序列化为二进制时 `Types` 数组必须与 `Columns` 对齐。

## 核心原则

1. **`CsvFile` 是 RFC4180 兼容的流式读写器**：`ReadLine()` 返回 `null` 表示 EOF；`WriteLine()` 自动转义含分隔符/换行/引号的字段；大数字（>9位整数）自动加 `\t` 前缀防 Excel 科学计数。
2. **`ExcelReader` 只读 xlsx**：本质是解析 OpenXML zip，不支持 xls/宏/公式；`ReadRows()` 自动补齐缺失列（跳列补 `null`）；`sheet=null` 取第一个工作表。
3. **`DbTable` 需要 `Types` 才能做二进制序列化**：列名 `Columns` + 列类型 `Types` + 行数据 `Rows` 三者需同步维护；`Read(IDataReader)` 会自动填充三者。
4. **超大文件用流式 API**：`CsvFile.ReadAll()` / `ReadAllAsync()` 是懒惰迭代器，不把整个文件加载内存；`ExcelReader.ReadRows()` 同理。

## 执行步骤

### 一、CsvFile — 读取 CSV

```csharp
using NewLife.IO;

// 从文件读取（流式，逐行）
using var csv = new CsvFile("./data.csv");

// 方式1：while 循环（推荐，EOF 返回 null）
while (true)
{
    var row = csv.ReadLine();
    if (row == null) break;
    // row 是 String[] 字段数组
    Console.WriteLine($"Id={row[0]}, Name={row[1]}");
}

// 方式2：枚举（LINQ 友好）
foreach (var row in csv.ReadAll())
{
    ProcessRow(row);
}

// 方式3：异步（.NET 5+）
await foreach (var row in csv.ReadAllAsync())
{
    await ProcessRowAsync(row);
}
```

#### 自定义分隔符（Tab 分隔）

```csharp
using var csv = new CsvFile(stream, leaveOpen: true)
{
    Separator = '\t',
    Encoding  = Encoding.UTF8,
};
```

### 二、CsvFile — 写入 CSV

```csharp
using NewLife.IO;

// 写入文件（write=true）
using var csv = new CsvFile("./out.csv", write: true);

// 写表头
csv.WriteLine(new[] { "Id", "Name", "CreatedAt" });

// 写数据行（自动处理 Boolean → 1/0、DateTime → 标准格式、含逗号字段自动加引号）
csv.WriteLine(new object[] { 1, "张三", DateTime.Now });
csv.WriteLine(new object[] { 2, "带,逗号的名字", DateTime.Today });

// 批量写入
csv.WriteAll(dataRows.Select(r => new object[] { r.Id, r.Name, r.CreatedAt }));
```

### 三、ExcelReader — 读取 xlsx

```csharp
using NewLife.IO;

// 从文件读取（始终 using，确保流关闭）
using var excel = new ExcelReader("./import.xlsx");

// 查看工作表列表
var sheets = excel.Sheets;  // ICollection<String>

// 读取第一个工作表（sheet=null 默认第一个）
var rows = excel.ReadRows().ToList();   // List<Object?[]>

// 第一行通常是表头
var header = rows[0];    // ["Id", "Name", "Price", ...]

// 逐行处理数据（跳过表头）
foreach (var row in rows.Skip(1))
{
    var id    = (int?)row[0] ?? 0;
    var name  = (string?)row[1] ?? "";
    var price = Convert.ToDecimal(row[2] ?? 0);
}

// 指定工作表
foreach (var row in excel.ReadRows("Sheet2"))
{
    ProcessRow(row);
}

// 从流读取（如 HTTP 上传）
using var excel2 = new ExcelReader(uploadStream, Encoding.UTF8);
```

#### 类型转换说明

`ExcelReader` 自动将单元格解析为：

| Excel 格式 | .NET 类型 |
|-----------|---------|
| 数字（无格式） | `Int32`/`Int64`/`Double`/`Decimal` |
| 日期格式数字 | `DateTime` |
| 时间格式数字 | `TimeSpan` |
| 布尔 | `Boolean` |
| 共享字符串 | `String` |
| 空 / 缺失列 | `null` |

### 四、DbTable — 内存数据表

```csharp
using NewLife.Data;

// 方式1：从数据库读取（自动填充 Columns/Types/Rows）
var table = new DbTable();
using var dr = cmd.ExecuteReader();
table.Read(dr);
// 或异步
await table.ReadAsync(dr);

// 方式2：手动构建
var table = new DbTable
{
    Columns = new[] { "Id", "Name", "Active" },
    Types   = new[] { typeof(int), typeof(string), typeof(bool) },
    Rows    = new List<object?[]>
    {
        new object?[] { 1, "张三", true  },
        new object?[] { 2, "李四", false },
    },
    Total = 2,
};

// 遍历
foreach (var row in table)
{
    var id   = (int?)row["Id"] ?? 0;
    var name = (string?)row["Name"] ?? "";
}

// 转换为模型列表
var users = table.ReadModels<User>().ToList();

// 序列化为 JSON
var json = table.ToJson();

// 序列化为二进制（高效，需 Types 正确）
var data = table.ToPacket();

// 从二进制反序列化
var table2 = new DbTable();
table2.Read(data);
```

### 五、CsvFile + DbTable 联合使用

```csharp
// 从 CSV 读取到 DbTable
var table = new DbTable
{
    Columns = new[] { "Id", "Name", "Amount" },
    Types   = new[] { typeof(int), typeof(string), typeof(decimal) },
};
using var csv = new CsvFile("./data.csv");
csv.ReadLine();  // 跳过表头
while (csv.ReadLine() is { } row)
{
    table.Rows.Add(new object?[] { row[0].ToInt(), row[1], row[2].ToDouble() });
}

// 从 DbTable 写出 CSV
using var csv2 = new CsvFile("./out.csv", write: true);
csv2.WriteLine(table.Columns);
table.WriteAll(csv2);
```

## 重点检查项

- [ ] `CsvFile` 是否使用 `using` 确保 `Dispose()` 调用（`_writer?.Flush()` 会在 Dispose 中执行）？
- [ ] 写入 `CsvFile` 时是否依赖自动转义（不要手动拼装含逗号/换行的字段字符串）？
- [ ] `ExcelReader` 是否使用 `using` 确保 zip 文件句柄释放？
- [ ] `ExcelReader` 读取结果中是否对 `null` 列做了空值保护（跳列/缺失单元格返回 `null`）？
- [ ] `DbTable` 在做二进制序列化/反序列化时 `Types` 是否与 `Columns` 对齐（缺 `Types` 会导致序列化出错）？
- [ ] `DbTable.Total` 是否在手动构建后设置为正确值（二进制协议中 `Total` 用于记录总条数）？

## 输出要求

- **CSV**：`CsvFile`（`NewLife.IO`）—— `ReadLine()`/`ReadAll()`/`ReadAllAsync()`；`WriteLine()`/`WriteAll()`；`Separator`/`Encoding`。
- **Excel**：`ExcelReader`（`NewLife.IO`）—— `ReadRows(sheet?)`；自动类型转换；仅支持 xlsx。
- **内存数据表**：`DbTable`（`NewLife.Data`）—— `Read(IDataReader)`；`ReadModels<T>()`；`ToJson()`/`ToPacket()`；`Columns`/`Types`/`Rows`/`Total`。

## 参考资料

- `NewLife.Core/IO/CsvFile.cs`
- `NewLife.Core/IO/ExcelReader.cs`
- `NewLife.Core/Data/DbTable.cs`
