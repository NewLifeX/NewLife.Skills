---
name: benchmark-testing
description: 'Design BenchmarkDotNet benchmarks, choose test dimensions, run in release mode, and write concise data-driven performance reports. Use when measuring throughput, latency, allocations, or optimization impact.'
argument-hint: 'Provide the benchmark target, test dimensions, environment, and whether you need benchmark code, report structure, or result analysis.'
---

# 设计性能测试与报告

## 适用场景

当你要做性能测试、基准测试、吞吐量分析、内存分配分析或优化效果验证时，使用本技能。

适合：

- BenchmarkDotNet 基准测试
- 压测前的微基准验证
- 优化前后对比
- 性能报告整理

## 核心原则

- 数据先于结论
- Release 构建先于报告
- Benchmark 初始化与清理要从被测路径中分离
- 结果分析要提炼，不要重复抄表

## 执行步骤

1. 确定被测对象、测试维度和数据规模。
2. 使用 BenchmarkDotNet 组织基准测试，标注内存诊断和必要参数。
3. 初始化与清理分别放在专用阶段，不把准备工作混入被测方法。
4. 使用 Release 运行并保留原始结果。
5. 报告中先给结论，再给环境、结果、分析和优化建议。
6. 所有结论都必须回到真实数据，不能凭感觉写“显著提升”。

## 重点检查项

- 是否使用 Release 模式
- 是否避免在 `[Benchmark]` 中做初始化
- 是否覆盖单线程 / 多线程、单次 / 批量等关键维度
- 是否保留内存分配指标
- 是否用文字提炼对比，而不是重新造一张大表

## 输出要求

输出至少包含：

- 测试目标
- 测试环境
- Benchmark 结构建议
- 报告结构
- 瓶颈与优化建议写法

## 参考资料

- 参考 `references/report-template.md`
