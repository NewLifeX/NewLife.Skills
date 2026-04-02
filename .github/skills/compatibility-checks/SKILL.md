---
name: compatibility-checks
description: 'Review framework compatibility, language-version constraints, conditional compilation, downgrade strategy, and API availability before changing .NET code. Use when working in multi-target or long-lived repositories.'
argument-hint: 'Provide the target project files, expected frameworks, and the API or syntax changes you plan to introduce.'
---

# 检查兼容性边界

## 适用场景

当你要修改 .NET 代码，尤其是多目标框架、历史仓库或公共库时，先使用本技能检查兼容性风险。

适用任务：

- 新增公共 API
- 引入新的语言特性或 BCL API
- 修改多目标框架项目
- 添加条件编译
- 做向下兼容或降级实现

## 工作目标

- 先看项目声明的兼容边界，再决定能不能用新语法、新 API
- 找出必须保留的低版本实现和条件编译分支
- 避免只在本机或单一目标框架可用的改法

## 执行步骤

1. 读取 `.csproj`、`Directory.Build.props`、`global.json` 等文件，确定 `TargetFrameworks` 与 `LangVersion`。
2. 搜索已有条件编译符号和兼容性分支，判断仓库当前的降级策略。
3. 检查拟引入的语言特性、BCL API、第三方依赖是否覆盖所有目标框架。
4. 如不覆盖，优先沿用仓库已有的降级方式和条件编译模式。
5. 输出时说明：兼容边界、风险点、替代方案、验证方式。

## 重点检查项

- `TargetFramework` / `TargetFrameworks`
- `LangVersion`
- 条件编译符号
- 高版本专属 BCL API
- Nullable、unsafe、隐式 using 等编译设置
- 文档或注释中声明的兼容承诺

## 输出要求

输出至少包含：

- 目标框架与语言版本
- 本次改动涉及的兼容性风险
- 需要的降级策略或条件编译点
- 验证方案

## 参考资料

- 参考 `references/newlife-compatibility-patterns.md`
