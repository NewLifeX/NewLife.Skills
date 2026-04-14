---
name: frontend-dark-theme
description: >
  亮暗主题设计与实现：暗色模式色彩映射规则、CSS 变量 / Tailwind dark: 方案、
  system/light/dark 三档切换机制、防白屏闪烁、投影退阶、主题过渡动画。
  适用于为前端项目添加暗色模式、优化现有深色主题、审查亮暗适配质量等任务。
argument-hint: >
  说明目标框架（Vue/React/Svelte/原生）和 CSS 方案（Tailwind/SCSS/CSS变量）；
  如已有亮色设计，提供主色和背景色。
---

# 亮暗主题设计与实现

## 适用场景

- 为现有前端项目添加暗色模式支持
- 优化已有暗色主题的对比度和视觉层次
- 审查亮暗模式切换是否平滑无闪烁
- 配置组件库（Element Plus / Ant Design / Arco 等）暗色主题
- 确保暗色下的可访问性（WCAG 对比度标准）

---

## 核心原则

暗色模式 **不是简单反色**。正确做法是重新映射语义色彩：

```
亮色模式                          暗色模式
─────────                        ─────────
白色背景 (#FFFFFF)          →    深灰背景 (#18181B)  ❌ 不是纯黑 #000000
灰色背景 (#F9FAFB)          →    略浅深灰 (#27272A)
卡片白色 (#FFFFFF)          →    卡片深灰 (#1E1E20)  比背景略浅
文字深色 (#111827)          →    文字浅色 (#F3F4F6)  ❌ 不是纯白 #FFFFFF
次要文字 (#6B7280)          →    次要灰色 (#9CA3AF)  保持次要感
边框浅灰 (#E5E7EB)          →    边框深灰 (#3F3F46)
主色保持                    →    主色不变或微调亮度 (+5~10%)
```

### 为什么不用纯黑？

- 纯黑 `#000000` 与白色文字对比度过高（21:1），长时间阅读眼睛疲劳
- 推荐深灰 `#18181B`~`#1A1A2E`（对比度 15:1 左右），减少视觉压力
- 纯黑背景在 OLED 屏幕上虽省电，但与深灰元素的分界会显得"漂浮"

---

## 色彩映射表

### 完整令牌映射

```css
/* ===== 亮色模式（默认） ===== */
:root {
  --color-bg-page:      #F9FAFB;
  --color-bg-card:      #FFFFFF;
  --color-bg-sidebar:   #F3F4F6;
  --color-bg-input:     #FFFFFF;
  --color-bg-hover:     #F3F4F6;
  --color-bg-active:    #EFF6FF;

  --color-text-primary:   #111827;
  --color-text-secondary: #6B7280;
  --color-text-placeholder: #9CA3AF;
  --color-text-disabled:  #D1D5DB;

  --color-border:       #E5E7EB;
  --color-border-focus:  #3B82F6;
  --color-divider:      #F3F4F6;

  --color-primary:      #3B82F6;
  --color-primary-hover: #2563EB;

  /* 投影 */
  --shadow-sm:   0 1px 2px rgba(0, 0, 0, 0.05);
  --shadow-md:   0 4px 6px rgba(0, 0, 0, 0.07);
  --shadow-lg:   0 10px 15px rgba(0, 0, 0, 0.1);
  --shadow-xl:   0 20px 25px rgba(0, 0, 0, 0.1);
}

/* ===== 暗色模式 ===== */
.dark {
  --color-bg-page:      #18181B;
  --color-bg-card:      #1E1E20;
  --color-bg-sidebar:   #202023;
  --color-bg-input:     #27272A;
  --color-bg-hover:     #27272A;
  --color-bg-active:    #1E3A5F;

  --color-text-primary:   #F3F4F6;
  --color-text-secondary: #9CA3AF;
  --color-text-placeholder: #6B7280;
  --color-text-disabled:  #4B5563;

  --color-border:       #3F3F46;
  --color-border-focus:  #60A5FA;
  --color-divider:      #27272A;

  --color-primary:      #60A5FA;     /* 暗色下主色提亮一档 */
  --color-primary-hover: #3B82F6;

  /* 投影：暗色下大幅降低（深色背景上投影几乎不可见） */
  --shadow-sm:   0 1px 2px rgba(0, 0, 0, 0.2);
  --shadow-md:   0 4px 6px rgba(0, 0, 0, 0.3);
  --shadow-lg:   0 10px 15px rgba(0, 0, 0, 0.3);
  --shadow-xl:   0 20px 25px rgba(0, 0, 0, 0.4);
}
```

### 背景层次（暗色模式关键）

暗色模式下需要多层深度区分元素层级：

```
最底层（页面背景）:  #18181B  — zinc-900
第二层（侧边栏）:    #202023  — 自定义，比背景浅 2%
第三层（卡片/输入框）: #27272A  — zinc-800
第四层（hover/悬浮）:  #3F3F46  — zinc-700
第五层（active/选中）: #52525B  — zinc-600
```

---

## Tailwind CSS 暗色模式

### 配置方式

```javascript
// tailwind.config.js
export default {
  darkMode: 'class',  // 使用 class 策略（推荐，可控性最强）
  // darkMode: 'media',  // 仅跟随系统，无法手动切换
}
```

### 使用模式

```html
<!-- 典型用法：亮色类 + dark: 前缀暗色类 -->
<div class="bg-white dark:bg-zinc-900
            text-gray-900 dark:text-gray-100
            border-gray-200 dark:border-zinc-700">

  <h1 class="text-gray-800 dark:text-gray-100">标题</h1>
  <p class="text-gray-600 dark:text-gray-400">正文内容</p>

  <button class="bg-blue-500 hover:bg-blue-600
                 dark:bg-blue-600 dark:hover:bg-blue-500
                 text-white rounded-lg px-4 py-2
                 transition-colors duration-150">
    操作按钮
  </button>
</div>
```

---

## 主题切换实现

### 三档切换（system / light / dark）

#### React + Zustand 示例

```tsx
// stores/themeStore.ts
import { create } from 'zustand'
import { persist } from 'zustand/middleware'

type ThemeMode = 'system' | 'light' | 'dark'

interface ThemeStore {
  mode: ThemeMode
  setMode: (mode: ThemeMode) => void
}

export const useThemeStore = create<ThemeStore>()(
  persist(
    (set) => ({
      mode: 'system',
      setMode: (mode) => {
        set({ mode })
        applyTheme(mode)
      },
    }),
    { name: 'theme-mode' }
  )
)

function applyTheme(mode: ThemeMode) {
  const root = document.documentElement
  const isDark = mode === 'dark' ||
    (mode === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches)

  // 添加过渡类，防止闪烁
  root.classList.add('theme-transitioning')
  root.classList.toggle('dark', isDark)

  // 过渡完成后移除
  setTimeout(() => root.classList.remove('theme-transitioning'), 400)
}

// 监听系统主题变化（system 模式下自动跟随）
window.matchMedia('(prefers-color-scheme: dark)')
  .addEventListener('change', () => {
    const { mode } = useThemeStore.getState()
    if (mode === 'system') applyTheme('system')
  })
```

#### Vue + Pinia 示例

```typescript
// stores/theme.ts
import { defineStore } from 'pinia'

type ThemeMode = 'system' | 'light' | 'dark'

export const useThemeStore = defineStore('theme', {
  state: () => ({
    mode: (localStorage.getItem('theme-mode') || 'system') as ThemeMode,
  }),
  actions: {
    setMode(mode: ThemeMode) {
      this.mode = mode
      localStorage.setItem('theme-mode', mode)
      this.apply()
    },
    apply() {
      const isDark = this.mode === 'dark' ||
        (this.mode === 'system' &&
         window.matchMedia('(prefers-color-scheme: dark)').matches)

      const root = document.documentElement
      root.classList.add('theme-transitioning')
      root.classList.toggle('dark', isDark)
      setTimeout(() => root.classList.remove('theme-transitioning'), 400)
    },
  },
})
```

### 过渡动画 CSS

```css
/* 主题切换时的全局过渡 */
.theme-transitioning,
.theme-transitioning *,
.theme-transitioning *::before,
.theme-transitioning *::after {
  transition: background-color 400ms ease,
              color 400ms ease,
              border-color 400ms ease,
              box-shadow 400ms ease !important;
}
```

---

## 防白屏闪烁

暗色模式用户刷新页面时，如果 JS 加载慢会先看到白色背景再闪到暗色。解决方案：

### 方案 1：内联脚本（推荐）

在 `<head>` 标签中、任何 CSS 加载之前添加同步脚本：

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <script>
    // 必须同步执行，不能 defer/async
    ;(function() {
      var theme = localStorage.getItem('theme-mode') || 'system'
      var isDark = theme === 'dark' ||
        (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches)
      if (isDark) document.documentElement.classList.add('dark')
    })()
  </script>
  <link rel="stylesheet" href="/style.css" />
</head>
```

### 方案 2：SSR 注入

对于 Nuxt / Next.js / SvelteKit 等 SSR 框架，在 cookie 中存储主题，服务端渲染时直接注入 `dark` 类。

---

## 暗色模式下的特殊处理

### 投影退阶

暗色背景上标准投影几乎不可见，需要加深：

```css
/* 亮色：轻投影 */
.card { box-shadow: 0 1px 3px rgba(0,0,0,0.1); }

/* 暗色：投影透明度 × 2~3 倍，或改用边框代替 */
.dark .card {
  box-shadow: 0 1px 3px rgba(0,0,0,0.3);
  /* 或者用边框替代投影 */
  border: 1px solid rgba(255,255,255,0.06);
}
```

### 图片处理

```css
/* 暗色模式下降低图片亮度，防止刺眼 */
.dark img:not([data-no-dim]) {
  filter: brightness(0.9);
}

/* 插画/SVG 可能需要反色或替换 */
.dark .illustration {
  filter: invert(1) hue-rotate(180deg);
  opacity: 0.85;
}
```

### 边框增强

暗色模式下投影弱，需要用细边框补偿层级感：

```css
.dark .card {
  border: 1px solid rgba(255, 255, 255, 0.06);
}

.dark .input {
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.dark .input:focus {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.3);
}
```

---

## 组件库暗色模式配置

### Element Plus

```typescript
// main.ts
import { ID_INJECTION_KEY } from 'element-plus'
import 'element-plus/theme-chalk/dark/css-vars.css'  // 引入暗色变量

// 脚本切换
document.documentElement.classList.toggle('dark', isDark)
```

### Ant Design 5

```tsx
import { ConfigProvider, theme } from 'antd'

<ConfigProvider theme={{
  algorithm: isDark ? theme.darkAlgorithm : theme.defaultAlgorithm,
  token: {
    colorPrimary: '#3B82F6',
  },
}}>
  <App />
</ConfigProvider>
```

### Arco Design Vue

```typescript
import { Message } from '@arco-design/web-vue'

// 切换暗色
document.body.setAttribute('arco-theme', 'dark')
// 切换亮色
document.body.removeAttribute('arco-theme')
```

### Naive UI

```vue
<template>
  <n-config-provider :theme="isDark ? darkTheme : null">
    <App />
  </n-config-provider>
</template>

<script setup>
import { darkTheme } from 'naive-ui'
</script>
```

### TDesign

```typescript
import { config } from 'tdesign-vue-next'

// 手动切换
document.documentElement.setAttribute('theme-mode', 'dark')
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 暗色背景用纯黑 `#000000` | 使用深灰 `#18181B` ~ `#1A1A2E` |
| 暗色文字用纯白 `#FFFFFF` | 使用 `#F3F4F6`~`#E5E7EB`，降低对比度 |
| 亮暗两套完全不同的调色板 | 一套语义令牌，映射两组值 |
| 刷新闪白屏 | `<head>` 内联同步脚本预读主题 |
| 暗色下投影完全不变 | 投影透明度 ×2~3，或用边框补偿 |
| 图片不做处理（暗色下刺眼） | `brightness(0.9)` 降低亮度 |
| 只有 light/dark 两档 | 加 system 自动跟随系统偏好 |
| 切换时生硬跳变 | 添加 300-400ms 全局过渡动画 |
| 不做可访问性检查 | WCAG AA 标准：正文 4.5:1，大字 3:1 对比度 |
| 暗色下色彩不调整 | 主色提亮一档（500→400），功能色同理 |

---

## 暗色模式检查清单

- [ ] 背景层级是否清晰？（页面 < 侧边栏 < 卡片 < 悬浮层 依次变浅）
- [ ] 文字对比度是否达标？（正文 ≥ 4.5:1，大字 ≥ 3:1）
- [ ] 主色是否提亮？（暗色背景下 500 色号不够亮，需用 400）
- [ ] 投影是否加深或改用边框？
- [ ] 图片是否降亮度处理？
- [ ] 切换是否平滑过渡？
- [ ] 刷新是否无白屏闪烁？
- [ ] system 模式是否跟随系统偏好变化？
- [ ] 组件库是否正确切换暗色？
- [ ] 代码块/终端等特殊区域是否适配？

---

## 参考实现

StarChat Web 暗色模式实现：
- 背景层级：`#18181B`（页面）→ `#202023`（侧边栏）→ `#1E1E20`（卡片）
- 文字：`gray-100`（主文字）→ `gray-400`（辅助）
- 主题 store 使用 Zustand persist 持久化模式选择
- 防闪烁：`index.html` 内联同步脚本读取 localStorage
- 切换动画：`.theme-transitioning` 类 + 400ms ease 过渡
- 所有交互元素统一 `dark:` Tailwind 前缀适配
