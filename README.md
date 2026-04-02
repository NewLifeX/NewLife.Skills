# NewLife Skills

这个仓库用于沉淀 **NewLife 团队与个人长期可复用的技能资产**，包括：知识、方法、规范、模板，以及后续可扩展的脚本与自动化流程。

## 目标

- 让技能可以被 Git 管理、版本化、跨设备同步。
- 让技能既适合人类阅读维护，也尽量兼容 Copilot 直接加载。
- 让“经验捕获 → 知识融合 → 再发布”形成闭环。

## 推荐结构

```text
.github/
  skills/                    # 直接给 Copilot 使用的运行态技能
    capture-conventions/
    merge-skill-knowledge/
    write-tech-docs/
docs/
  skill-system-design.md     # 技能体系设计说明
scripts/
  sync-skills-to-user.ps1    # 同步到用户级 Copilot 技能目录
```

## 设计原则

1. **运行态扁平，知识态分层**
   - Copilot 直接识别的技能目录建议放在 `.github/skills/<skill-name>/`，保持扁平。
   - 更细的知识分层、分类、归档，放在 `docs/` 或未来扩展的知识目录中。

2. **路径英文，内容中文优先**
   - 目录名、技能名、脚本名优先使用英文 kebab-case，便于兼容性与跨平台。
   - `SKILL.md` 正文、说明文档、示例内容，完全可以使用中文。

3. **技能分三层**
   - 捕获型：从代码、目录、提交、问答中提炼稳定规律。
   - 融合型：把新发现与已有知识合并，避免重复和冲突。
   - 生产型：在写代码、写文档、做评审时直接调用。

## 推荐工作流

1. 在仓库或目录上运行“捕获型技能”。
2. 生成候选知识条目。
3. 调用“融合型技能”与已有技能文件合并。
4. 产出新的稳定技能文件并提交 Git。
5. 通过脚本同步到用户级 Copilot 技能目录。

## 与 Copilot 的关系

- 当前仓库中的 `.github/skills/` 适合在**打开本仓库时**直接被 Copilot 使用。
- 如果希望跨项目全局复用，建议把技能同步到用户级技能目录。
- `scripts/sync-skills-to-user.ps1` 提供了一个起点，后续可接入计划任务、登录脚本或你自己的工具链。

## 下一步建议

- 先沉淀 10~20 个高价值技能，而不是一次铺满所有类别。
- 优先顺序建议：
  1. `capture-conventions`
  2. `merge-skill-knowledge`
  3. `write-tech-docs`
  4. 语言/框架专项技能（如 `csharp-style`, `xcode-repo-analysis`）
  5. 发布、评审、问题定位等流程型技能
