---
name: merge-skill-knowledge
description: 'Merge newly captured knowledge into existing skill files. Use when you have old and new convention documents that need deduplication, conflict resolution, restructuring, and stable preservation.'
argument-hint: 'Provide the existing file, the newly captured notes, and the target merged file.'
---

# 融合技能知识

## 适用场景

当你已经有旧版技能文件，又从代码库、问答或 Copilot 记忆中捕获了新知识时，使用本技能进行融合。

## 工作目标

- 去重
- 消歧
- 保留历史有效信息
- 吸收新增高价值知识
- 形成更稳定、更短、更清晰的新版本

## 融合步骤

1. 读取已有技能文件。
2. 读取新捕获的知识条目。
3. 按主题分组：规则、例外、示例、待确认项。
4. 识别重复、冲突、过时和范围过窄的内容。
5. 产出统一的新版本。
6. 保留必要的“适用范围”和“证据强度”说明。

## 决策规则

### 保留

- 被多个证据支持的稳定规则
- 高复用、高指导价值的做法
- 明确说明适用边界的经验

### 删除

- 只有一次出现的偶然写法
- 已被新规则覆盖的旧表述
- 纯历史背景而无执行价值的内容

### 标记待确认

- 证据不足
- 新旧内容冲突且暂时无法判断
- 仅在单一模块观察到的局部习惯

## 输出风格

- 用更少的文字表达更稳定的规则
- 避免同义重复
- 优先输出可执行建议，而不是空泛总结
