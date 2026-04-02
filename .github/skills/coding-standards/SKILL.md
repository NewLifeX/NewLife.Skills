---
name: coding-standards
description: 'Apply or refine repository-specific coding standards, naming conventions, commenting rules, formatting boundaries, and documented house-style exceptions. Use when adding or reviewing code in an existing codebase.'
argument-hint: 'Provide the repository or files to inspect, the language, and whether you need to apply, extract, or review standards.'
---

# 应用或提炼编码规范

## 适用场景

当你需要在现有仓库中写代码、改代码、审代码，或者从代码中提炼显式编码规则时使用本技能。

典型场景：

- 根据仓库已有风格补代码
- 从指令文件或源码中整理编码规范
- 识别“项目特例”与“语言通例”的边界
- 在代码评审时检查命名、注释、结构是否一致

## 工作目标

- 优先遵循仓库的显式规范，而不是通用语言默认习惯
- 把稳定规则与局部例外分开表达
- 保护高价值的历史注释、兼容性处理与防御性代码
- 输出可执行的规范，而不是抽象口号

## 执行步骤

1. 先看仓库中的协作指令、代码规范、注释模板、代表性代码文件。
2. 提取命名规范、代码结构、注释规范、异常处理、资源管理等规则。
3. 标记哪些规则是“通用最佳实践”，哪些是“仓库特例”。
4. 在修改代码时优先保持已有风格，不做无关重排。
5. 如果发现历史兼容性代码、解释性注释、被刻意保留的旧逻辑，先判断其作用，不能直接清理。
6. 输出时采用“规则 + 适用范围 + 正例/反例 + 待确认项”的结构。

## 重点检查项

- 命名：类型、接口、字段、参数、布尔成员、扩展类
- 结构：命名空间、单文件职责、region 组织、方法布局
- 注释：XML 注释、迁移建议、说明性注释、禁止删除的历史注释
- 语法：是否使用项目允许的现代语法，是否破坏低版本兼容性
- 资源：池化对象、异常路径、释放与归还是否完整

## 输出要求

输出至少包含：

- 适用范围
- 核心规则
- 项目特例
- 正例 / 反例
- 修改时的注意事项
- 待确认问题

## 参考资料

- 参考 `references/newlife-csharp-style.md`
