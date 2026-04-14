---
name: frontend-design-system
description: >
  前端设计系统基础：设计令牌体系（色彩理论、排版层级、间距网格、圆角策略、投影层次、动画规范），
  为后台管理系统和 Web 应用建立统一视觉语言。
  适用于新建前端项目设计规范、优化现有界面视觉一致性、组件库主题配置等任务。
argument-hint: >
  说明目标：是新建设计系统、优化现有项目、还是为组件库配置主题；
  如有品牌色或设计偏好，一并提供。
---

# 前端设计系统基础

## 文件说明

此技能文件旨在指导用户如何构建和优化前端设计系统，涵盖色彩、排版、间距等核心设计原则。以下是文件的主要内容：

- **适用场景**：列举了设计系统的应用场景，包括新建项目、优化现有系统等。
- **设计令牌体系**：详细描述了设计令牌的概念及其在色彩系统中的应用。
- **色彩分类**：提供了主色、辅助色、中性色和功能色的分类及示例。
- **主色选取规则**：列出了推荐的色相范围和避免事项。

通过遵循此技能文件中的指导，用户可以显著提升前端界面的视觉一致性和现代化水平。

## 适用场景

- 新建前端项目时建立统一设计规范
- 优化现有后台管理系统的视觉一致性
- 为 Element Plus / Ant Design / Arco / TDesign / Naive UI 等组件库配置主题基础
- 审查界面设计是否符合现代审美标准
- 从"能用"提升到"好看"的第一步

---

## 设计令牌体系

设计令牌（Design Tokens）是设计系统的原子单位，所有视觉属性都应从令牌派生，而非硬编码。

### 1. 色彩系统

#### 1.1 色彩分类

| 类别 | 用途 | 色相数量 | 示例 |
|------|------|---------|------|
| **主色（Primary）** | 核心 CTA、焦点、品牌标识 | 1 个色相，5-9 个明度梯度 | `#0057FF`（科技蓝） |
| **辅助色（Secondary）** | 次要操作、装饰、图表配色 | 1-2 个色相 | 紫色 `#7C3AED`、青色 `#06B6D4` |
| **中性色（Neutral）** | 文字、背景、边框、分割线 | 灰色系，10 个梯度 | `gray-50` ~ `gray-950` |
| **功能色（Semantic）** | 状态反馈，必须语义一致 | 4 个 | 成功绿/警告黄/错误红/信息蓝 |

#### 1.2 主色选取规则

```
✅ 推荐色相范围（后台管理系统）：
   - 蓝色系 200°~230°（专业、信任）— 最安全的选择
   - 紫色系 260°~280°（创新、高端）
   - 青色系 180°~200°（清新、科技）

❌ 避免：
   - 纯红色主色（攻击性强）
   - 饱和度过高（>90%）的纯色直接做背景
   - 主色与功能色色相冲突（如主色为绿色则成功色难以区分）
```

#### 1.3 主色梯度生成

从一个基准色生成完整梯度，用于不同交互态：

```css
:root {
  /* 基准色 */
  --color-primary: #0057FF;

  /* 自动梯度 */
  --color-primary-50:  #EFF6FF;   /* 极浅背景（选中行、徽章底色） */
  --color-primary-100: #DBEAFE;   /* 浅背景（hover 态、活跃态底色） */
  --color-primary-200: #BFDBFE;   /* 边框（focus ring） */
  --color-primary-300: #93C5FD;   /* 禁用态文字 */
  --color-primary-400: #60A5FA;   /* 图标、次要操作 */
  --color-primary-500: #3B82F6;   /* 标准按钮、链接 */
  --color-primary-600: #2563EB;   /* 按钮 hover */
  --color-primary-700: #1D4ED8;   /* 按钮 active/pressed */
  --color-primary-800: #1E40AF;   /* 深色文字 */
  --color-primary-900: #1E3A8A;   /* 极深场景 */
}
```

#### 1.4 功能色规范

```css
:root {
  /* 成功 — 绿色系 */
  --color-success: #10B981;
  --color-success-light: #D1FAE5;
  --color-success-dark: #065F46;

  /* 警告 — 琥珀色系（非纯黄，纯黄在白色背景上对比度不够） */
  --color-warning: #F59E0B;
  --color-warning-light: #FEF3C7;
  --color-warning-dark: #92400E;

  /* 错误 — 红色系 */
  --color-error: #EF4444;
  --color-error-light: #FEE2E2;
  --color-error-dark: #991B1B;

  /* 信息 — 蓝色系（可复用主色浅色调） */
  --color-info: #3B82F6;
  --color-info-light: #DBEAFE;
  --color-info-dark: #1E40AF;
}
```

#### 1.5 中性色梯度

```css
:root {
  --color-gray-50:  #F9FAFB;   /* 页面背景、侧边栏底色 */
  --color-gray-100: #F3F4F6;   /* 卡片背景（非白色区域） */
  --color-gray-200: #E5E7EB;   /* 边框、分割线 */
  --color-gray-300: #D1D5DB;   /* 禁用态边框 */
  --color-gray-400: #9CA3AF;   /* 占位文字 */
  --color-gray-500: #6B7280;   /* 次要文字 */
  --color-gray-600: #4B5563;   /* 正文文字 */
  --color-gray-700: #374151;   /* 标题文字 */
  --color-gray-800: #1F2937;   /* 强调文字 */
  --color-gray-900: #111827;   /* 最深文字 */
  --color-gray-950: #030712;   /* 近黑色 */
}
```

---

### 2. 排版系统

#### 2.1 字体栈

```css
:root {
  /* 中文优先字体栈 */
  --font-sans: "Noto Sans SC", "PingFang SC", "Microsoft YaHei",
               -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;

  /* 等宽字体（代码/数据） */
  --font-mono: "JetBrains Mono", "Fira Code", "Cascadia Code",
               "Source Code Pro", Consolas, monospace;
}
```

#### 2.2 字号梯度

基于 `1rem = 16px`，使用模块化比例（Major Third = 1.25）：

| 令牌名 | 大小 | 行高 | 用途 |
|--------|------|------|------|
| `text-xs` | 12px / 0.75rem | 1.5 | 标签、徽章、辅助信息 |
| `text-sm` | 14px / 0.875rem | 1.5 | 表格内容、按钮文字、表单标签 |
| `text-base` | 16px / 1rem | 1.5 | 正文、输入框文字 |
| `text-lg` | 18px / 1.125rem | 1.5 | 卡片标题、区块标题 |
| `text-xl` | 20px / 1.25rem | 1.4 | 页面副标题 |
| `text-2xl` | 24px / 1.5rem | 1.35 | 页面标题 |
| `text-3xl` | 30px / 1.875rem | 1.3 | 欢迎页/登录页标题 |
| `text-4xl` | 36px / 2.25rem | 1.25 | KPI 大数字 |

#### 2.3 字重梯度

| 令牌名 | 值 | 用途 |
|--------|-----|------|
| `font-normal` | 400 | 正文、表格内容 |
| `font-medium` | 500 | 按钮、导航项、表单标签 |
| `font-semibold` | 600 | 卡片标题、表头 |
| `font-bold` | 700 | 页面标题、KPI 数字 |

---

### 3. 间距系统

#### 3.1 8px 基准网格

所有间距必须是 **4px 的倍数**，优先使用 **8px 的倍数**：

| 令牌 | 值 | 用途 |
|------|-----|------|
| `space-0.5` | 2px | 图标与文字间微调 |
| `space-1` | 4px | 紧凑元素内边距 |
| `space-1.5` | 6px | 小按钮/标签内边距 |
| `space-2` | 8px | 输入框内边距、列表项间距 |
| `space-3` | 12px | 卡片内边距（紧凑） |
| `space-4` | 16px | 卡片内边距（标准）、区块间距 |
| `space-5` | 20px | 表单字段间距 |
| `space-6` | 24px | 区块间距（宽松） |
| `space-8` | 32px | 页面容器内边距 |
| `space-10` | 40px | 大区块分隔 |
| `space-12` | 48px | 页面顶部/底部留白 |

#### 3.2 间距应用原则

```
✅ 规则：
   - 相关元素靠近（8-12px），无关元素远离（24-32px）
   - 内边距 > 外边距（容器向内收紧，向外留白）
   - 标题与内容间距 > 内容行间距（建立层级）
   - 留白优于分割线（能用间距分隔的不要画线）

❌ 常见错误：
   - 所有间距一样大（没有层级感）
   - 间距不是 4px 倍数（如 5px、7px、15px）
   - 卡片内边距小于元素间距（内容溢出感）
```

---

### 4. 圆角系统

按组件尺寸递增，越大的容器圆角越大：

| 令牌 | 值 | 适用组件 |
|------|-----|---------|
| `rounded-sm` | 4px | 小标签、行内徽章 |
| `rounded` | 6px | 按钮、输入框、选择器 |
| `rounded-md` | 8px | 下拉菜单、Tooltip |
| `rounded-lg` | 12px | 卡片、表格容器 |
| `rounded-xl` | 16px | Modal、大卡片 |
| `rounded-2xl` | 24px | 全屏弹窗、登录框 |
| `rounded-full` | 9999px | 头像、圆形按钮、开关 |

```
✅ 规则：
   - 圆角越大 = 越柔和亲切（适合 C 端、对话 UI）
   - 圆角越小 = 越硬朗精确（适合 B 端数据密集型）
   - 同一层级的组件圆角保持一致
   - 内部子元素圆角 ≤ 外部容器圆角 - 内边距（防止圆角溢出）

❌ 常见错误：
   - 所有组件统一 4px 圆角（老旧感）
   - 按钮 16px 圆角但容器 4px（风格不统一）
   - 头像用方角（不亲和）
```

---

### 5. 投影系统

4 级投影建立空间层次，从低到高：

| 层级 | 令牌 | CSS 值 | 适用场景 |
|------|------|--------|---------|
| L0 - 平面 | `shadow-none` | `none` | 默认状态、内嵌元素 |
| L1 - 微浮 | `shadow-sm` | `0 1px 2px rgba(0,0,0,0.05)` | 卡片默认态、按钮 |
| L2 - 浮起 | `shadow` | `0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)` | 卡片 hover、下拉菜单 |
| L3 - 悬浮 | `shadow-lg` | `0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05)` | Tooltip、Popover、浮层 |
| L4 - 弹出 | `shadow-xl` | `0 20px 25px -5px rgba(0,0,0,0.1), 0 8px 10px rgba(0,0,0,0.04)` | Modal、Drawer |

```
✅ 规则：
   - 投影方向统一朝下（模拟自然光从上方照射）
   - 层级越高，投影越大且越淡（不要用纯黑重影）
   - 交互态投影变化：hover 时升一级（L1→L2），active 降回（L2→L1）

❌ 常见错误：
   - 不使用投影（纯扁平，无层次感 = 显得廉价）
   - 投影颜色太深或太大（沉重、老旧）
   - 不同方向的投影混用（光源矛盾）
```

---

### 6. 动画与过渡

#### 6.1 时长规范

| 场景 | 时长 | Easing |
|------|------|--------|
| 颜色/背景切换 | 150ms | `ease` |
| 尺寸/位置变化 | 200ms | `ease-out` |
| 进入/出现 | 200-300ms | `ease-out` |
| 退出/消失 | 150-200ms | `ease-in` |
| 主题切换 | 300-400ms | `ease-in-out` |
| 页面切换 | 300ms | `ease-in-out` |

#### 6.2 通用过渡

```css
/* 所有可交互元素的默认过渡 */
.interactive {
  transition: all 200ms ease;
}

/* 颜色变化（按钮、链接） */
.color-transition {
  transition: color 150ms ease, background-color 150ms ease, border-color 150ms ease;
}

/* 投影变化（卡片 hover） */
.shadow-transition {
  transition: box-shadow 200ms ease, transform 200ms ease;
}
```

#### 6.3 动画规范

```
✅ 规则：
   - 每个元素最多 1-2 种动画效果
   - 动画服务于功能反馈，不做纯装饰
   - 尊重 prefers-reduced-motion：
     @media (prefers-reduced-motion: reduce) { *, *::before, *::after { animation-duration: 0.01ms !important; } }
   - 加载动画：旋转 spin 或脉冲 pulse，不要弹跳 bounce

❌ 常见错误：
   - 过度动画（每个元素都在动 = 眼花缭乱）
   - 动画时长 > 500ms（用户感知到等待）
   - 没有动画（切换生硬、缺乏反馈 = 廉价感）
```

---

## Tailwind CSS 令牌映射

如果项目使用 Tailwind CSS，以下是设计令牌到 `tailwind.config` 的映射：

```javascript
// tailwind.config.js
export default {
  theme: {
    extend: {
      colors: {
        primary: {
          50:  '#EFF6FF',
          100: '#DBEAFE',
          200: '#BFDBFE',
          300: '#93C5FD',
          400: '#60A5FA',
          500: '#3B82F6',  // 基准色
          600: '#2563EB',  // hover
          700: '#1D4ED8',  // active
          800: '#1E40AF',
          900: '#1E3A8A',
          DEFAULT: '#3B82F6',
        },
        success: { DEFAULT: '#10B981', light: '#D1FAE5', dark: '#065F46' },
        warning: { DEFAULT: '#F59E0B', light: '#FEF3C7', dark: '#92400E' },
        error:   { DEFAULT: '#EF4444', light: '#FEE2E2', dark: '#991B1B' },
        info:    { DEFAULT: '#3B82F6', light: '#DBEAFE', dark: '#1E40AF' },
      },
      fontFamily: {
        sans: ['"Noto Sans SC"', '"PingFang SC"', '"Microsoft YaHei"', 'sans-serif'],
        mono: ['"JetBrains Mono"', '"Fira Code"', 'Consolas', 'monospace'],
      },
      borderRadius: {
        sm:   '4px',
        DEFAULT: '6px',
        md:   '8px',
        lg:   '12px',
        xl:   '16px',
        '2xl': '24px',
      },
      boxShadow: {
        sm:   '0 1px 2px rgba(0,0,0,0.05)',
        DEFAULT: '0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)',
        lg:   '0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05)',
        xl:   '0 20px 25px -5px rgba(0,0,0,0.1), 0 8px 10px rgba(0,0,0,0.04)',
      },
    },
  },
}
```

---

## CSS 变量令牌映射

如果项目使用原生 CSS 或 SCSS，统一定义令牌变量：

```css
:root {
  /* === 色彩 === */
  --color-primary: #3B82F6;
  --color-primary-hover: #2563EB;
  --color-primary-active: #1D4ED8;
  --color-primary-light: #EFF6FF;
  --color-primary-border: #BFDBFE;

  --color-success: #10B981;
  --color-warning: #F59E0B;
  --color-error: #EF4444;
  --color-info: #3B82F6;

  --color-text-primary: #111827;
  --color-text-secondary: #6B7280;
  --color-text-placeholder: #9CA3AF;
  --color-text-disabled: #D1D5DB;

  --color-bg-page: #F9FAFB;
  --color-bg-card: #FFFFFF;
  --color-bg-sidebar: #F3F4F6;
  --color-border: #E5E7EB;
  --color-divider: #F3F4F6;

  /* === 排版 === */
  --font-sans: "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;
  --font-mono: "JetBrains Mono", "Fira Code", Consolas, monospace;
  --text-xs: 0.75rem;
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.125rem;
  --text-xl: 1.25rem;
  --text-2xl: 1.5rem;

  /* === 间距 === */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-6: 24px;
  --space-8: 32px;

  /* === 圆角 === */
  --radius-sm: 4px;
  --radius: 6px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;

  /* === 投影 === */
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.05);
  --shadow: 0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06);
  --shadow-lg: 0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05);
  --shadow-xl: 0 20px 25px -5px rgba(0,0,0,0.1), 0 8px 10px rgba(0,0,0,0.04);

  /* === 动画 === */
  --duration-fast: 150ms;
  --duration-normal: 200ms;
  --duration-slow: 300ms;
  --easing: ease;
  --easing-in: ease-in;
  --easing-out: ease-out;
}
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 到处硬编码 `#333`、`14px`、`4px` | 使用设计令牌变量 |
| 所有文字同一颜色同一大小 | 建立排版层级（标题/正文/辅助文字） |
| 间距随意 5px/7px/15px | 统一 4px 基准网格 |
| 所有圆角统一 4px | 按组件尺寸递增（6/8/12/16px） |
| 没有投影，纯扁平白色卡片 | 至少使用 L1 微浮投影 |
| 投影又黑又大 | 使用低透明度 `rgba(0,0,0,0.05~0.1)` |
| 没有过渡动画 | 所有交互元素添加 150-200ms 过渡 |
| 过度动画（到处 bounce） | 动画服务于反馈，时长 < 300ms |
| 超过 5 种不同颜色 | 控制调色板，一个主色 + 4 个功能色 + 中性色梯度 |
| 正文用衬线字体 | 中文场景优先无衬线（Noto Sans SC / PingFang） |

---

## 设计系统建立检查清单

新建或优化前端项目时，按此清单逐项确认：

- [ ] 是否定义了主色及其 50-900 梯度？
- [ ] 是否定义了 4 个功能色（成功/警告/错误/信息）？
- [ ] 是否定义了完整的中性灰色梯度（10 级）？
- [ ] 是否有统一字体栈（含中文字体回退）？
- [ ] 是否建立了字号梯度（至少 6 级）？
- [ ] 是否所有间距都是 4px 的倍数？
- [ ] 是否定义了圆角梯度（至少 5 级）？
- [ ] 是否定义了投影梯度（至少 3 级：无/轻/重）？
- [ ] 是否所有交互元素都有过渡动画？
- [ ] 令牌是否以 CSS 变量或 Tailwind config 形式输出？

---

## 参考实现

StarChat Web 项目采用了完整的设计令牌体系：
- 主色 `#0057FF`（深蓝科技感）
- 中性色从 `white` 到 `gray-900` + 暗色 `#18181b`
- 圆角从 `0.5rem`（按钮）到 `2rem`（大 Modal）递增
- 投影从 `shadow-soft`（轻卡片）到 `shadow-modal`（弹窗）分级
- 所有按钮使用 `transition-colors` 150ms 过渡
- 字体使用 `Noto Sans SC` 中文友好字体栈
