---
name: capture-conventions
description: 'Capture coding style, directory structure habits, naming conventions, layering patterns, module boundaries, and documentation rules from one or more repositories. Use when analyzing codebases to extract stable conventions into reusable knowledge files.'
argument-hint: 'Provide repository paths, target convention types, and output files to update.'
---

# 捕获代码库约定

## 适用场景

当你需要从一个或多个仓库中提取稳定规律时使用本技能，例如：

- 统一编码风格习惯
- 目录结构习惯
- 命名习惯
- 模块分层习惯
- 文档书写习惯
- API 设计偏好

## 输入要求

至少提供以下信息：

- 待分析目录或仓库路径
- 想要捕获的约定类型
- 目标输出文件位置
- 是否需要与已有知识融合

## 分析步骤

1. 确认分析范围，排除生成文件、构建产物、第三方依赖、临时目录。
2. 识别主要语言、框架、核心模块和测试目录。
3. 按照 [捕获检查表](references/capture-checklist.md) 提取规律。
4. 区分“高频稳定规则”与“局部实现细节”。
5. 只输出可复用、可执行、可验证的知识，不输出偶然现象。
6. 如果目标文件已存在，先读取旧内容，再基于旧内容进行增量融合。
7. 生成统一后的目标技能文件。

## 输出要求

输出内容应尽量采用以下结构：

- 适用范围
- 核心规则
- 常见例外
- 正例/反例
- 推荐检查项
- 待确认问题

## 融合原则

- 新知识不能简单覆盖旧知识。
- 若新旧规则一致，合并并去重。
- 若新旧规则冲突，优先保留“范围更明确、证据更多、更新更近”的规则。
- 若只在单一模块出现，不得直接上升为全局规范。

## 注意事项

- 优先总结“稳定模式”，避免被个别历史代码误导。
- 如果仓库存在多个子系统，应分别总结再抽象公共规律。
- 对于证据不足的结论，明确标记为“候选规则”，不要伪装成最终规范。
