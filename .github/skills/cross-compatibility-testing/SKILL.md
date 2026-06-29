---
name: cross-compatibility-testing
description: '协议/通信/编解码/文件格式类项目的竞品交叉兼容测试：我写你读、你写我读、我写我读等多模式对比验证。使用场景：项目涉及文件格式读写、网络协议通信、音视频编解码等需要与竞品互操作验证的场景。'
argument-hint: '说明项目类型（文件格式/网络协议/编解码）、涉及的竞品、需要验证的互操作方向。'
---

# 竞品交叉兼容测试

## 适用场景

- 文件格式类项目（Excel/Word/PDF/图片/音视频容器等）
- 网络协议类项目（IoT 通信/IM 协议/自定义 TCP 协议等）
- 编解码类项目（音视频编解码/压缩/加密等）
- 任何需要证明"我的实现与行业标准/竞品兼容"的场景

## 核心原则

- **交叉验证是最高置信度的兼容性证明**：自说自话通过 ≠ 和竞品互通
- **4 种角色排列组合**：我/竞品 × 写入/读取（或 客户端/服务端、编码/解码）
- **验证标准因场景而异**：文件格式允许可观差异，网络协议要求精确兼容
- **竞品作为测试 Oracle**：竞品的行为就是"正确答案"，不需要手动构造预期值

## 交叉测试模式矩阵

### 文件格式

| 编号 | 模式 | 操作 | 验证标准 |
|------|------|------|---------|
| F1 | 我写你读 | 我的 Writer 写入文件 → 竞品 Reader 读取 | 竞品能正确解析字段值，无报错 |
| F2 | 你写我读 | 竞品 Writer 写入文件 → 我的 Reader 读取 | 我能正确解析竞品生成的文件 |
| F3 | 我写我读 | 我的 Writer 写入 → 我的 Reader 读取 | 自校验：写出的字段能完整读回 |
| F4 | 你写你读 | 竞品 Writer 写入 → 竞品 Reader 读取 | 基线：确认竞品自身一致性 |

**验证标准**：
- 文件格式：双方读写结果**高度一致**（允许少量可观变化——如 XML 属性顺序、空白节点、默认值省略，但不影响文件内容语义）
- 我写我读：写入后读回的字段值**与原值完全一致**
- 你写你读：作为基线参考，确认竞品自身行为

### 网络协议

| 编号 | 模式 | 操作 | 验证标准 |
|------|------|------|---------|
| N1 | 我→你 | 我的客户端 → 竞品服务端 | 竞品服务端正确解析我的请求并返回有效响应 |
| N2 | 你→我 | 竞品客户端 → 我的服务端 | 我的服务端正确解析竞品请求并返回竞品可接受的响应 |
| N3 | 我→我 | 我的客户端 → 我的服务端 | 自通信：请求-响应完整闭环 |
| N4 | 你→你 | 竞品客户端 → 竞品服务端 | 基线：确认竞品协议行为 |

**验证标准**：
- 网络协议：客户端服务端**精确兼容**（字节级一致或语义等价）
- 所有字段必须能正确序列化/反序列化
- 异常路径（超时、断连、畸形包）行为一致

### 编解码

| 编号 | 模式 | 操作 | 验证标准 |
|------|------|------|---------|
| C1 | 我编你解 | 我的编码器 → 竞品解码器 | 竞品能正确解码并还原原始数据 |
| C2 | 你编我解 | 竞品编码器 → 我的解码器 | 我能正确解码竞品编码的数据 |
| C3 | 我编我解 | 我的编码器 → 我的解码器 | 自校验：编码后解码还原原始数据 |
| C4 | 你编你解 | 竞品编码器 → 竞品解码器 | 基线：确认竞品编解码行为 |

**验证标准**：
- 有损编解码（音视频）：输出**语义等价**（PSNR/SSIM 在可接受范围）
- 无损编解码（压缩/加密）：输出**比特级一致**

## 执行步骤

### 1. 判断项目类型与适用模式

根据项目特征自动判断适用的交叉测试模式：

| 项目特征 | 项目类型 | 适用模式 |
|----------|---------|---------|
| 读写文件、操作文档格式 | 文件格式 | F1-F4 |
| 监听端口、建立连接、收发数据包 | 网络协议 | N1-N4 |
| 数据编码/解码、压缩/解压 | 编解码 | C1-C4 |
| 同时涉及上述多种 | 混合型 | 组合适用模式 |

### 2. 引入竞品依赖

在 `XUnitTest` 项目中引入竞品 NuGet 包作为测试依赖：

```xml
<!-- 测试项目中引用竞品包（仅用于交叉验证） -->
<PackageReference Include="NPOI" Version="2.*" />
<PackageReference Include="ClosedXML" Version="0.*" />
```

**注意**：
- 竞品依赖仅用于测试项目，不污染生产代码
- 注意竞品许可证是否允许在测试中使用
- 竞品版本锁定主版本，避免 CI 中意外升级

### 3. 编写交叉测试用例

**文件格式交叉测试模板**：

```csharp
public class ExcelCrossCompatibilityTests
{
    [Fact]
    [DisplayName("F1-我写你读_NPOI能正确读取NewLife.Office生成的xlsx")]
    public void F1_MyWrite_YourRead_NPOI_Reads_Our_Xlsx()
    {
        // 1. 使用我的 Writer 生成文件
        var tempFile = Path.GetTempFileName() + ".xlsx";
        using var writer = new ExcelWriter();
        writer.AddSheet("Sheet1");
        writer.SetCell(0, 0, "Hello");
        writer.SetCell(0, 1, 12345);
        writer.Save(tempFile);

        // 2. 使用竞品 NPOI 读取
        using var fs = File.OpenRead(tempFile);
        var workbook = new XSSFWorkbook(fs);
        var sheet = workbook.GetSheetAt(0);
        var row = sheet.GetRow(0);

        // 3. 验证竞品读取结果
        Assert.Equal("Hello", row.GetCell(0).StringCellValue);
        Assert.Equal(12345, row.GetCell(1).NumericCellValue, 0);

        File.Delete(tempFile);
    }

    [Fact]
    [DisplayName("F2-你写我读_NewLife.Office能正确读取NPOI生成的xlsx")]
    public void F2_YourWrite_MyRead_We_Read_NPOI_Xlsx()
    {
        // 1. 使用竞品 NPOI 生成文件
        var tempFile = Path.GetTempFileName() + ".xlsx";
        var workbook = new XSSFWorkbook();
        var sheet = workbook.CreateSheet("Sheet1");
        var row = sheet.CreateRow(0);
        row.CreateCell(0).SetCellValue("World");
        row.CreateCell(1).SetCellValue(67890);
        using var fs = File.Create(tempFile);
        workbook.Write(fs, leaveOpen: false);

        // 2. 使用我的 Reader 读取
        using var reader = new ExcelReader();
        reader.Open(tempFile);
        var cell00 = reader.GetCell(0, 0);
        var cell01 = reader.GetCell(0, 1);

        // 3. 验证我能正确解析
        Assert.Equal("World", cell00);
        Assert.Equal(67890, (Int32)(Double)cell01);

        File.Delete(tempFile);
    }
}
```

**网络协议交叉测试模板**：

```csharp
public class MqttCrossCompatibilityTests
{
    [Fact]
    [DisplayName("N2-你写我读_MQTTnet客户端能连接我的MQTT服务端")]
    public async Task N2_YourClient_MyServer_MQTTnet_Connects()
    {
        // 1. 启动我的服务端（随机端口）
        var port = 0; // 随机端口
        using var server = new MqttServer();
        server.Start(port);
        var actualPort = server.Port;

        // 2. 竞品 MQTTnet 客户端连接
        var factory = new MqttFactory();
        using var client = factory.CreateMqttClient();
        var options = new MqttClientOptionsBuilder()
            .WithTcpServer("localhost", actualPort)
            .Build();

        var result = await client.ConnectAsync(options);

        // 3. 验证连接成功
        Assert.Equal(MqttClientConnectResultCode.Success, result.ResultCode);
    }
}
```

### 4. 验证与判定

| 场景 | 通过标准 | 不通过处理 |
|------|---------|-----------|
| 文件格式 F1/F2 | 竞品能解析，关键字段值一致 | 分析 XML/二进制差异，修复兼容性 |
| 文件格式 F3 | 自校验字段完整读回 | 纯 bug，直接修复 |
| 网络协议 N1/N2 | 双方能完成完整的请求-响应循环 | 抓包对比协议帧差异 |
| 网络协议 N3 | 自通信无异常 | 纯 bug，直接修复 |
| 编解码 C1/C2 | 解码输出与原始输入一致（或误差在阈值内） | 分析编解码参数差异 |
| 基线 F4/N4/C4 | 竞品自身一致 | 若基线都不通过，说明测试用例有问题 |

## 测试用例设计指南

### AI 应根据项目类型自动生成测试矩阵

当用户要求为某个项目创建交叉测试时，AI 应：

1. **识别项目类型**（文件格式 / 网络协议 / 编解码 / 混合）
2. **列出适用的交叉模式**（从矩阵中选取）
3. **识别相关竞品**（从竞品分析报告中提取，或联网搜索）
4. **为每种模式 × 每个竞品** 创建至少一个测试用例
5. **覆盖关键功能维度**（不是每个功能都要交叉测试，选核心/差异大的功能）

### 测试用例优先级

| 优先级 | 模式 | 说明 |
|--------|------|------|
| 🔴 高 | F2/N2/C2（你写我读） | **最关键**——证明我能兼容业界标准 |
| 🔴 高 | F3/N3/C3（我写我读） | **基础门禁**——自己都不通别谈兼容 |
| 🟡 中 | F1/N1/C1（我写你读） | 证明我的输出能被业界接受 |
| 🟢 低 | F4/N4/C4（你写你读） | 基线参考，帮助定位问题归属 |

## 注意事项

- 交叉测试是集成测试的子集，放在 `XUnitTest` 项目的对应子目录中
- 使用 `[Trait("Category", "CrossCompatibility")]` 分类，便于 CI 按需运行
- 竞品 NuGet 包版本升级后需重新验证交叉测试
- 竞品本身有 bug 时，在测试中注释说明（防御性注释），不作为我方失败
- 文件路径统一使用 `Path.GetTempFileName()` + 正确扩展名
