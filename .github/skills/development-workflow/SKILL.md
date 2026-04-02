---
name: development-workflow
description: 'Guide requirement clarification, feature slicing, technical design, task breakdown, iterative implementation, validation, and acceptance. Use when a request is larger than a single coding step.'
argument-hint: 'Provide the project goal, current stage if known, and whether you want normal step-by-step delivery or batched execution.'
---

# 规划研发工作流

## 适用场景

当任务不是一个单点小改，而是一个系统、模块、子项目、较大功能或多阶段需求时，使用本技能建立可执行工作流。

适合：

- 新建系统或新模块
- 整理需求并输出文档
- 架构设计与任务拆解
- 多轮迭代开发
- 验收与回顾
- 进入批处理/自治式开发前的规划

## 核心原则

- 先明确需求，再做设计，再进入编码
- 大需求必须拆小，每轮只交付可验证的最小单元
- 功能拆分按用户价值和端到端路径，而不是按技术层硬切
- 每个任务都要有完成标准与验证方式

## 推荐阶段

1. 需求整理
2. 需求评审与拆分
3. 技术方案设计
4. 任务分解
5. 迭代开发
6. 集成验证
7. 验收与回顾

## 执行步骤

1. 判断用户当前所处阶段；若未说明，默认从需求整理开始。
2. 把原始描述转成结构化需求：背景、角色、功能、验收条件、非功能约束。
3. 把功能拆成可交付的纵向切片，并标注优先级与依赖。
4. 输出技术方案：架构概览、数据模型、接口、关键决策、风险。
5. 把技术方案继续拆成单轮可执行任务，每项任务都要写明输入、产出、验收。
6. 进入开发时按任务顺序实施，并在每轮完成后进行编译、测试、用户确认。
7. 最后对照需求逐项验收，并记录遗留问题与经验总结。

## 输出要求

输出至少包含：

- 当前阶段判断
- 下一阶段建议
- 可复用的文档结构或表格
- 对大需求的拆分方案
- 对风险与依赖的说明

## 参考资料

- 参考 `references/newlife-flow-template.md`
