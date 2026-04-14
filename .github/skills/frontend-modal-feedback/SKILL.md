---
name: frontend-modal-feedback
description: >
  弹窗与反馈组件美化：模态框（居中/抽屉/全屏三形态）、确认弹窗、
  Toast 通知（成功/错误/警告/信息四态）、Notification 推送、
  加载遮罩、空状态页、错误页（403/404/500）、进度反馈。
  适用于全局反馈组件定制、弹窗交互优化、错误页面美化等任务。
argument-hint: >
  说明反馈组件类型（弹窗/通知/空状态/错误页）和使用框架；
  如有动画需求（入场/退场过渡），一并提供。
---

# 弹窗与反馈组件美化

## 适用场景

- 后台管理系统的弹窗确认交互
- 全局 Toast / Notification 通知样式
- 操作反馈（成功/失败/加载）的视觉一致性
- 空状态页和错误页面设计
- 抽屉式侧滑面板

---

## 模态框

### 居中模态框

```html
<!-- 遮罩层 -->
<div class="fixed inset-0 z-50 flex items-center justify-center p-4">
  <!-- 毛玻璃背景 -->
  <div class="absolute inset-0 bg-black/40 backdrop-blur-sm"
       @click="close" />

  <!-- 弹窗内容 -->
  <div class="relative w-full max-w-lg
              bg-white dark:bg-zinc-800
              rounded-2xl shadow-2xl
              animate-[modalIn_0.2s_ease-out]
              overflow-hidden">

    <!-- 头部 -->
    <div class="flex items-center justify-between px-6 py-4
                border-b border-gray-100 dark:border-zinc-700">
      <h3 class="text-lg font-semibold text-gray-800 dark:text-gray-100">
        {{ title }}
      </h3>
      <button @click="close"
              class="p-1.5 rounded-lg
                     text-gray-400 hover:text-gray-600
                     dark:hover:text-gray-200
                     hover:bg-gray-100 dark:hover:bg-zinc-700
                     transition-colors">
        <Icon name="close" class="w-5 h-5" />
      </button>
    </div>

    <!-- 内容区 -->
    <div class="px-6 py-5 max-h-[60vh] overflow-y-auto">
      <slot />
    </div>

    <!-- 底部操作 -->
    <div class="flex items-center justify-end gap-3
                px-6 py-4
                border-t border-gray-100 dark:border-zinc-700
                bg-gray-50/50 dark:bg-zinc-800/50">
      <button @click="close"
              class="px-4 py-2.5 rounded-lg
                     border border-gray-300 dark:border-zinc-600
                     text-sm font-medium text-gray-700 dark:text-gray-300
                     hover:bg-gray-50 dark:hover:bg-zinc-700
                     transition-colors">
        取消
      </button>
      <button @click="confirm"
              class="px-4 py-2.5 rounded-lg
                     bg-primary-500 text-white text-sm font-medium
                     hover:bg-primary-600
                     transition-colors">
        确认
      </button>
    </div>
  </div>
</div>
```

### 模态框入场动画

```css
@keyframes modalIn {
  from {
    opacity: 0;
    transform: scale(0.95) translateY(8px);
  }
  to {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
}

@keyframes modalOut {
  from {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
  to {
    opacity: 0;
    transform: scale(0.95) translateY(8px);
  }
}
```

### 抽屉（Drawer）

```html
<!-- 右侧抽屉 -->
<div class="fixed inset-0 z-50 flex justify-end">
  <!-- 遮罩 -->
  <div class="absolute inset-0 bg-black/40 backdrop-blur-sm"
       @click="close" />

  <!-- 抽屉内容 -->
  <div class="relative w-full max-w-md
              bg-white dark:bg-zinc-800
              shadow-2xl
              animate-[slideInRight_0.25s_ease-out]
              flex flex-col h-full">
    <!-- 头部 -->
    <div class="flex items-center justify-between px-6 py-4
                border-b border-gray-200 dark:border-zinc-700
                flex-shrink-0">
      <h3 class="text-lg font-semibold">{{ title }}</h3>
      <button @click="close" class="p-1.5 rounded-lg
                     text-gray-400 hover:text-gray-600
                     hover:bg-gray-100 dark:hover:bg-zinc-700
                     transition-colors">
        <Icon name="close" class="w-5 h-5" />
      </button>
    </div>

    <!-- 滚动内容 -->
    <div class="flex-1 overflow-y-auto px-6 py-5">
      <slot />
    </div>

    <!-- 底部操作 -->
    <div class="flex items-center justify-end gap-3
                px-6 py-4 border-t border-gray-200 dark:border-zinc-700
                flex-shrink-0">
      <button @click="close" class="px-4 py-2.5 rounded-lg border ...">
        取消
      </button>
      <button @click="confirm" class="px-4 py-2.5 rounded-lg bg-primary-500 ...">
        确认
      </button>
    </div>
  </div>
</div>
```

```css
@keyframes slideInRight {
  from { transform: translateX(100%); }
  to   { transform: translateX(0); }
}
```

---

## 确认弹窗

### 危险操作确认

```html
<div class="fixed inset-0 z-50 flex items-center justify-center p-4">
  <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" />

  <div class="relative w-full max-w-sm bg-white dark:bg-zinc-800
              rounded-2xl shadow-2xl p-6 text-center
              animate-[modalIn_0.2s_ease-out]">
    <!-- 警告图标 -->
    <div class="w-14 h-14 mx-auto mb-4 rounded-full
                bg-red-100 dark:bg-red-900/20
                flex items-center justify-center">
      <Icon name="warning" class="w-7 h-7 text-red-500" />
    </div>

    <h3 class="text-lg font-semibold text-gray-800 dark:text-gray-100">
      确认删除？
    </h3>
    <p class="text-sm text-gray-500 dark:text-gray-400 mt-2">
      删除后数据将无法恢复，确定要继续吗？
    </p>

    <div class="flex items-center gap-3 mt-6">
      <button @click="close"
              class="flex-1 px-4 py-2.5 rounded-lg border
                     border-gray-300 dark:border-zinc-600
                     text-sm font-medium text-gray-700 dark:text-gray-300
                     hover:bg-gray-50 dark:hover:bg-zinc-700
                     transition-colors">
        取消
      </button>
      <button @click="confirmDelete"
              class="flex-1 px-4 py-2.5 rounded-lg
                     bg-red-500 text-white text-sm font-medium
                     hover:bg-red-600
                     transition-colors">
        确认删除
      </button>
    </div>
  </div>
</div>
```

---

## Toast 通知

### 四种状态

```html
<!-- Toast 容器（固定在右上角） -->
<div class="fixed top-4 right-4 z-[100] space-y-3 w-80">

  <!-- 成功 -->
  <div class="flex items-start gap-3 p-4
              bg-white dark:bg-zinc-800
              rounded-xl border border-gray-200 dark:border-zinc-700
              shadow-lg
              animate-[slideInRight_0.3s_ease-out]">
    <div class="w-8 h-8 rounded-full bg-green-100 dark:bg-green-900/20
                flex items-center justify-center flex-shrink-0">
      <Icon name="check_circle" class="w-5 h-5 text-green-500" />
    </div>
    <div class="flex-1 min-w-0">
      <p class="text-sm font-medium text-gray-800 dark:text-gray-100">
        操作成功
      </p>
      <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
        数据已保存
      </p>
    </div>
    <button class="text-gray-400 hover:text-gray-600
                   dark:hover:text-gray-200 transition-colors">
      <Icon name="close" class="w-4 h-4" />
    </button>
  </div>

  <!-- 错误 -->
  <div class="flex items-start gap-3 p-4 bg-white dark:bg-zinc-800
              rounded-xl border border-red-200 dark:border-red-900/50
              shadow-lg">
    <div class="w-8 h-8 rounded-full bg-red-100 dark:bg-red-900/20
                flex items-center justify-center flex-shrink-0">
      <Icon name="error" class="w-5 h-5 text-red-500" />
    </div>
    <div class="flex-1">
      <p class="text-sm font-medium text-gray-800 dark:text-gray-100">
        操作失败
      </p>
      <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
        网络错误，请稍后重试
      </p>
    </div>
    <button class="text-gray-400 hover:text-gray-600 transition-colors">
      <Icon name="close" class="w-4 h-4" />
    </button>
  </div>

  <!-- 警告 -->
  <div class="flex items-start gap-3 p-4 bg-white dark:bg-zinc-800
              rounded-xl border border-yellow-200 dark:border-yellow-900/50
              shadow-lg">
    <div class="w-8 h-8 rounded-full bg-yellow-100 dark:bg-yellow-900/20
                flex items-center justify-center flex-shrink-0">
      <Icon name="warning" class="w-5 h-5 text-yellow-500" />
    </div>
    <div class="flex-1">
      <p class="text-sm font-medium">注意</p>
      <p class="text-xs text-gray-500 mt-0.5">该操作不可逆</p>
    </div>
  </div>

  <!-- 信息 -->
  <div class="flex items-start gap-3 p-4 bg-white dark:bg-zinc-800
              rounded-xl border border-blue-200 dark:border-blue-900/50
              shadow-lg">
    <div class="w-8 h-8 rounded-full bg-blue-100 dark:bg-blue-900/20
                flex items-center justify-center flex-shrink-0">
      <Icon name="info" class="w-5 h-5 text-blue-500" />
    </div>
    <div class="flex-1">
      <p class="text-sm font-medium">提示</p>
      <p class="text-xs text-gray-500 mt-0.5">新版本已发布</p>
    </div>
  </div>
</div>
```

### Toast 自动消失进度条

```html
<div class="relative overflow-hidden rounded-xl ...">
  <!-- Toast 内容 -->
  ...
  <!-- 底部进度条（5 秒后消失） -->
  <div class="absolute bottom-0 left-0 right-0 h-0.5">
    <div class="h-full bg-green-500
                animate-[shrink_5s_linear_forwards]" />
  </div>
</div>
```

```css
@keyframes shrink {
  from { width: 100%; }
  to   { width: 0%; }
}
```

---

## 加载遮罩

### 全屏加载

```html
<div class="fixed inset-0 z-[200]
            bg-white/80 dark:bg-zinc-900/80
            backdrop-blur-sm
            flex flex-col items-center justify-center gap-4">
  <div class="w-10 h-10 border-3 border-primary-500/30 border-t-primary-500
              rounded-full animate-spin" />
  <p class="text-sm text-gray-600 dark:text-gray-400">加载中...</p>
</div>
```

### 局部加载（覆盖在卡片上）

```html
<div class="relative">
  <!-- 卡片内容 -->
  <div class="...">...</div>

  <!-- 加载遮罩 -->
  <div v-if="loading"
       class="absolute inset-0 z-10
              bg-white/60 dark:bg-zinc-800/60
              backdrop-blur-[2px]
              rounded-xl
              flex items-center justify-center">
    <div class="w-6 h-6 border-2 border-primary-500/30 border-t-primary-500
                rounded-full animate-spin" />
  </div>
</div>
```

---

## 空状态页

```html
<div class="flex flex-col items-center justify-center py-20 px-4">
  <!-- 插画/图标 -->
  <div class="w-32 h-32 mb-6 text-gray-300 dark:text-zinc-600">
    <svg viewBox="0 0 128 128" fill="none" class="w-full h-full">
      <rect x="24" y="28" width="80" height="60" rx="12"
            stroke="currentColor" stroke-width="2" />
      <path d="M24 48h80" stroke="currentColor" stroke-width="2" />
      <circle cx="64" cy="72" r="8" stroke="currentColor" stroke-width="2" />
      <path d="M56 80l8 8 8-8" stroke="currentColor" stroke-width="2"
            stroke-linecap="round" stroke-linejoin="round" />
    </svg>
  </div>

  <h3 class="text-lg font-semibold text-gray-600 dark:text-gray-300">
    暂无数据
  </h3>
  <p class="text-sm text-gray-400 dark:text-gray-500 mt-2 max-w-xs text-center">
    还没有任何记录，点击下方按钮开始创建
  </p>
  <button class="mt-6 px-6 py-2.5 rounded-lg
                 bg-primary-500 text-white text-sm font-medium
                 hover:bg-primary-600 transition-colors
                 inline-flex items-center gap-2">
    <Icon name="add" class="w-4 h-4" />
    新建记录
  </button>
</div>
```

---

## 错误页面

### 404 页面

```html
<div class="min-h-screen flex flex-col items-center justify-center px-4
            bg-gray-50 dark:bg-zinc-900">
  <p class="text-8xl font-bold text-primary-500/20">404</p>
  <h1 class="text-2xl font-bold text-gray-800 dark:text-gray-100 mt-4">
    页面不存在
  </h1>
  <p class="text-gray-500 dark:text-gray-400 mt-2">
    您访问的页面不存在或已被移除
  </p>
  <div class="flex items-center gap-3 mt-8">
    <button @click="$router.back()"
            class="px-5 py-2.5 rounded-lg border border-gray-300
                   dark:border-zinc-600
                   text-sm font-medium text-gray-700 dark:text-gray-300
                   hover:bg-gray-50 dark:hover:bg-zinc-700
                   transition-colors">
      返回上页
    </button>
    <a href="/"
       class="px-5 py-2.5 rounded-lg bg-primary-500 text-white
              text-sm font-medium hover:bg-primary-600
              transition-colors">
      回到首页
    </a>
  </div>
</div>
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 弹窗没有遮罩模糊 | `backdrop-blur-sm` + 半透明黑色遮罩 |
| 弹窗无入场动画 | scale(0.95) + opacity 渐入（200ms） |
| 弹窗关闭按钮太小不好点 | 至少 36×36px 点击区域 |
| Toast 没有分类图标（全靠文字色） | 圆形图标 + 颜色区分 4 种状态 |
| Toast 永远不消失 | 自动消失 5s + 进度条 + x 关闭 |
| 确认弹窗没有图标和颜色区分 | 危险用红色警告图标，通用用蓝色信息图标 |
| 空状态只有文字"暂无" | 插画 + 描述 + 行动按钮 |
| 加载中整个页面白屏 | 骨架屏或毛玻璃遮罩 + Spinner |
| 错误页面丑陋或空白 | 自定义 404/403/500 页面 |
| 抽屉没有过渡动画 | `translateX(100%)→0` 滑入 |
