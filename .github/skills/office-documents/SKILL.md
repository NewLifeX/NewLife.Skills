---
name: office-documents
description: >
  使用 NewLife.Office 生成和读取 Office 文档，涵盖 Excel（ExcelWriter/ExcelReader/ExcelTemplate/BiffReader）、
  Word（WordWriter/WordReader/WordTemplate/WordHtmlConverter）、
  PowerPoint（PptxWriter/PptxReader）、PDF（PdfFluentDocument/PdfWriter）、
  Markdown（MarkdownParser/MarkdownWriter），以及 RTF/ODS/EML/iCalendar/vCard/EPUB 等格式。
  零第三方依赖，仅依赖 NewLife.Core，适用于报表生成、文档导出、模板填充等场景。
argument-hint: >
  说明你的文档场景：生成还是读取；文件格式（Excel/Word/PPT/PDF）；
  是否需要模板填充（{{Key}} 占位符）；是否需要转换（Word→HTML/PDF）；
  是否需要样式、图片、表格等高级元素。
---

# Office 文档生成与处理技能（NewLife.Office）

## 适用场景

- 服务端动态生成 Excel 报表（数据导出、财务报告）并提供下载。
- 基于 Word 模板生成合同、通知函等个性化文档（`{{Key}}` 占位符替换）。
- 生成 PDF 报告（发票、报告单、处方）支持页眉/页脚/书签/密码保护。
- 读取上传的 xls/xlsx/docx/pptx，提取文字内容做分析处理。
- 在服务端（无 Office/COM 依赖）做高性能文档操作，免除 Interop 许可问题。

## 核心原则

1. **`ExcelWriter` 和 `WordWriter` 必须 `Dispose`**：两者内部持有 OpenXML 文件流；不调用 `Dispose`/`using` 会导致文件流未刷新、zip 包损坏，生成的文件无法打开。
2. **模板占位符 `{{Key}}` 保留原有样式**：`ExcelTemplate`/`WordTemplate`/`PptxTemplate` 在替换时保留单元格格式、字体、颜色；手动修改模板文件样式比代码设置样式更高效。
3. **`PdfFluentDocument` 是链式 API，强于 `PdfWriter`**：`PdfFluentDocument` 管理页面布局（自动换页、当前 Y 坐标、页眉页脚），适合报告/发票场景；`PdfWriter` 是低级绝对坐标 API，适合精确排版。
4. **`BiffReader` 读取旧 `.xls` 格式**：解析 BIFF8/OLE2 容器（Excel 97-2003），只能读取不能写入；现代 xlsx 用 `ExcelReader`。
5. **中文 PDF 需要显式创建中文字体**：`.NET` 的 PDF 实现默认不含中文字体；`PdfWriter.CreateSimplifiedChineseFont()` 内置宋体嵌入，必须在 `DrawText` 前设置字体，否则中文字符丢失。
6. **`ExcelWriter.WriteObjects<T>` 自动映射属性**：通过反射读取公共属性名作为列标题，属性值作为行数据，适合快速导出实体列表；列顺序默认与属性声明顺序一致。

## 执行步骤

### 一、Excel 写入（生成报表）

```csharp
using NewLife.Office;

// 基础行写入
using var writer = new ExcelWriter("report.xlsx");

// 写入表头（指定工作表名）
writer.WriteHeader("销售数据", new[] { "订单号", "金额", "日期", "状态" });

// 逐行写入
writer.WriteRow("销售数据", new Object[] { "ORD-001", 1250.00, DateTime.Today, "已付款" });

// 批量写入（推荐，适合大数据量）
var rows = orders.Select(o => new Object[] { o.Id, o.Amount, o.Date, o.Status });
writer.WriteRows("销售数据", rows);

// 自动映射实体类属性
writer.WriteObjects("订单列表", orders);   // Order 类的公共属性自动变为列

// 设置列宽
writer.SetColumnWidth("销售数据", colIndex: 1, width: 15.0);
// 冻结首行（表头）
writer.FreezePane("销售数据", freezeRowCount: 1);
// 自动筛选
writer.SetAutoFilter("销售数据", range: "A1:D1");

writer.Save();  // 保存到构造时指定的路径
// 或：writer.Save(stream); 写入输出流（用于 HTTP 响应）
```

### 二、Excel 读取

```csharp
using var reader = new ExcelReader("upload.xlsx");

// 获取所有工作表名
var sheets = reader.Sheets;

// 逐行读取（懒加载，节省内存）
foreach (var row in reader.ReadRows("Sheet1"))
{
    var orderId = row[0]?.ToString();
    var amount  = Convert.ToDecimal(row[1]);
}

// 映射到实体类（按列名映射）
var orders = reader.ReadObjects<Order>("销售数据").ToList();

// 读取为 DataTable（与旧代码数据绑定兼容）
var dt = reader.ReadDataTable("Sheet1");
```

### 三、Excel 模板填充

```csharp
// 模板文件中使用 {{Key}} 占位符（如 {{CompanyName}}、{{Total}}）
var template = new ExcelTemplate("template/invoice-template.xlsx");

template.Fill("output/invoice-001.xlsx", new Dictionary<String, Object>
{
    ["CompanyName"] = "北京科技有限公司",
    ["InvoiceDate"] = DateTime.Today.ToString("yyyy年MM月dd日"),
    ["Total"]       = 12500.00m,
    ["Items"]       = itemList,   // 列表类型自动展开为多行
});
```

### 四、Excel 高级功能

```csharp
// 添加数据验证（下拉列表）
writer.AddDropdownValidation("Sheet1", "C2:C100", new[] { "待处理", "进行中", "已完成" });

// 条件格式（超过阈值变红）
writer.AddConditionalFormat("Sheet1", "B2:B100",
    ConditionalFormatType.GreaterThan, value: "10000", color: "#FF0000");

// 插入图片
var imageBytes = File.ReadAllBytes("logo.png");
writer.AddImage("封面", row: 1, col: 1, imageBytes, "png", width: 120, height: 60);

// 超链接
writer.AddHyperlink("说明", row: 1, col: 5, url: "https://docs.example.com", display: "查看文档");

// 页面设置（A4 横向，用于宽表格打印）
writer.SetPageSetup("销售数据", PageOrientation.Landscape, PaperSize.A4);
writer.SetHeaderFooter("销售数据", header: "公司内部报告", footer: "页码：&P/&N");

// 工作表保护密码
writer.ProtectSheet("敏感数据", password: "123456");
```

### 五、Word 写入（生成合同/通知）

```csharp
using var word = new WordWriter("contract.docx");

// 设置文档属性
word.DocumentProperties.Title  = "服务合同";
word.DocumentProperties.Author = "北京科技有限公司";

// 写入标题和正文
word.AppendHeading("服务合同", level: 1);
word.AppendParagraph($"合同编号：{contractId}", WordParagraphStyle.Normal);
word.AppendParagraph("");  // 空行

// 格式化段落（混合样式）
word.AppendFormattedParagraph(new[]
{
    new WordRun("甲方：", bold: true),
    new WordRun("北京科技有限公司"),
}, WordParagraphStyle.Normal);

// 插入表格
var table = word.AppendTable(rows: 5, cols: 3);
table.SetCell(0, 0, "服务项目");
table.SetCell(0, 1, "单价");
table.SetCell(0, 2, "数量");

// 插入图片
var imgBytes = File.ReadAllBytes("signature.png");
word.AppendImage(imgBytes, "png", widthCm: 5.0, heightCm: 2.0);

// 页眉页脚
word.SetPageHeader("机密文件");
word.SetPageFooter($"生成时间：{DateTime.Now:yyyy-MM-dd HH:mm}");

word.Save("output/contract.docx");
```

### 六、Word 模板填充

```csharp
// Word 模板中使用 {{FieldName}} 占位符
var template = new WordTemplate("templates/contract-template.docx");
template.Fill("output/contract-001.docx", new Dictionary<String, Object>
{
    ["PartyA"]        = "北京科技有限公司",
    ["PartyB"]        = "上海贸易有限公司",
    ["ContractDate"]  = "2024年3月15日",
    ["Amount"]        = "¥ 120,000.00",
});
```

### 七、Word 读取与转换

```csharp
// 读取 docx 文本内容
using var wordReader = new WordReader("document.docx");
var fullText = wordReader.ReadFullText();   // 全文文本
var paragraphs = wordReader.ReadParagraphs().ToList();  // 逐段
var tables = wordReader.ReadTables().ToList();           // 表格（二维数组）

// 转换为 HTML
var converter = new WordHtmlConverter();
var html = converter.ToHtml("document.docx");

// 转换为 PDF
var pdfConverter = new WordPdfConverter();
pdfConverter.ToPdf("document.docx", "output.pdf");
```

### 八、PDF 生成（Fluent API）

```csharp
using var doc = new PdfFluentDocument();
doc.Title            = "销售月报";
doc.Author           = "财务部";
doc.Header           = "Confidential";
doc.Footer           = "公司内部文件";
doc.ShowPageNumbers  = true;

// 中文字体（必须设置，否则中文乱码）
var font = doc.CreateChineseFont(fontSize: 12);

doc
    .AddText("2024年3月 销售月报", fontSize: 20, font: font)
    .AddEmptyLine()
    .AddText($"制表日期：{DateTime.Today:yyyy年MM月dd日}", fontSize: 10, font: font)
    .AddEmptyLine()
    .AddTable(tableRows, firstRowHeader: true)
    .AddEmptyLine()
    .AddText("附件图表", fontSize: 14, font: font)
    .AddImage(chartImageBytes, width: 400, height: 250)
    .PageBreak()
    .AddText("说明与备注", fontSize: 14, font: font)
    .AddText(remarkText, font: font);

doc.Save("sales-report.pdf");
```

### 九、PPT 生成

```csharp
using var ppt = new PptxWriter("presentation.pptx");

// 添加幻灯片
var slide1 = ppt.AddSlide();

// 标题文本框（EMU 单位：914400 EMU = 1 英寸 = 2.54 cm）
ppt.AddTextBox(0, "季度业绩报告",
    leftCm: 2, topCm: 2, widthCm: 22, heightCm: 3,
    fontSize: 36, bold: true);

// 数据表格
ppt.AddTable(0,
    rows: new[] { new[] { "项目", "目标", "实际", "完成率" }, ... },
    leftCm: 1, topCm: 6, widthCm: 22);

// 插入图片
ppt.AddImage(0, chartBytes, "png",
    leftCm: 1, topCm: 12, widthCm: 10, heightCm: 7);

// 设置幻灯片背景色
ppt.SetBackground(0, "#F5F5F5");

ppt.Save("output/presentation.pptx");
```

## 格式支持速查

| 格式 | 读取 | 写入 | 模板 | 核心类 |
|------|:----:|:----:|:----:|--------|
| xlsx | ✓ | ✓ | ✓ | `ExcelWriter`/`ExcelReader`/`ExcelTemplate` |
| xls | ✓ | — | — | `BiffReader` |
| docx | ✓ | ✓ | ✓ | `WordWriter`/`WordReader`/`WordTemplate` |
| doc | ✓(文本) | — | — | `DocReader` |
| pptx | ✓ | ✓ | ✓ | `PptxWriter`/`PptxReader` |
| PDF | ✓ | ✓ | — | `PdfFluentDocument`/`PdfWriter`/`PdfReader` |
| Markdown | ✓ | ✓ | — | `MarkdownParser`/`MarkdownWriter` |
| RTF | ✓ | ✓ | ✓ | `RtfReader`/`RtfWriter` |
| ODS | ✓ | ✓ | — | `OdsReader`/`OdsWriter` |
| EML | ✓ | ✓ | — | `EmlReader`/`EmlWriter` |
| iCalendar | ✓ | ✓ | — | `ICalReader`/`ICalWriter` |
| vCard | ✓ | ✓ | — | `VCardReader`/`VCardWriter` |
| EPUB | ✓ | ✓ | — | `EpubReader`/`EpubWriter` |

## 常见错误与注意事项

- **忘记 `Dispose`/`using`**：`ExcelWriter`/`WordWriter` 等持有文件流，不 `Dispose` 生成的文件是不完整的 zip 包，打开时报"文件损坏"。
- **中文 PDF 不设置字体**：默认 PDF 字体不含中文，不调用 `CreateSimplifiedChineseFont()` 则中文字符完全丢失（显示为方块或空白）。
- **模板占位符大小写**：`{{CompanyName}}` 和 `{{companyname}}` 是不同的 key，`Dictionary<String, Object>` 的默认比较是大小写敏感的。
- **`BiffReader` 只读不写**：旧 `.xls` 格式只支持读取；如需生成旧版 Excel，建议生成 `.xlsx` 后建议用户另存，或用 LibreOffice 服务转换。
- **`PdfFluentDocument.AddTable` 超宽会截断**：表格宽度由 `ContentWidth`（页面宽度减去左右边距）决定；列数过多时内容可能被截断，应减少列数或用横向纵向页面。
- **`WriteObjects<T>` 忽略无公共 getter 的属性**：仅映射有公开 `get` 访问器的属性；计算属性/内部属性不会出现在导出列中，若需要则手动指定列映射。
