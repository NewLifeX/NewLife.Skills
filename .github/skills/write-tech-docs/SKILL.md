---
name: write-tech-docs
description: 'Write or refine technical documentation in Chinese with clear structure, accurate terminology, practical examples, and repository-aware conventions. Use for README, module docs, how-to guides, API notes, and architecture explanations.'
argument-hint: 'Provide the audience, source materials, target document type, and output path.'
---

# 编写技术文档

## 适用场景

- 编写 README
- 编写模块说明
- 编写使用手册
- 编写架构文档
- 补全文档目录与导航
- 把零散知识整理成结构化文档
- 为类、模块、功能点生成 API 文档
- 为已有 Markdown 文档补全 frontmatter 与统一结构

## 写作原则

1. 先交代目标，再展开细节。
2. 先给结论，再给背景。
3. 优先使用真实路径、真实符号、真实示例。
4. 同时照顾“首次接触者”和“维护者”。
5. 中文表达自然准确，英文仅用于路径、命令、符号名。
6. 输出必须能追溯来源，避免只凭想象总结。

## 推荐结构

- 这是什么
- 解决什么问题
- 怎么使用
- 关键设计
- 常见问题
- 相关链接

## 建议流程

1. 先确认文档类型：README、模块文档、API 文档、架构文档、操作手册。
2. 读取真实来源：源码、现有文档、指令文件、测试、配置、示例。
3. 先整理结论，再补背景、示例和边界说明。
4. 如需要 frontmatter，优先保持字段稳定且可批处理。
5. 对 API 文档，优先引用真实类名、方法名、参数名和文件路径。

## Frontmatter 建议

若仓库采用 Markdown frontmatter，建议优先使用稳定字段：

- `title`
- `description`
- `tags`
- `category`
- `api_version`（若可从项目文件或版本文件读取）
- `is_core`

## 输出要求

- 标题层级清晰
- 术语前后一致
- 示例尽量最小可用
- 与仓库现有导航和命名保持一致
- 若信息不足，明确写出假设与限制
- 若文档来源于代码，必须标明关键符号或来源文件
- 若文档来源于旧文档，优先增量整理，不要重写覆盖历史结构

## 参考资料

- 参考 `references/frontmatter-template.md`
- 参考 `references/doc-quality-checklist.md`
