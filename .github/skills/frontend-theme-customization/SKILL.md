---
name: frontend-theme-customization
description: >
  五大主流组件库主题深度定制：Element Plus CSS 变量 + SCSS、Ant Design 5 Token + 算法、
  Arco Design Less 变量、TDesign Token 覆盖、Naive UI themeOverrides。
  从设计令牌到组件库的统一映射方法。
  适用于为 Cube API 版各前端主题定制视觉风格、统一多主题色彩体系等任务。
argument-hint: >
  说明使用的组件库（Element Plus/Ant Design/Arco/TDesign/Naive UI）和目标视觉效果；
  如有品牌色板，一并提供。
---

# 组件库主题深度定制

## 适用场景

- 为 Cube API 版各前端主题（Vue/React/Angular）定制品牌视觉
- 替换组件库默认主色，建立统一色彩体系
- 调整组件圆角、间距、字号以匹配设计系统
- 统一多个组件库主题的视觉风格（使同一设计令牌产出一致外观）

---

## 设计令牌到组件库的映射策略

先定义与组件库无关的设计令牌，再映射到各库的配置格式：

```
设计令牌 (Design Tokens)
    │
    ├── Element Plus  → CSS 变量 / SCSS 变量
    ├── Ant Design 5  → ConfigProvider token
    ├── Arco Design   → Less 变量 / CSS 变量
    ├── TDesign       → CSS Token / ConfigProvider
    └── Naive UI      → themeOverrides 对象
```

### 统一令牌定义

```typescript
// design-tokens.ts — 框架无关的设计令牌
export const tokens = {
  // 色彩
  colorPrimary: '#3B82F6',
  colorPrimaryHover: '#2563EB',
  colorPrimaryActive: '#1D4ED8',
  colorPrimaryLight: '#EFF6FF',
  colorSuccess: '#10B981',
  colorWarning: '#F59E0B',
  colorError: '#EF4444',
  colorInfo: '#3B82F6',

  // 中性色
  colorTextPrimary: '#111827',
  colorTextSecondary: '#6B7280',
  colorBgPage: '#F9FAFB',
  colorBgCard: '#FFFFFF',
  colorBorder: '#E5E7EB',

  // 圆角
  borderRadius: 6,
  borderRadiusLg: 12,

  // 字号
  fontSize: 14,
  fontSizeLg: 16,
  fontSizeSm: 12,

  // 间距
  padding: 16,
  paddingSm: 12,
  paddingLg: 24,

  // 投影
  boxShadow: '0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)',
  boxShadowLg: '0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05)',

  // 字体
  fontFamily: '"Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif',
}
```

---

## Element Plus 主题定制

### 方式 1：CSS 变量覆盖（推荐，零构建配置）

```css
/* styles/element-theme.css */
:root {
  /* 主色 */
  --el-color-primary: #3B82F6;
  --el-color-primary-light-3: #93C5FD;
  --el-color-primary-light-5: #BFDBFE;
  --el-color-primary-light-7: #DBEAFE;
  --el-color-primary-light-8: #EFF6FF;
  --el-color-primary-light-9: #F5F9FF;
  --el-color-primary-dark-2: #2563EB;

  /* 功能色 */
  --el-color-success: #10B981;
  --el-color-warning: #F59E0B;
  --el-color-danger: #EF4444;
  --el-color-info: #6B7280;

  /* 圆角 */
  --el-border-radius-base: 6px;
  --el-border-radius-medium: 8px;
  --el-border-radius-small: 4px;
  --el-border-radius-large: 12px;
  --el-border-radius-round: 999px;

  /* 字号 */
  --el-font-size-base: 14px;
  --el-font-size-medium: 14px;
  --el-font-size-small: 13px;
  --el-font-size-extra-small: 12px;
  --el-font-size-large: 16px;
  --el-font-size-extra-large: 20px;

  /* 字体 */
  --el-font-family: "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;

  /* 边框 */
  --el-border-color: #E5E7EB;
  --el-border-color-light: #F3F4F6;
  --el-border-color-lighter: #F9FAFB;

  /* 背景 */
  --el-bg-color: #FFFFFF;
  --el-bg-color-page: #F9FAFB;
  --el-bg-color-overlay: #FFFFFF;

  /* 投影 */
  --el-box-shadow: 0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06);
  --el-box-shadow-light: 0 1px 2px rgba(0,0,0,0.05);
}

/* 暗色模式 */
html.dark {
  --el-color-primary: #60A5FA;
  --el-bg-color: #1E1E20;
  --el-bg-color-page: #18181B;
  --el-bg-color-overlay: #27272A;
  --el-border-color: #3F3F46;
  --el-text-color-primary: #F3F4F6;
  --el-text-color-regular: #D1D5DB;
}
```

```typescript
// main.ts
import 'element-plus/dist/index.css'
import './styles/element-theme.css'  // 覆盖变量放在后面
import 'element-plus/theme-chalk/dark/css-vars.css'  // 暗色模式
```

### 方式 2：SCSS 编译时覆盖（深度定制）

```scss
// styles/element-variables.scss
@forward 'element-plus/theme-chalk/src/common/var.scss' with (
  $colors: (
    'primary': (
      'base': #3B82F6,
    ),
    'success': (
      'base': #10B981,
    ),
    'warning': (
      'base': #F59E0B,
    ),
    'danger': (
      'base': #EF4444,
    ),
  ),
  $border-radius: (
    'base': 6px,
    'medium': 8px,
    'small': 4px,
    'large': 12px,
    'round': 999px,
  ),
);
```

```typescript
// vite.config.ts
export default defineConfig({
  css: {
    preprocessorOptions: {
      scss: {
        additionalData: `@use "@/styles/element-variables.scss" as *;`,
      },
    },
  },
})
```

---

## Ant Design 5 主题定制

### ConfigProvider Token

Ant Design 5 使用 Design Token 系统，分三层：Seed Token → Map Token → Alias Token。

```tsx
// App.tsx
import { ConfigProvider, theme } from 'antd'
import zhCN from 'antd/locale/zh_CN'

const App = () => (
  <ConfigProvider
    locale={zhCN}
    theme={{
      // Seed Token（会自动派生其他 Token）
      token: {
        // 色彩
        colorPrimary: '#3B82F6',
        colorSuccess: '#10B981',
        colorWarning: '#F59E0B',
        colorError: '#EF4444',
        colorInfo: '#3B82F6',

        // 圆角
        borderRadius: 6,
        borderRadiusLG: 12,
        borderRadiusSM: 4,

        // 字号
        fontSize: 14,
        fontSizeLG: 16,
        fontSizeSM: 12,

        // 字体
        fontFamily: '"Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif',

        // 间距
        padding: 16,
        paddingLG: 24,
        paddingSM: 12,
        paddingXS: 8,

        // 投影
        boxShadow: '0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)',
        boxShadowSecondary: '0 10px 15px -3px rgba(0,0,0,0.1), 0 4px 6px rgba(0,0,0,0.05)',

        // 线宽
        lineWidth: 1,

        // 控件高度
        controlHeight: 36,
        controlHeightLG: 44,
        controlHeightSM: 28,
      },

      // 组件级 Token（覆盖特定组件）
      components: {
        Button: {
          borderRadius: 8,
          controlHeight: 40,
          paddingContentHorizontal: 20,
        },
        Card: {
          borderRadiusLG: 12,
          paddingLG: 24,
        },
        Table: {
          borderRadius: 12,
          headerBg: '#F9FAFB',
          rowHoverBg: '#F3F4F6',
        },
        Modal: {
          borderRadiusLG: 16,
        },
        Input: {
          borderRadius: 8,
          controlHeight: 40,
        },
      },

      // 暗色模式算法
      algorithm: isDark ? theme.darkAlgorithm : theme.defaultAlgorithm,
    }}
  >
    <RouterView />
  </ConfigProvider>
)
```

### Ant Design 组件级精调

```tsx
// 使用 CSS-in-JS 扩展样式
const StyledTable = () => (
  <ConfigProvider
    theme={{
      components: {
        Table: {
          headerBg: '#F9FAFB',
          headerColor: '#374151',
          headerSortActiveBg: '#F3F4F6',
          rowHoverBg: '#F9FAFB',
          borderColor: '#E5E7EB',
          headerBorderRadius: 12,
          cellPaddingBlock: 14,
          cellPaddingInline: 16,
        },
      },
    }}
  >
    <Table {...props} />
  </ConfigProvider>
)
```

---

## Arco Design Vue 主题定制

### Less 变量覆盖

```less
// styles/arco-theme.less
@arcoblue-6: #3B82F6;     // 主色
@green-6: #10B981;         // 成功
@orange-6: #F59E0B;        // 警告
@red-6: #EF4444;           // 错误

@border-radius-small: 4px;
@border-radius-medium: 6px;
@border-radius-large: 12px;

@font-size-body-1: 12px;
@font-size-body-2: 13px;
@font-size-body-3: 14px;
@font-size-title-1: 16px;
@font-size-title-2: 20px;
@font-size-title-3: 24px;
```

```typescript
// vite.config.ts
export default defineConfig({
  css: {
    preprocessorOptions: {
      less: {
        modifyVars: {
          'arcoblue-6': '#3B82F6',
          'border-radius-medium': '6px',
        },
        javascriptEnabled: true,
      },
    },
  },
})
```

### CSS 变量覆盖

```css
/* Arco 也支持 CSS 变量 */
body {
  --primary-6: 59, 130, 246;  /* RGB 值 */
  --border-radius-small: 4px;
  --border-radius-medium: 6px;
  --border-radius-large: 12px;
}
```

---

## TDesign 主题定制

### CSS Token 覆盖

```css
/* styles/tdesign-theme.css */
:root, html[theme-mode="light"] {
  /* 品牌色 */
  --td-brand-color: #3B82F6;
  --td-brand-color-hover: #2563EB;
  --td-brand-color-active: #1D4ED8;
  --td-brand-color-disabled: #BFDBFE;
  --td-brand-color-light: #EFF6FF;
  --td-brand-color-focus: rgba(59, 130, 246, 0.2);

  /* 功能色 */
  --td-success-color: #10B981;
  --td-warning-color: #F59E0B;
  --td-error-color: #EF4444;

  /* 圆角 */
  --td-radius-small: 4px;
  --td-radius-default: 6px;
  --td-radius-medium: 8px;
  --td-radius-large: 12px;
  --td-radius-extraLarge: 16px;
  --td-radius-round: 999px;

  /* 字号 */
  --td-font-size-s: 12px;
  --td-font-size-base: 14px;
  --td-font-size-l: 16px;
  --td-font-size-xl: 20px;

  /* 投影 */
  --td-shadow-1: 0 1px 2px rgba(0, 0, 0, 0.05);
  --td-shadow-2: 0 1px 3px rgba(0, 0, 0, 0.1), 0 1px 2px rgba(0, 0, 0, 0.06);
  --td-shadow-3: 0 10px 15px -3px rgba(0, 0, 0, 0.1);

  /* 字体 */
  --td-font-family: "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;
}

/* 暗色模式 */
html[theme-mode="dark"] {
  --td-brand-color: #60A5FA;
  --td-bg-color-container: #1E1E20;
  --td-bg-color-page: #18181B;
  --td-border-level-1-color: #3F3F46;
  --td-text-color-primary: #F3F4F6;
}
```

---

## Naive UI 主题定制

### themeOverrides 对象

```typescript
// theme/naive-overrides.ts
import type { GlobalThemeOverrides } from 'naive-ui'

export const lightOverrides: GlobalThemeOverrides = {
  common: {
    primaryColor: '#3B82F6',
    primaryColorHover: '#2563EB',
    primaryColorPressed: '#1D4ED8',
    primaryColorSuppl: '#60A5FA',

    successColor: '#10B981',
    warningColor: '#F59E0B',
    errorColor: '#EF4444',
    infoColor: '#3B82F6',

    borderRadius: '6px',
    borderRadiusSmall: '4px',

    fontSize: '14px',
    fontSizeMedium: '14px',
    fontSizeSmall: '13px',
    fontSizeLarge: '16px',

    fontFamily: '"Noto Sans SC", "PingFang SC", sans-serif',

    bodyColor: '#F9FAFB',
    cardColor: '#FFFFFF',
    modalColor: '#FFFFFF',
    popoverColor: '#FFFFFF',

    borderColor: '#E5E7EB',
    dividerColor: '#F3F4F6',

    textColorBase: '#111827',
    textColor1: '#111827',
    textColor2: '#374151',
    textColor3: '#6B7280',

    boxShadow1: '0 1px 2px rgba(0,0,0,0.05)',
    boxShadow2: '0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06)',
    boxShadow3: '0 10px 15px -3px rgba(0,0,0,0.1)',
  },
  Button: {
    borderRadiusMedium: '8px',
    heightMedium: '40px',
    paddingMedium: '0 20px',
  },
  Card: {
    borderRadius: '12px',
    paddingMedium: '24px',
  },
  DataTable: {
    borderRadius: '12px',
    thColor: '#F9FAFB',
    tdColorHover: '#F3F4F6',
  },
  Modal: {
    borderRadius: '16px',
  },
  Input: {
    borderRadius: '8px',
    heightMedium: '40px',
  },
}
```

```vue
<!-- App.vue -->
<template>
  <n-config-provider
    :theme="isDark ? darkTheme : null"
    :theme-overrides="isDark ? darkOverrides : lightOverrides"
    :locale="zhCN"
    :date-locale="dateZhCN"
  >
    <RouterView />
  </n-config-provider>
</template>
```

---

## 通用组件样式增强

无论使用哪个组件库，以下全局 CSS 补丁可统一改善外观：

```css
/* 全局字体平滑 */
body {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}

/* 所有过渡默认时长 */
*,
*::before,
*::after {
  transition-duration: 150ms;
}

/* 聚焦可见性（替换浏览器丑陋的默认蓝色外线） */
:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary, #3B82F6),
              0 0 0 4px rgba(59, 130, 246, 0.2);
}

/* 自定义选中色 */
::selection {
  background-color: rgba(59, 130, 246, 0.2);
  color: inherit;
}
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 使用组件库默认主色（Element 蓝/Ant 蓝）不做定制 | 至少替换主色和圆角 |
| 每个组件单独写内联样式覆盖 | 统一 Theme 配置入口 |
| 不同组件库主题风格完全不同 | 共享设计令牌 → 分别映射 |
| 暗色模式只切换了组件库，自定义样式没适配 | 自定义 CSS 也要用 CSS 变量 |
| 字号/圆角不一致（按钮 8px 圆角，输入框 4px） | 统一定义梯度，全局应用 |
| `!important` 到处飞 | 正确使用 CSS 变量覆盖或 Token 系统 |
| 用 CDN 引入组件库默认样式，不可定制 | 用包管理器安装，按需引入 |
| 升级组件库后主题失效 | 使用官方推荐的定制方式，避免 hack |

---

## 主题定制检查清单

- [ ] 是否替换了主色为品牌色？
- [ ] 功能色（成功/警告/错误/信息）是否自定义？
- [ ] 圆角是否按设计系统梯度统一？
- [ ] 字号/字体是否覆盖为中文友好字体栈？
- [ ] 投影是否从默认调整为设计系统规范？
- [ ] 暗色模式是否正确配置？
- [ ] 通用全局补丁（字体平滑/选中色/焦点环）是否添加？
- [ ] 多个前端主题的视觉是否趋于一致？
