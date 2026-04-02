# 文档驱动 AI 分发架构

## 核心洞察

> 无论是 Copilot instructions/skills/agents、llms.txt 还是网站，一切分发渠道的根基都是**完整、结构化、可机器解析**的功能文档。先把文档写好，再自动转化。

## 分发路径

```
项目源码
  └─ Copilot 分析 → 标准化 Markdown 文档（Doc/*.md）
       ├─ → copilot-instructions/skills/agents（AI 编程助手）
       ├─ → llms.txt（外部 LLM 检索）
       └─ → 网站文档（开发者浏览 + 搜索引擎）
```

## 文档索引 JSON 格式（机器可解析）

每个项目根目录下维护 `Doc/索引.json`：

```json
{
  "project": "NewLife.Core",
  "nuget": "NewLife.Core",
  "version": "11.x.x",
  "modules": [
    {
      "namespace": "NewLife.Caching",
      "name": "缓存系统",
      "summary": "统一缓存接口，内存缓存和 Redis 客户端",
      "doc": "缓存系统ICache.md",
      "url": "https://newlifex.com/core/icache",
      "types": [
        {
          "name": "ICache",
          "kind": "interface",
          "summary": "标准缓存操作接口",
          "keyMethods": ["Set(key, value, expire)", "Get<T>(key)", "Remove(key)"]
        }
      ]
    }
  ]
}
```

`keyMethods` 字段让 LLM 无需读完整文档就能快速理解类型能做什么。

## llms.txt 规范

遵循 [llms.txt 标准](https://llmstxt.org/)，精简索引（供外部 ChatGPT 等检索）：

```
# NewLife 开源组件

> 新生命团队基础组件，支持 .NET 4.5 到 .NET 10。

## 核心库 NewLife.Core

- [缓存系统](https://newlifex.com/core/icache): 统一 ICache 接口
- [网络库](https://newlifex.com/core/netserver): 高性能 TCP/UDP 服务器
- [日志追踪](https://newlifex.com/core/tracer): ILog + ITracer APM
- [安全加密](https://newlifex.com/core/security_helper): RSA/AES/SM4/JWT
```

## 关键设计原则

| 决策点 | 推荐方案 | 理由 |
|--------|---------|------|
| 文档格式 | Markdown + YAML frontmatter | 人机双可读，Git 友好 |
| 索引格式 | JSON + Markdown | JSON 供工具解析，Markdown 供浏览 |
| 文档粒度 | 每个公共类型一个条目，核心类独立文件 | 平衡覆盖度 |
| 版本管理 | 文档随源码版本走，推送时带版本号 | 保证一致性 |

## 与 write-tech-docs 技能的关系

- 本文档描述**为什么**文档要标准化（服务于 AI 分发渠道）
- `write-tech-docs` 技能描述**怎么写**
- `newlife-module-doc-template.md` 提供具体格式模板

## 来源

- `D:\X\NewLife.Core\Doc\文档驱动AI分发架构.md`
