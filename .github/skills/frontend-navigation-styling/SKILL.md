---
name: frontend-navigation-styling
description: >
  后台管理系统导航美化：侧边栏菜单树（多级折叠/图标+文字/收起仅图标）、
  顶栏（通知铃铛/用户头像下拉/全局搜索框）、面包屑层次、
  标签页路由（可关闭/固定/滚动）、移动端底部导航栏。
  适用于后台管理系统导航组件开发和美化、全局布局优化等任务。
argument-hint: >
  说明导航结构（顶部导航/侧边栏/混合）和菜单层级深度；
  如有特定交互需求（如标签页缓存、菜单搜索），一并提供。
---

# 后台管理导航美化

## 适用场景

- 后台管理系统侧边栏菜单样式定制
- 顶部导航栏（Header）视觉优化
- 面包屑导航层级展示
- 多标签页路由管理
- 移动端适配的底部导航栏

---

## 侧边栏菜单

### 菜单项样式

```html
<nav class="px-3 py-4 space-y-1">
  <!-- 一级菜单项（带图标） -->
  <a href="#" :class="isActive
       ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-600 dark:text-primary-400 font-medium'
       : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-zinc-700 hover:text-gray-900 dark:hover:text-gray-200'"
     class="flex items-center gap-3 px-3 py-2.5 rounded-lg
            text-sm transition-colors duration-150">
    <Icon name="dashboard" class="w-5 h-5 flex-shrink-0" />
    <span>仪表盘</span>
  </a>

  <!-- 带子菜单的父项 -->
  <div>
    <button @click="toggleGroup('system')"
            class="w-full flex items-center justify-between
                   px-3 py-2.5 rounded-lg text-sm
                   text-gray-600 dark:text-gray-400
                   hover:bg-gray-100 dark:hover:bg-zinc-700
                   transition-colors duration-150">
      <span class="flex items-center gap-3">
        <Icon name="settings" class="w-5 h-5" />
        <span>系统管理</span>
      </span>
      <Icon name="expand_more"
            :class="openGroups.has('system') ? 'rotate-180' : ''"
            class="w-4 h-4 transition-transform duration-200" />
    </button>

    <!-- 子菜单折叠区域 -->
    <div v-show="openGroups.has('system')"
         class="mt-1 ml-5 pl-3 border-l-2 border-gray-200 dark:border-zinc-700
                space-y-0.5">
      <a v-for="child in systemMenus"
         :class="isActive(child)
           ? 'text-primary-600 dark:text-primary-400 bg-primary-50/50 dark:bg-primary-900/10 font-medium'
           : 'text-gray-500 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200 hover:bg-gray-50 dark:hover:bg-zinc-700/50'"
         class="block px-3 py-2 rounded-md text-sm
                transition-colors duration-150">
        {{ child.label }}
      </a>
    </div>
  </div>
</nav>
```

### 侧边栏底部区域

```html
<div class="border-t border-gray-200 dark:border-zinc-700 p-3 mt-auto">
  <!-- 用户信息 -->
  <div class="flex items-center gap-3 px-3 py-2.5 rounded-lg
              hover:bg-gray-100 dark:hover:bg-zinc-700
              cursor-pointer transition-colors">
    <div class="w-8 h-8 rounded-full bg-primary-100 dark:bg-primary-900/30
                flex items-center justify-center text-sm font-semibold
                text-primary-600 dark:text-primary-400">
      A
    </div>
    <div class="flex-1 min-w-0">
      <p class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">
        Admin
      </p>
      <p class="text-xs text-gray-500 dark:text-gray-400 truncate">
        admin@example.com
      </p>
    </div>
    <Icon name="unfold_more" class="w-4 h-4 text-gray-400" />
  </div>
</div>
```

### 折叠态（仅图标 + Tooltip）

```html
<nav class="px-2 py-4 space-y-1">
  <!-- 折叠态菜单项 -->
  <a href="#" :title="item.label"
     :class="isActive ? activeClass : normalClass"
     class="flex items-center justify-center
            w-10 h-10 mx-auto rounded-lg
            transition-colors duration-150
            group relative">
    <Icon :name="item.icon" class="w-5 h-5" />

    <!-- Tooltip（hover 显示） -->
    <span class="absolute left-full ml-2
                 px-2.5 py-1.5 rounded-md
                 bg-gray-900 dark:bg-zinc-200
                 text-white dark:text-gray-900
                 text-xs font-medium whitespace-nowrap
                 opacity-0 group-hover:opacity-100
                 pointer-events-none
                 transition-opacity duration-150
                 shadow-lg z-50">
      {{ item.label }}
    </span>
  </a>
</nav>
```

---

## 顶部导航栏

```html
<header class="sticky top-0 z-30 h-16
               bg-white/90 dark:bg-zinc-800/90
               backdrop-blur-md backdrop-saturate-150
               border-b border-gray-200/80 dark:border-zinc-700/80">
  <div class="flex items-center h-full px-4 gap-4">

    <!-- 左侧：移动端菜单按钮 + Logo -->
    <button class="lg:hidden p-2 rounded-lg hover:bg-gray-100
                   dark:hover:bg-zinc-700 transition-colors">
      <Icon name="menu" class="w-5 h-5 text-gray-600 dark:text-gray-300" />
    </button>

    <!-- 全局搜索 -->
    <div class="hidden md:flex items-center flex-1 max-w-md">
      <div class="relative w-full">
        <Icon name="search"
              class="absolute left-3 top-1/2 -translate-y-1/2
                     w-4 h-4 text-gray-400" />
        <input type="text"
               placeholder="搜索菜单、功能..."
               class="w-full pl-9 pr-4 py-2 rounded-lg
                      bg-gray-100 dark:bg-zinc-700
                      border-0 text-sm
                      placeholder:text-gray-400
                      focus:bg-white dark:focus:bg-zinc-600
                      focus:ring-2 focus:ring-primary-500/20
                      transition-all duration-200" />
        <kbd class="absolute right-3 top-1/2 -translate-y-1/2
                    hidden lg:inline-flex items-center
                    px-1.5 py-0.5 rounded border
                    border-gray-300 dark:border-zinc-500
                    bg-gray-50 dark:bg-zinc-600
                    text-xs text-gray-400 dark:text-gray-400
                    font-mono">
          ⌘K
        </kbd>
      </div>
    </div>

    <div class="flex-1" />

    <!-- 右侧操作区 -->
    <div class="flex items-center gap-2">

      <!-- 主题切换 -->
      <button class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-zinc-700
                     text-gray-500 dark:text-gray-400 transition-colors"
              @click="toggleTheme">
        <Icon :name="isDark ? 'light_mode' : 'dark_mode'" class="w-5 h-5" />
      </button>

      <!-- 通知铃铛 -->
      <button class="relative p-2 rounded-lg hover:bg-gray-100
                     dark:hover:bg-zinc-700
                     text-gray-500 dark:text-gray-400 transition-colors">
        <Icon name="notifications" class="w-5 h-5" />
        <!-- 未读红点 -->
        <span v-if="unreadCount > 0"
              class="absolute top-1.5 right-1.5
                     w-2 h-2 rounded-full bg-red-500
                     ring-2 ring-white dark:ring-zinc-800" />
      </button>

      <!-- 分隔线 -->
      <div class="w-px h-6 bg-gray-200 dark:bg-zinc-700 mx-1" />

      <!-- 用户头像下拉 -->
      <button class="flex items-center gap-2 p-1.5 rounded-lg
                     hover:bg-gray-100 dark:hover:bg-zinc-700
                     transition-colors">
        <div class="w-8 h-8 rounded-full bg-primary-500
                    flex items-center justify-center
                    text-sm font-semibold text-white">
          A
        </div>
        <span class="hidden md:block text-sm text-gray-700 dark:text-gray-300">
          Admin
        </span>
        <Icon name="expand_more" class="w-4 h-4 text-gray-400" />
      </button>
    </div>
  </div>
</header>
```

---

## 面包屑

```html
<nav class="flex items-center gap-1.5 text-sm mb-6">
  <a href="/" class="text-gray-500 dark:text-gray-400
                     hover:text-gray-700 dark:hover:text-gray-200
                     transition-colors">
    <Icon name="home" class="w-4 h-4" />
  </a>

  <template v-for="(crumb, index) in breadcrumbs">
    <Icon name="chevron_right"
          class="w-4 h-4 text-gray-300 dark:text-gray-600" />

    <!-- 最后一项：当前页面（不可点击） -->
    <span v-if="index === breadcrumbs.length - 1"
          class="text-gray-800 dark:text-gray-200 font-medium">
      {{ crumb.label }}
    </span>

    <!-- 中间项：可点击链接 -->
    <a v-else :href="crumb.path"
       class="text-gray-500 dark:text-gray-400
              hover:text-gray-700 dark:hover:text-gray-200
              transition-colors">
      {{ crumb.label }}
    </a>
  </template>
</nav>
```

---

## 标签页路由

```html
<div class="bg-white dark:bg-zinc-800
            border-b border-gray-200 dark:border-zinc-700
            overflow-x-auto flex items-center
            [&::-webkit-scrollbar]:h-0">

  <div class="flex items-center min-w-0 gap-0.5 px-2">
    <div v-for="tab in tabs"
         :class="tab.active
           ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-600 dark:text-primary-400 border-b-2 border-primary-500'
           : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 hover:bg-gray-50 dark:hover:bg-zinc-700'"
         class="group flex items-center gap-1.5
                px-3 py-2.5 text-sm whitespace-nowrap
                cursor-pointer transition-colors duration-150
                border-b-2 border-transparent
                first:ml-0">

      <span>{{ tab.label }}</span>

      <!-- 关闭按钮（hover 显示） -->
      <button v-if="!tab.fixed"
              @click.stop="closeTab(tab)"
              class="w-4 h-4 rounded-sm
                     opacity-0 group-hover:opacity-100
                     hover:bg-gray-200 dark:hover:bg-zinc-600
                     flex items-center justify-center
                     transition-opacity">
        <Icon name="close" class="w-3 h-3" />
      </button>

      <!-- 固定标记 -->
      <Icon v-if="tab.fixed" name="push_pin"
            class="w-3 h-3 opacity-40" />
    </div>
  </div>

  <!-- 右侧操作 -->
  <div class="ml-auto flex-shrink-0 flex items-center px-2
              border-l border-gray-200 dark:border-zinc-700">
    <button class="p-1.5 rounded hover:bg-gray-100 dark:hover:bg-zinc-700
                   text-gray-400 transition-colors"
            title="关闭其他">
      <Icon name="close_fullscreen" class="w-4 h-4" />
    </button>
  </div>
</div>
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 菜单项间距过密（< 32px 高度） | 每项 py-2.5 (约 40px)，拇指友好 |
| 活跃菜单项和普通项视觉差异不明显 | 活跃：主色背景 + 主色文字 + font-medium |
| 子菜单没有缩进和层级指示 | 左侧 border-l-2 + ml-5 缩进 |
| 折叠态不显示 Tooltip | 鼠标悬停显示菜单名 Tooltip |
| 顶栏不使用毛玻璃 | `backdrop-blur-md` + 半透明背景 |
| 面包屑用纯文字无链接 | 中间项可点击，仅末项不可点击 |
| 标签页无关闭按钮 | hover 时显示关闭 × 按钮 |
| 通知图标无未读标记 | 右上角小红点 + ring 白色描边 |
| 搜索框占全宽 | 限制 max-w-md，带快捷键提示 |
| 用户区域只有文字没有头像 | 头像（实图或首字母圆形）+ 名称 |
