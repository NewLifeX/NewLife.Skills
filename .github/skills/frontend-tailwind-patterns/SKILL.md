---
name: frontend-tailwind-patterns
description: >
  Tailwind CSS 现代模式集：按钮/卡片/输入框常用类组合、毛玻璃效果 backdrop-blur、
  渐变色系、微动画（hover/focus/active 三态反馈）、自定义滚动条美化、
  group/peer 高级选择器、clsx + tailwind-merge 动态类名组合。
  适用于使用 Tailwind CSS 的前端项目组件开发和视觉美化任务。
argument-hint: >
  说明组件类型（按钮/卡片/表格/表单等）和视觉目标；
  如有特定品牌色或 Tailwind 版本约束，一并提供。
---

# Tailwind CSS 现代模式集

## 适用场景

- 使用 Tailwind CSS 开发前端组件
- 为 Cube API 版前端主题（Vue/React/Svelte）添加视觉美化
- 需要现成的 Tailwind 类组合 pattern 快速套用
- 从组件库默认样式升级到定制化视觉效果

---

## 按钮模式

### 基础按钮变体

```html
<!-- 主按钮（Primary） -->
<button class="inline-flex items-center justify-center
               px-4 py-2.5 rounded-lg
               bg-primary-500 text-white font-medium text-sm
               hover:bg-primary-600 active:bg-primary-700
               focus-visible:outline-none focus-visible:ring-2
               focus-visible:ring-primary-500/50 focus-visible:ring-offset-2
               disabled:opacity-50 disabled:cursor-not-allowed
               transition-colors duration-150">
  确认提交
</button>

<!-- 次按钮（Secondary / Outlined） -->
<button class="inline-flex items-center justify-center
               px-4 py-2.5 rounded-lg
               border border-gray-300 dark:border-zinc-600
               bg-white dark:bg-zinc-800
               text-gray-700 dark:text-gray-200 font-medium text-sm
               hover:bg-gray-50 dark:hover:bg-zinc-700
               active:bg-gray-100 dark:active:bg-zinc-600
               focus-visible:outline-none focus-visible:ring-2
               focus-visible:ring-primary-500/50 focus-visible:ring-offset-2
               transition-colors duration-150">
  取消
</button>

<!-- 幽灵按钮（Ghost） -->
<button class="inline-flex items-center justify-center
               px-4 py-2.5 rounded-lg
               text-gray-600 dark:text-gray-300 font-medium text-sm
               hover:bg-gray-100 dark:hover:bg-zinc-700
               active:bg-gray-200 dark:active:bg-zinc-600
               transition-colors duration-150">
  更多操作
</button>

<!-- 危险按钮 -->
<button class="inline-flex items-center justify-center
               px-4 py-2.5 rounded-lg
               bg-red-500 text-white font-medium text-sm
               hover:bg-red-600 active:bg-red-700
               focus-visible:ring-2 focus-visible:ring-red-500/50
               transition-colors duration-150">
  删除
</button>
```

### 按钮尺寸

```html
<!-- Small -->
<button class="px-3 py-1.5 text-xs rounded-md">小号</button>

<!-- Default -->
<button class="px-4 py-2.5 text-sm rounded-lg">默认</button>

<!-- Large -->
<button class="px-6 py-3 text-base rounded-lg">大号</button>
```

### 图标按钮

```html
<!-- 仅图标（圆形） -->
<button class="w-9 h-9 rounded-full
               flex items-center justify-center
               text-gray-500 dark:text-gray-400
               hover:bg-gray-100 dark:hover:bg-zinc-700
               hover:text-gray-700 dark:hover:text-gray-200
               transition-colors duration-150">
  <Icon name="settings" class="w-5 h-5" />
</button>

<!-- 带文字的图标按钮 -->
<button class="inline-flex items-center gap-2
               px-4 py-2.5 rounded-lg ...">
  <Icon name="add" class="w-4 h-4" />
  <span>新建</span>
</button>
```

---

## 卡片模式

### 基础卡片

```html
<div class="bg-white dark:bg-zinc-800
            rounded-xl border border-gray-200 dark:border-zinc-700
            shadow-sm hover:shadow-md
            transition-shadow duration-200
            overflow-hidden">
  <!-- 可选：卡片头部 -->
  <div class="px-6 py-4 border-b border-gray-100 dark:border-zinc-700">
    <h3 class="text-base font-semibold text-gray-800 dark:text-gray-100">
      卡片标题
    </h3>
  </div>
  <!-- 卡片内容 -->
  <div class="p-6">
    <p class="text-sm text-gray-600 dark:text-gray-400">
      卡片内容区域
    </p>
  </div>
</div>
```

### 可点击卡片（带交互反馈）

```html
<div class="bg-white dark:bg-zinc-800
            rounded-xl border border-gray-200 dark:border-zinc-700
            shadow-sm
            hover:shadow-md hover:border-primary-200 dark:hover:border-primary-800
            active:shadow-sm active:scale-[0.99]
            cursor-pointer
            transition-all duration-200
            p-6">
  <h3 class="font-semibold">可点击卡片</h3>
  <p class="text-sm text-gray-500 mt-2">点击有微缩 + 投影变化反馈</p>
</div>
```

### 渐变装饰卡片（统计卡）

```html
<div class="relative overflow-hidden rounded-xl p-6
            bg-gradient-to-br from-blue-500 to-blue-600
            text-white shadow-lg">
  <!-- 装饰圆 -->
  <div class="absolute -right-4 -top-4 w-24 h-24
              bg-white/10 rounded-full" />
  <div class="absolute -right-2 -bottom-6 w-32 h-32
              bg-white/5 rounded-full" />

  <!-- 内容 -->
  <div class="relative">
    <p class="text-sm text-white/80">总用户数</p>
    <p class="text-3xl font-bold mt-1">12,345</p>
    <p class="text-sm text-white/70 mt-2">
      较上月 <span class="text-green-300">+12.5%</span>
    </p>
  </div>
</div>
```

---

## 输入框模式

### 基础输入框

```html
<div class="space-y-1.5">
  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
    用户名
  </label>
  <input type="text"
         placeholder="请输入用户名"
         class="w-full px-3 py-2.5 rounded-lg
                bg-white dark:bg-zinc-800
                border border-gray-300 dark:border-zinc-600
                text-gray-900 dark:text-gray-100
                placeholder:text-gray-400 dark:placeholder:text-gray-500
                focus:outline-none focus:border-primary-500
                focus:ring-2 focus:ring-primary-500/20
                disabled:bg-gray-50 dark:disabled:bg-zinc-700
                disabled:cursor-not-allowed
                transition-colors duration-150
                text-sm" />
</div>
```

### 带图标输入框

```html
<div class="relative">
  <!-- 左侧图标 -->
  <span class="absolute left-3 top-1/2 -translate-y-1/2
               text-gray-400 dark:text-gray-500 pointer-events-none">
    <Icon name="search" class="w-5 h-5" />
  </span>
  <input type="text" placeholder="搜索..."
         class="w-full pl-10 pr-4 py-2.5 rounded-lg
                bg-white dark:bg-zinc-800
                border border-gray-300 dark:border-zinc-600
                focus:outline-none focus:border-primary-500
                focus:ring-2 focus:ring-primary-500/20
                text-sm transition-colors duration-150" />
</div>
```

---

## 毛玻璃效果

### 模态遮罩

```html
<!-- 背景毛玻璃遮罩 -->
<div class="fixed inset-0 bg-black/40 backdrop-blur-sm z-50" />

<!-- 导航栏毛玻璃 -->
<header class="sticky top-0 z-30
               bg-white/80 dark:bg-zinc-900/80
               backdrop-blur-md backdrop-saturate-150
               border-b border-gray-200/50 dark:border-zinc-700/50">
  ...
</header>
```

### 毛玻璃卡片

```html
<div class="bg-white/70 dark:bg-zinc-800/70
            backdrop-blur-xl
            border border-white/20 dark:border-zinc-700/50
            rounded-2xl shadow-lg
            p-6">
  <h3 class="font-semibold">毛玻璃卡片</h3>
</div>
```

---

## 渐变色

### 文字渐变

```html
<h1 class="text-4xl font-bold
           bg-gradient-to-r from-blue-500 to-purple-600
           bg-clip-text text-transparent">
  渐变标题
</h1>
```

### 按钮渐变

```html
<button class="px-6 py-3 rounded-xl
               bg-gradient-to-r from-blue-500 to-purple-600
               hover:from-blue-600 hover:to-purple-700
               text-white font-semibold
               shadow-lg shadow-blue-500/25
               transition-all duration-200">
  渐变按钮
</button>
```

### 背景渐变

```html
<!-- 页面渐变背景 -->
<div class="min-h-screen
            bg-gradient-to-br from-blue-50 via-white to-purple-50
            dark:from-zinc-900 dark:via-zinc-900 dark:to-zinc-800">
  ...
</div>

<!-- 装饰性光晕 -->
<div class="absolute -z-10 top-0 left-1/4
            w-96 h-96 rounded-full
            bg-gradient-to-r from-blue-400/20 to-purple-400/20
            blur-3xl" />
```

---

## 微动画

### hover/focus/active 三态

```html
<!-- 三态反馈模板（所有交互元素通用） -->
<div class="
  /* 默认态 */
  bg-white border-gray-200 shadow-sm

  /* Hover 态：略浮起 */
  hover:shadow-md hover:border-gray-300

  /* Active 态：按下反馈 */
  active:shadow-sm active:scale-[0.98]

  /* Focus 态：可访问性环 */
  focus-visible:outline-none focus-visible:ring-2
  focus-visible:ring-primary-500/50

  /* 过渡 */
  transition-all duration-200
">
```

### 加载旋转

```html
<!-- 标准 Spinner -->
<div class="w-5 h-5 border-2 border-primary-500/30 border-t-primary-500
            rounded-full animate-spin" />

<!-- 小号（内联） -->
<div class="w-4 h-4 border-2 border-white/30 border-t-white
            rounded-full animate-spin" />
```

### 脉冲占位

```html
<!-- 骨架屏脉冲 -->
<div class="animate-pulse space-y-4">
  <div class="h-4 bg-gray-200 dark:bg-zinc-700 rounded w-3/4" />
  <div class="h-4 bg-gray-200 dark:bg-zinc-700 rounded w-1/2" />
  <div class="h-32 bg-gray-200 dark:bg-zinc-700 rounded-lg" />
</div>
```

---

## 自定义滚动条

```css
/* 全局细滚动条 */
::-webkit-scrollbar {
  width: 6px;
  height: 6px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.15);
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: rgba(0, 0, 0, 0.25);
}

/* 暗色模式滚动条 */
.dark ::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.15);
}

.dark ::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.25);
}
```

Tailwind 选择器精确控制：

```html
<!-- 仅 hover 时显示滚动条 -->
<div class="overflow-y-auto
            [&::-webkit-scrollbar]:w-1.5
            [&::-webkit-scrollbar-track]:bg-transparent
            [&::-webkit-scrollbar-thumb]:bg-gray-300/0
            hover:[&::-webkit-scrollbar-thumb]:bg-gray-300/50
            dark:hover:[&::-webkit-scrollbar-thumb]:bg-zinc-600/50
            [&::-webkit-scrollbar-thumb]:rounded-full
            [&::-webkit-scrollbar-thumb]:transition-colors">
  ...
</div>
```

---

## group / peer 高级选择器

### group：父元素状态影响子元素

```html
<!-- hover 父卡片时，子元素变色 -->
<div class="group cursor-pointer p-4 rounded-xl
            border border-gray-200 hover:border-primary-300
            transition-colors duration-200">

  <h3 class="font-semibold text-gray-700
             group-hover:text-primary-600
             transition-colors duration-200">
    卡片标题
  </h3>

  <p class="text-sm text-gray-500
            group-hover:text-gray-700
            transition-colors duration-200">
    描述文字
  </p>

  <!-- hover 时显示的操作按钮 -->
  <div class="opacity-0 group-hover:opacity-100
              transition-opacity duration-200 mt-3">
    <button class="text-sm text-primary-500">查看详情 →</button>
  </div>
</div>
```

### group 命名（嵌套场景）

```html
<div class="group/card hover:shadow-lg">
  <div class="group/header">
    <!-- group-hover/card 匹配外层，group-hover/header 匹配内层 -->
    <h3 class="group-hover/card:text-primary-600
               group-hover/header:underline">
      两层 group 控制
    </h3>
  </div>
</div>
```

### peer：兄弟元素状态影响后续元素

```html
<!-- 输入框聚焦时，标签和提示文字变色 -->
<div class="relative">
  <input class="peer w-full px-3 py-2.5 rounded-lg border
                border-gray-300 focus:border-primary-500
                placeholder-transparent" placeholder=" " />

  <!-- 浮动标签（peer-focus + peer-placeholder-shown） -->
  <label class="absolute left-3 top-2.5 text-sm text-gray-400
                peer-focus:-top-2.5 peer-focus:left-2
                peer-focus:text-xs peer-focus:text-primary-500
                peer-focus:bg-white dark:peer-focus:bg-zinc-800
                peer-focus:px-1
                peer-[:not(:placeholder-shown)]:-top-2.5
                peer-[:not(:placeholder-shown)]:left-2
                peer-[:not(:placeholder-shown)]:text-xs
                peer-[:not(:placeholder-shown)]:bg-white
                peer-[:not(:placeholder-shown)]:px-1
                transition-all duration-200
                pointer-events-none">
    用户名
  </label>
</div>
```

---

## clsx + tailwind-merge

安装：

```bash
pnpm add clsx tailwind-merge
```

工具函数：

```typescript
// utils/cn.ts
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

/** 合并 Tailwind 类名，自动解决冲突 */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

使用：

```tsx
function Button({ variant = 'primary', size = 'md', className, ...props }) {
  return (
    <button
      className={cn(
        // 基础样式
        'inline-flex items-center justify-center font-medium rounded-lg transition-colors',

        // 变体
        variant === 'primary' && 'bg-primary-500 text-white hover:bg-primary-600',
        variant === 'secondary' && 'border border-gray-300 text-gray-700 hover:bg-gray-50',
        variant === 'ghost' && 'text-gray-600 hover:bg-gray-100',
        variant === 'danger' && 'bg-red-500 text-white hover:bg-red-600',

        // 尺寸
        size === 'sm' && 'px-3 py-1.5 text-xs',
        size === 'md' && 'px-4 py-2.5 text-sm',
        size === 'lg' && 'px-6 py-3 text-base',

        // 外部传入的类名（可覆盖以上所有）
        className,
      )}
      {...props}
    />
  )
}

// 使用时可覆盖任何样式
<Button variant="primary" className="rounded-full px-8">圆角按钮</Button>
```

---

## Badge 徽章

```html
<!-- 状态徽章 -->
<span class="inline-flex items-center px-2.5 py-0.5
             text-xs font-medium rounded-full
             bg-green-100 text-green-700
             dark:bg-green-900/30 dark:text-green-400">
  正常
</span>

<span class="inline-flex items-center px-2.5 py-0.5
             text-xs font-medium rounded-full
             bg-red-100 text-red-700
             dark:bg-red-900/30 dark:text-red-400">
  异常
</span>

<span class="inline-flex items-center px-2.5 py-0.5
             text-xs font-medium rounded-full
             bg-yellow-100 text-yellow-700
             dark:bg-yellow-900/30 dark:text-yellow-400">
  警告
</span>

<!-- 带圆点的徽章 -->
<span class="inline-flex items-center gap-1.5 px-2.5 py-0.5
             text-xs font-medium rounded-full
             bg-blue-50 text-blue-700
             dark:bg-blue-900/30 dark:text-blue-400">
  <span class="w-1.5 h-1.5 rounded-full bg-blue-500" />
  运行中
</span>
```

---

## 头像

```html
<!-- 用户头像（带默认字母） -->
<div class="w-10 h-10 rounded-full overflow-hidden
            bg-primary-100 dark:bg-primary-900/30
            flex items-center justify-center
            text-sm font-semibold text-primary-600 dark:text-primary-400">
  <!-- 有图片时 -->
  <img v-if="avatarUrl" :src="avatarUrl" class="w-full h-full object-cover" />
  <!-- 无图片时显示首字母 -->
  <span v-else>{{ userName.charAt(0).toUpperCase() }}</span>
</div>

<!-- AI 头像（渐变） -->
<div class="w-8 h-8 rounded-full
            bg-gradient-to-br from-blue-500 to-purple-600
            flex items-center justify-center text-white">
  <Icon name="smart_toy" class="w-5 h-5" />
</div>
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 按钮没有 hover/active/focus 态 | 三态完整：hover 变色 + active 加深 + focus ring |
| 类名超长不可维护 | 提取 `cn()` 工具函数 + 组件化 |
| Tailwind 类冲突（如 `px-4 px-6`） | 使用 `tailwind-merge` 自动解决 |
| 毛玻璃效果在暗色下不明显 | 增加 `bg-black/40`（暗色）或 `bg-white/70`（亮色）底色 |
| 渐变色在暗色下太亮 | 暗色下降低渐变饱和度或切换为渐变方向 |
| 动画时长 > 300ms | 交互反馈 ≤ 200ms，页面切换 ≤ 300ms |
| 没有 `disabled` 态样式 | 添加 `disabled:opacity-50 disabled:cursor-not-allowed` |
| 焦点没有可见指示 | 添加 `focus-visible:ring-2 focus-visible:ring-primary/50` |

---

## 参考实现

StarChat Web 的 Tailwind 实践：
- 使用 `clsx` + `tailwind-merge` 组合动态类名
- 按钮 4 种变体（primary/secondary/ghost/danger）× 3 种尺寸
- Modal 双层毛玻璃：`bg-black/40 backdrop-blur-sm` 遮罩 + 白色内容
- 消息气泡右上角尖角：`rounded-2xl rounded-tr-sm`
- AI 头像渐变：`bg-gradient-to-br from-blue-500 to-purple-600`
- 代码块 hover 显示复制按钮：`group/code` + `opacity-0 group-hover/code:opacity-100`
- 自定义细滚动条：宽 4px，默认透明，hover 半透明显现
