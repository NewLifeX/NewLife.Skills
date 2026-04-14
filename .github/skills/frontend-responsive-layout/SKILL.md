---
name: frontend-responsive-layout
description: >
  响应式布局与导航设计：断点策略、后台管理侧边栏折叠模式、移动端适配（底部导航/抽屉菜单/全屏 Modal）、
  表格窄屏横滚与卡片切换、Container Query 现代用法。
  适用于优化后台管理系统的多端适配、移动端体验改进、响应式布局审查等任务。
argument-hint: >
  说明场景：是后台管理系统还是 C 端应用；当前断点设置和主要问题；
  目标设备范围（仅桌面/桌面+平板/全端适配）。
---

# 响应式布局与导航

## 适用场景

- 后台管理系统的多端适配（桌面 + 平板 + 手机）
- 侧边栏 + 内容区的经典布局响应式改造
- 数据密集型表格在窄屏下的展示方案
- 移动端导航模式选择（底部 Tab / 汉堡菜单 / 抽屉）
- 使用 Container Query 实现组件级响应式

---

## 断点策略

### 推荐断点

| 断点名 | 宽度 | 设备 | 布局策略 |
|--------|------|------|---------|
| `sm` | ≥ 640px | 大手机横屏 | 单列，底部导航 |
| `md` | ≥ 768px | 平板竖屏 | 侧边栏可折叠 |
| `lg` | ≥ 1024px | 平板横屏/小笔记本 | 侧边栏展开 |
| `xl` | ≥ 1280px | 标准桌面 | 完整布局 |
| `2xl` | ≥ 1536px | 大屏 | 宽松布局 |

### 设计优先级

```
后台管理系统：桌面优先（Desktop First）
   → 先设计 1280px+ 完整布局
   → 逐步缩减：折叠侧边栏 → 隐藏侧边栏 → 单列堆叠

C 端应用：移动优先（Mobile First）
   → 先设计 375px 单列布局
   → 逐步扩展：显示侧边栏 → 多列网格 → 宽松间距
```

---

## 经典后台布局

### 基础结构

```
┌────────────────────────────────────────────────────┐
│ Header (h-16, 固定顶部)                              │
├──────────┬─────────────────────────────────────────┤
│ Sidebar  │ Main Content                             │
│ w-60     │ flex-1                                   │
│ (固定左侧) │ ┌─────────────────────────────────────┐ │
│          │ │ Breadcrumb                           │ │
│ • 菜单项  │ │ Page Title                           │ │
│ • 子菜单  │ │                                      │ │
│          │ │ Content Area                          │ │
│          │ │ (overflow-auto)                       │ │
│          │ │                                      │ │
│          │ └─────────────────────────────────────┘ │
└──────────┴─────────────────────────────────────────┘
```

### Tailwind 实现

```html
<div class="min-h-screen bg-gray-50 dark:bg-zinc-900">
  <!-- Header -->
  <header class="fixed top-0 left-0 right-0 h-16 bg-white dark:bg-zinc-800
                 border-b border-gray-200 dark:border-zinc-700 z-30
                 flex items-center px-4">
    <!-- 移动端汉堡按钮 -->
    <button class="lg:hidden p-2 rounded-md hover:bg-gray-100
                   dark:hover:bg-zinc-700" @click="toggleSidebar">
      <MenuIcon class="w-5 h-5" />
    </button>
    <!-- Logo / 标题 -->
    <div class="flex-1">...</div>
    <!-- 用户菜单 -->
    <div>...</div>
  </header>

  <div class="flex pt-16">
    <!-- Sidebar -->
    <aside class="fixed left-0 top-16 bottom-0 z-20
                  w-60 bg-white dark:bg-zinc-800
                  border-r border-gray-200 dark:border-zinc-700
                  overflow-y-auto
                  transition-transform duration-300
                  lg:translate-x-0"
           :class="sidebarOpen ? 'translate-x-0' : '-translate-x-full'">
      <nav class="p-4 space-y-1">...</nav>
    </aside>

    <!-- Mobile Overlay -->
    <div v-if="sidebarOpen"
         class="fixed inset-0 bg-black/40 z-10 lg:hidden"
         @click="closeSidebar" />

    <!-- Main Content -->
    <main class="flex-1 lg:ml-60 p-6 min-h-[calc(100vh-4rem)]">
      <slot />
    </main>
  </div>
</div>
```

---

## 侧边栏模式

### 三种状态

| 状态 | 宽度 | 触发条件 | 展示 |
|------|------|---------|------|
| **展开** | 240px (w-60) | 桌面默认 (≥ 1024px) | 图标 + 文字 |
| **折叠** | 64px (w-16) | 用户手动折叠 / 平板 | 仅图标，hover 展开子菜单 |
| **隐藏** | 0px | 移动端 (< 768px) | 汉堡按钮触发抽屉 |

### 折叠态实现

```html
<!-- 侧边栏 -->
<aside :class="collapsed ? 'w-16' : 'w-60'"
       class="transition-[width] duration-300 overflow-hidden">

  <!-- 菜单项 -->
  <div class="flex items-center px-3 py-2.5 rounded-lg
              hover:bg-gray-100 dark:hover:bg-zinc-700
              cursor-pointer group">
    <span class="w-5 h-5 flex-shrink-0">
      <Icon :name="item.icon" />
    </span>

    <!-- 折叠时文字隐藏 -->
    <span :class="collapsed ? 'opacity-0 w-0' : 'opacity-100 ml-3'"
          class="transition-all duration-300 whitespace-nowrap overflow-hidden">
      {{ item.label }}
    </span>
  </div>
</aside>

<!-- 折叠按钮 -->
<button @click="collapsed = !collapsed"
        class="hidden lg:flex absolute -right-3 top-20
               w-6 h-6 rounded-full bg-white dark:bg-zinc-700
               border border-gray-200 dark:border-zinc-600
               items-center justify-center shadow-sm
               hover:bg-gray-50 dark:hover:bg-zinc-600
               transition-colors">
  <ChevronIcon :class="collapsed ? 'rotate-180' : ''"
               class="w-4 h-4 transition-transform" />
</button>
```

---

## 移动端适配

### 导航方案选择

| 方案 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| **抽屉菜单** | 后台管理系统 | 完整菜单结构、与桌面版一致 | 操作步骤多 |
| **底部 Tab** | C 端应用、简单后台 | 一键切换、拇指可达 | 最多 5 个入口 |
| **顶部下拉** | 信息展示类 | 不占底部空间 | 遮挡内容 |

### 底部导航栏

```html
<!-- 底部 Tab 导航（仅移动端显示） -->
<nav class="fixed bottom-0 left-0 right-0 md:hidden
            bg-white dark:bg-zinc-800
            border-t border-gray-200 dark:border-zinc-700
            flex items-center justify-around
            h-14 px-2 z-30
            safe-area-inset-bottom">

  <button v-for="tab in tabs" :key="tab.path"
          @click="navigate(tab.path)"
          :class="isActive(tab) ? 'text-primary' : 'text-gray-500 dark:text-gray-400'"
          class="flex flex-col items-center justify-center
                 flex-1 h-full space-y-0.5
                 transition-colors duration-150">
    <Icon :name="tab.icon" class="w-5 h-5" />
    <span class="text-xs">{{ tab.label }}</span>
  </button>
</nav>

<!-- 主内容区增加底部安全间距 -->
<main class="pb-14 md:pb-0">...</main>
```

### 安全区域（iOS 刘海屏）

```css
/* 底部导航安全区域 */
.safe-area-inset-bottom {
  padding-bottom: env(safe-area-inset-bottom);
}

/* 顶部安全区域（全屏应用） */
.safe-area-inset-top {
  padding-top: env(safe-area-inset-top);
}
```

---

## 表格响应式

数据密集型表格在移动端是最大挑战。三种方案：

### 方案 1：横向滚动（推荐，最通用）

```html
<div class="overflow-x-auto -mx-4 px-4 md:mx-0 md:px-0">
  <table class="min-w-[800px] w-full">
    <!-- 固定关键列 -->
    <thead>
      <tr>
        <th class="sticky left-0 bg-white dark:bg-zinc-800 z-10">名称</th>
        <th>状态</th>
        <th>创建时间</th>
        <th>更新时间</th>
        <th class="sticky right-0 bg-white dark:bg-zinc-800 z-10">操作</th>
      </tr>
    </thead>
  </table>
</div>
```

### 方案 2：卡片切换（适合少量数据）

```html
<!-- 桌面：表格 -->
<table class="hidden md:table w-full">...</table>

<!-- 移动端：卡片列表 -->
<div class="md:hidden space-y-3">
  <div v-for="item in data"
       class="bg-white dark:bg-zinc-800
              rounded-lg border border-gray-200 dark:border-zinc-700
              p-4 space-y-2">
    <div class="flex justify-between items-center">
      <span class="font-medium">{{ item.name }}</span>
      <Badge :type="item.status" />
    </div>
    <div class="text-sm text-gray-500 space-y-1">
      <div class="flex justify-between">
        <span>创建时间</span>
        <span>{{ item.createTime }}</span>
      </div>
      <div class="flex justify-between">
        <span>更新时间</span>
        <span>{{ item.updateTime }}</span>
      </div>
    </div>
    <div class="flex gap-2 pt-2 border-t border-gray-100 dark:border-zinc-700">
      <button class="text-sm text-primary">编辑</button>
      <button class="text-sm text-error">删除</button>
    </div>
  </div>
</div>
```

### 方案 3：列隐藏 + 展开详情

```html
<!-- 移动端隐藏次要列，展开查看详情 -->
<tr v-for="item in data">
  <td>{{ item.name }}</td>
  <td class="hidden sm:table-cell">{{ item.status }}</td>
  <td class="hidden lg:table-cell">{{ item.createTime }}</td>
  <td>
    <!-- 展开按钮（移动端显示） -->
    <button class="sm:hidden" @click="toggle(item)">
      <ChevronIcon :class="expanded(item) ? 'rotate-90' : ''" />
    </button>
    <!-- 操作按钮 -->
    <span class="hidden sm:inline">...</span>
  </td>
</tr>
<!-- 展开详情行 -->
<tr v-if="expanded(item)" class="sm:hidden">
  <td colspan="4" class="p-4 bg-gray-50 dark:bg-zinc-800">
    <dl class="space-y-2 text-sm">
      <div class="flex justify-between">
        <dt class="text-gray-500">状态</dt>
        <dd>{{ item.status }}</dd>
      </div>
    </dl>
  </td>
</tr>
```

---

## Modal / Drawer 响应式

```html
<!-- Modal：桌面居中弹窗，移动端全屏 -->
<div class="fixed inset-0 z-50 flex items-center justify-center p-4 md:p-8">
  <!-- 遮罩 -->
  <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" @click="close" />

  <!-- 内容 -->
  <div class="relative w-full
              md:max-w-lg md:rounded-2xl
              max-md:h-full max-md:rounded-none
              bg-white dark:bg-zinc-800
              shadow-xl overflow-hidden
              flex flex-col">
    <!-- Header -->
    <div class="flex items-center justify-between p-4 border-b
                border-gray-200 dark:border-zinc-700">
      <h3 class="text-lg font-semibold">{{ title }}</h3>
      <button @click="close">
        <CloseIcon class="w-5 h-5" />
      </button>
    </div>
    <!-- Body -->
    <div class="flex-1 overflow-y-auto p-4">
      <slot />
    </div>
    <!-- Footer -->
    <div class="flex justify-end gap-3 p-4 border-t
                border-gray-200 dark:border-zinc-700">
      <button class="btn-secondary" @click="close">取消</button>
      <button class="btn-primary" @click="confirm">确认</button>
    </div>
  </div>
</div>
```

---

## Container Query（现代方案）

组件级响应式，不依赖视口宽度：

```css
/* 定义容器 */
.card-container {
  container-type: inline-size;
  container-name: card;
}

/* 容器查询：当容器宽度 < 400px 时堆叠排列 */
@container card (max-width: 400px) {
  .card-content {
    flex-direction: column;
  }
  .card-image {
    width: 100%;
  }
}

@container card (min-width: 401px) {
  .card-content {
    flex-direction: row;
  }
  .card-image {
    width: 200px;
  }
}
```

Tailwind CSS v3.2+ 支持：

```html
<div class="@container">
  <div class="flex flex-col @md:flex-row gap-4">
    <img class="w-full @md:w-48 rounded-lg" />
    <div class="flex-1">...</div>
  </div>
</div>
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 只适配桌面，忽略移动端 | 至少支持 768px+ 和 < 768px 两档 |
| 移动端表格直接缩小字号 | 横向滚动或卡片切换 |
| 侧边栏在移动端直接消失，无替代导航 | 汉堡菜单 + 抽屉 或 底部 Tab |
| 固定像素宽度（width: 1200px） | 使用 max-width + 百分比 |
| 所有断点硬编码 px | 使用 Tailwind 断点或 CSS 变量 |
| Modal 移动端仍然小弹窗 | 移动端全屏或底部抽屉式 |
| 忽略安全区域（刘海屏遮挡内容） | `env(safe-area-inset-*)` |
| 触摸目标太小（< 44px） | 移动端按钮/链接最小 44×44px |
| 不测试横屏平板 | 折叠态侧边栏应覆盖平板横屏 |

---

## 响应式检查清单

- [ ] 是否定义了至少 3 个断点（手机/平板/桌面）？
- [ ] 侧边栏是否有三种状态（展开/折叠/隐藏）？
- [ ] 移动端是否有替代导航（抽屉/底部Tab）？
- [ ] 表格是否可横向滚动或切换为卡片？
- [ ] Modal 移动端是否改为全屏/底部弹出？
- [ ] 触摸目标是否 ≥ 44×44px？
- [ ] 是否处理了安全区域（刘海屏）？
- [ ] 表单在窄屏下是否从多列变为单列？
- [ ] 图片是否使用响应式尺寸？
- [ ] 是否在真实设备/模拟器上测试？

---

## 参考实现

StarChat Web 响应式方案：
- 桌面（≥768px）：侧边栏 260px 常显 + 内容区自适应
- 移动端（<768px）：侧边栏自动折叠，选中会话后自动关闭侧边栏
- 拖拽上传反馈：`fixed inset-0` + 虚线边框 + 模糊背景
- 输入框：底部固定 + 安全区域适配
- 返回底部按钮：滚动位置智能显现
