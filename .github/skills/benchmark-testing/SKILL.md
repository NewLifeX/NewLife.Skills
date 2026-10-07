---
name: benchmark-testing
description: 'NewLife 项目性能测试：设计 BenchmarkDotNet 基准测试（Release 模式、GlobalSetup 分离、维度覆盖），输出数据驱动的性能报告。使用场景：吞吐量测量、延迟分析、内存分配分析、优化前后对比验证。'
argument-hint: '说明被测对象（类/方法）、测试维度（数据规模/并发/批大小）、对比基线（优化前版本/竞品）。'
---

# BenchmarkDotNet 性能测试

## 适用场景

- 测量关键路径的吞吐量、延迟、内存分配
- 优化前后对比，验证优化效果
- 与竞品或旧版本做基准对比
- 定位内存分配热点、GC 压力来源

## 开始前确认

- 被测对象（类/方法）
- 测试维度（数据规模 / 并发数 / 批大小）
- 对比基线（优化前版本 / 竞品）

## 核心原则

- **数据先于结论**：所有结论必须回到真实数据，不能凭感觉写"显著提升"
- **Release 构建先于报告**：绝对不在 Debug 模式下运行基准测试
- **初始化与清理从被测路径分离**：`GlobalSetup` / `GlobalCleanup` 不混入被测方法
- **结果分析要提炼**：不重复抄表，用文字提炼对比

## Benchmark 设计

### 基本结构

```csharp
[MemoryDiagnoser]
public class XxxBenchmark
{
    private Object? _data;

    [GlobalSetup]
    public void Setup() => _data = PrepareData();   // 初始化放专用阶段

    [Benchmark]
    public void MethodA() => Target.MethodA(_data);

    [Benchmark]
    public void MethodB() => Target.MethodB(_data);
}
```

### 设计检查项

- [ ] 使用 Release 模式运行
- [ ] `[Benchmark]` 方法内不含初始化逻辑
- [ ] 覆盖关键维度：单线程 / 多线程、单次 / 批量
- [ ] 保留内存分配指标（`[MemoryDiagnoser]`）
- [ ] 用文字提炼对比，不重复造大表

## 运行

```bash
dotnet run -c Release --project path/to/BenchmarkProject
```

- 必须使用 **Release** 模式
- 保留原始结果文件（`BenchmarkDotNet.Artifacts/`）
- 避免开发机后台运行其他负载干扰结果

## 结果分析

提取关键指标：

| 指标 | 含义 |
|------|------|
| Mean | 平均耗时 |
| Allocated | 内存分配 |
| Gen0/Gen1/Gen2 Collections | GC 压力 |

- 计算优化前后的百分比变化
- 异常结果（方差过大、异常值）需说明原因

## 报告模板

```markdown
# 性能测试报告

## 测试目标
{一句话说明测试目的}

## 测试环境
- OS: {操作系统}
- CPU: {处理器型号}
- .NET 版本: {运行时版本}
- BenchmarkDotNet 版本: {vX.Y.Z}

## 测试结果

| 方法 | Mean | Error | StdDev | Gen0 | Gen1 | Allocated |
|------|------|-------|--------|------|------|-----------|
| {方法A} | {值} | {值} | {值} | {值} | {值} | {值} |

## 分析
{关键发现和结论}

## 优化建议
{具体的优化方向}
```
