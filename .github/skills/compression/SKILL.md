---
name: compression
description: >
  使用 NewLife.Core 内置的 TarFile（纯托管 tar/tar.gz 读写，无外部依赖）
  和 SevenZip（调用外部 7z.exe 支持 .7z/.zip/.rar 等更多格式）进行文件打包与解压。
  适用于部署包打包、日志归档、插件分发和自动更新等场景。
argument-hint: >
  说明你的场景：是打包目录为 tar.gz（TarFile，纯托管），
  还是需要 7z/zip/rar 格式（SevenZip）；是否需要流模式处理；
  是否在 Linux 容器中（无 7z.exe 时必须用 TarFile）。
---

# 压缩归档技能（TarFile + SevenZip）

## 适用场景

| 场景 | 推荐 |
|------|------|
| 纯 C# / 无外部依赖（Linux 容器、跨平台）| `TarFile`（.tar / .tar.gz / .tgz） |
| 需支持 .7z / .zip / .rar / .iso 等格式 | `SevenZip`（需 7z.exe） |
| 日志归档、部署包打包（跨平台）| `TarFile` |
| 极高压缩比冷备份 | `SevenZip`（.7z 格式） |
| 自动更新包下载并解压 | `SevenZip`（通用，有 7z.exe 时）|

## 核心原则

1. **`TarFile` 惰性枚举**：`Entries` 是流式惰性读取，**不能重复遍历**；需多次访问时先 `.ToList()` 缓存。
2. **`TarFile` 路径兼容**：`AddFile` 的 `entryName` 用正斜杠 `/` 分隔，保证跨平台解压正确。
3. **自动 GZip 包裹**：`TarFile` 构造时扩展名为 `.gz`/`.tgz` 自动包裹 `GZipStream`，无需手动处理压缩。
4. **`SevenZip.Compress/Extract` 是静态方法**：内部自动按优先级查找 `7z.exe`（当前目录 → Plugins/ → 7z/ → ../7z/ → 自动下载）。
5. **`TarFile` 使用 `using`**：写入模式下 `Dispose()` 才会 flush 并关闭流，忘记 `using` 会产生不完整归档。

## 执行步骤

### 一、TarFile — 打包目录为 tar.gz

```csharp
using NewLife.IO;

var releaseDir = @"d:\publish\MyApp";
var archive    = $"MyApp-{DateTime.Today:yyyyMMdd}.tar.gz";

using var tar = new TarFile(archive, isWrite: true);
foreach (var file in Directory.GetFiles(releaseDir, "*", SearchOption.AllDirectories))
{
    // 相对路径，正斜杠，保持跨平台兼容
    var entryName = Path.GetRelativePath(releaseDir, file).Replace('\\', '/');
    tar.AddFile(file, entryName);
}
// using 结束时自动 flush 并关闭
Console.WriteLine($"已打包: {archive}");
```

### 二、TarFile — 解压 tar.gz

```csharp
using NewLife.IO;

using var tar = new TarFile("release.tar.gz");   // 读取模式

// 惰性枚举，只能遍历一次！需要多次访问时 .ToList()
// var entries = tar.Entries.ToList();

foreach (var entry in tar.Entries)
{
    Console.WriteLine($"{entry.Name}  {entry.Size:#,0} 字节  {entry.LastModified:yyyy-MM-dd}");

    switch (entry.Type)
    {
        case TarEntryType.RegularFile:
            entry.ExtractTo(@"d:\deploy\");       // 自动还原相对路径
            break;
        case TarEntryType.Directory:
            Directory.CreateDirectory(Path.Combine(@"d:\deploy\", entry.Name));
            break;
        // TarEntryType.SymbolicLink / HardLink 等可根据需要处理
    }
}
```

### 三、TarFile — 从流读写

```csharp
// 写入到内存流（然后上传 / 发送）
using var ms = new MemoryStream();
using (var tar = new TarFile(ms, leaveOpen: true))
{
    tar.AddFile("./config.json", "config.json");
    tar.AddFile("./app.db",      "data/app.db");
}
ms.Position = 0;
await httpClient.PostAsync("/upload", new StreamContent(ms));

// 从网络流读取（不落盘）
using var responseStream = await httpClient.GetStreamAsync("/package.tar.gz");
using var tar2 = new TarFile(responseStream);
foreach (var entry in tar2.Entries)
{
    if (entry.Type == TarEntryType.RegularFile)
        entry.ExtractTo(@"d:\temp\");
}
```

### 四、SevenZip — 压缩

```csharp
using NewLife.IO;

// 压缩目录为 .7z（极高压缩比）
SevenZip.Compress(@"d:\logs\", @"d:\archive\logs-2025.7z");

// 压缩为 .zip（更通用，接收方无需 7z）
SevenZip.Compress(@"d:\data\report.xlsx", @"d:\archive\report.zip");

// overwrite=false 时目标已存在则跳过
SevenZip.Compress(@"d:\data\", @"d:\backup\data.zip", overwrite: false);
```

### 五、SevenZip — 解压

```csharp
// 解压到目标目录（不存在时自动创建）
SevenZip.Extract(@"d:\packages\plugin.7z", @"d:\app\plugins\");

// overwrite=false 时不覆盖已有文件
SevenZip.Extract(@"d:\backup\config.zip", @"d:\app\", overwrite: false);
```

### 六、自动更新场景

```csharp
// 下载更新包并解压覆盖
var tmpFile = Path.Combine(Path.GetTempPath(), "update.zip");

using var wc = new WebClientX { Timeout = 120_000 };
await wc.DownloadFileAsync(updateUrl, tmpFile);

SevenZip.Extract(tmpFile, AppDomain.CurrentDomain.BaseDirectory, overwrite: true);
File.Delete(tmpFile);
```

## 重点检查项

- [ ] `TarFile`（写入模式）是否使用了 `using`（`Dispose` 才会 flush，否则产生截断归档）？
- [ ] 遍历 `TarFile.Entries` 是否只访问一次（惰性流式，重复遍历会出错）？需多次遍历先 `.ToList()`。
- [ ] `TarFile.AddFile` 的 `entryName` 是否使用正斜杠 `/`（避免 Windows 路径分隔符在 Linux 解压出错）？
- [ ] 使用 `SevenZip` 的环境是否确认有 `7z.exe`（容器/Linux 环境默认无，需提前安装或使用 `TarFile` 代替）？
- [ ] `SevenZip.Extract` 的目标目录是否做了权限检查（写入操作，避免部署到只读目录）？

## 输出要求

- **纯托管 tar**：`TarFile`（`NewLife.IO`）—— 读写 `.tar`/`.tar.gz`/`.tgz`；`AddFile`/`Entries`/`ExtractTo`；`leaveOpen` 流复用。
- **多格式压缩**：`SevenZip`（`NewLife.IO`，静态类）—— `Compress(src, dest)`/`Extract(archive, dir)`；依赖外部 `7z.exe`。
- **TarEntryType**：`RegularFile`/`Directory`/`SymbolicLink`/`GNULongName` 等，解压时按类型处理。

## 参考资料

- `NewLife.Core/IO/TarFile.cs`
- `NewLife.Core/IO/SevenZip.cs`
- 相关技能：`utility-extensions`（`IOHelper.Compress`/`DecompressGZip` 用于单文件 GZip/Deflate）、`network-client`（`WebClientX.DownloadLinkAndExtract` 下载后自动解压）
