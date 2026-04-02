# Markdown frontmatter 模板

适用于需要把技术文档纳入统一索引、站点生成或批处理工具链的场景。

## 推荐模板

```yaml
---
title: 模块或类名
description: 用一句话概括它解决什么问题
tags: [Core, API]
category: API
api_version: 1.0.0
is_core: true
---
```

## 使用建议

- `title`：优先使用读者最容易识别的名称
- `description`：一句话说明用途，避免空泛描述
- `tags`：控制在 2~5 个
- `category`：尽量稳定，便于后续导航
- `api_version`：尽量从 `.csproj`、版本文件或发布信息读取
- `is_core`：用于区分核心能力与外围扩展

## 注意事项

- 不要为了凑字段而填无意义值
- 若仓库未采用 frontmatter，就不要强行添加
- 同一仓库应保持字段集合稳定，便于自动处理
