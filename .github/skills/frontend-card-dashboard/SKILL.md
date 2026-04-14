---
name: frontend-card-dashboard
description: >
  仪表盘与卡片布局美化：统计卡（数值+趋势箭头+迷你图表）、渐变装饰统计卡、
  网格仪表盘布局（响应式 auto-fit）、图表容器样式、
  快捷操作卡片、公告/消息卡片、空状态卡片。
  适用于后台首页仪表盘设计、数据概览页美化、卡片式布局开发等任务。
argument-hint: >
  说明仪表盘包含的统计指标和图表类型；
  如有特定数据展示需求（如实时数据、环比对比），一并提供。
---

# 仪表盘与卡片布局美化

## 适用场景

- 后台管理系统首页仪表盘设计
- 数据概览页的统计卡片美化
- 图表容器与周边布局的协调
- 卡片式布局的响应式网格

---

## 仪表盘网格布局

```html
<div class="space-y-6">
  <!-- 统计卡片行 -->
  <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4">
    <!-- 4 张统计卡 -->
  </div>

  <!-- 图表行 -->
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
    <!-- 2/3 宽度主图表 -->
    <div class="lg:col-span-2">
      <!-- 趋势图 -->
    </div>
    <!-- 1/3 宽度辅图表 -->
    <div>
      <!-- 饼图 / 排行榜 -->
    </div>
  </div>

  <!-- 底部全宽（表格 / 动态） -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
    <!-- 最近操作 -->
    <!-- 系统公告 -->
  </div>
</div>
```

---

## 统计卡片

### 基础统计卡

```html
<div class="bg-white dark:bg-zinc-800
            rounded-xl border border-gray-200 dark:border-zinc-700
            p-5 hover:shadow-md transition-shadow duration-200">
  <div class="flex items-center justify-between">
    <div>
      <p class="text-sm text-gray-500 dark:text-gray-400">总用户数</p>
      <p class="text-2xl font-bold text-gray-800 dark:text-gray-100 mt-1">
        12,345
      </p>
      <!-- 趋势 -->
      <div class="flex items-center gap-1 mt-2 text-xs">
        <span class="flex items-center gap-0.5 text-green-600 dark:text-green-400">
          <Icon name="trending_up" class="w-3.5 h-3.5" />
          +12.5%
        </span>
        <span class="text-gray-400">较上月</span>
      </div>
    </div>
    <!-- 图标装饰 -->
    <div class="w-12 h-12 rounded-xl
                bg-blue-50 dark:bg-blue-900/20
                flex items-center justify-center">
      <Icon name="group" class="w-6 h-6 text-blue-500" />
    </div>
  </div>
</div>
```

### 渐变统计卡

```html
<div class="relative overflow-hidden rounded-xl p-5 text-white
            bg-gradient-to-br from-blue-500 to-blue-600
            shadow-lg shadow-blue-500/20
            hover:shadow-xl hover:shadow-blue-500/30
            transition-shadow duration-200">
  <!-- 装饰圆形 -->
  <div class="absolute -right-4 -top-4 w-24 h-24
              bg-white/10 rounded-full" />
  <div class="absolute -right-2 -bottom-6 w-32 h-32
              bg-white/5 rounded-full" />

  <div class="relative">
    <div class="flex items-center gap-2 text-sm text-white/80">
      <Icon name="group" class="w-4 h-4" />
      总用户数
    </div>
    <p class="text-3xl font-bold mt-2">12,345</p>
    <div class="flex items-center gap-1 mt-2 text-sm text-white/70">
      <Icon name="trending_up" class="w-4 h-4 text-green-300" />
      <span class="text-green-300">+12.5%</span>
      <span>较上月</span>
    </div>
  </div>
</div>
```

### 渐变色系列（4 色搭配）

```html
<!-- 蓝色 -->
<div class="bg-gradient-to-br from-blue-500 to-blue-600 shadow-blue-500/20">
<!-- 紫色 -->
<div class="bg-gradient-to-br from-purple-500 to-purple-600 shadow-purple-500/20">
<!-- 绿色 -->
<div class="bg-gradient-to-br from-emerald-500 to-emerald-600 shadow-emerald-500/20">
<!-- 橙色 -->
<div class="bg-gradient-to-br from-orange-500 to-orange-600 shadow-orange-500/20">
```

### 带迷你图表的统计卡

```html
<div class="bg-white dark:bg-zinc-800 rounded-xl border
            border-gray-200 dark:border-zinc-700 p-5">
  <div class="flex items-start justify-between">
    <div>
      <p class="text-sm text-gray-500 dark:text-gray-400">访问量</p>
      <p class="text-2xl font-bold text-gray-800 dark:text-gray-100 mt-1">
        8,846
      </p>
    </div>
    <span class="flex items-center gap-0.5 text-xs font-medium
                 text-red-600 dark:text-red-400
                 bg-red-50 dark:bg-red-900/20
                 px-2 py-0.5 rounded-full">
      <Icon name="trending_down" class="w-3 h-3" />
      -3.2%
    </span>
  </div>

  <!-- 迷你趋势线（用简单 SVG 或 sparkline） -->
  <div class="mt-4 h-12">
    <svg viewBox="0 0 200 48" class="w-full h-full" preserveAspectRatio="none">
      <defs>
        <linearGradient id="sparkGrad" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stop-color="#3B82F6" stop-opacity="0.2" />
          <stop offset="100%" stop-color="#3B82F6" stop-opacity="0" />
        </linearGradient>
      </defs>
      <!-- 填充区域 -->
      <path d="M0,40 L20,35 L40,38 L60,25 L80,30 L100,20 L120,15 L140,22 L160,10 L180,8 L200,12 L200,48 L0,48 Z"
            fill="url(#sparkGrad)" />
      <!-- 线条 -->
      <path d="M0,40 L20,35 L40,38 L60,25 L80,30 L100,20 L120,15 L140,22 L160,10 L180,8 L200,12"
            fill="none" stroke="#3B82F6" stroke-width="2" />
    </svg>
  </div>
</div>
```

---

## 图表容器

```html
<div class="bg-white dark:bg-zinc-800
            rounded-xl border border-gray-200 dark:border-zinc-700
            shadow-sm overflow-hidden">
  <!-- 图表头部 -->
  <div class="flex items-center justify-between px-6 py-4
              border-b border-gray-100 dark:border-zinc-700">
    <div>
      <h3 class="text-base font-semibold text-gray-800 dark:text-gray-100">
        访问趋势
      </h3>
      <p class="text-xs text-gray-500 dark:text-gray-400 mt-0.5">
        最近 30 天
      </p>
    </div>
    <!-- 切换按钮组 -->
    <div class="flex items-center bg-gray-100 dark:bg-zinc-700
                rounded-lg p-0.5">
      <button v-for="period in ['7天', '30天', '90天']"
              :class="activePeriod === period
                ? 'bg-white dark:bg-zinc-600 text-gray-800 dark:text-gray-100 shadow-sm'
                : 'text-gray-500 dark:text-gray-400'"
              class="px-3 py-1.5 rounded-md text-xs font-medium
                     transition-all duration-150">
        {{ period }}
      </button>
    </div>
  </div>
  <!-- 图表区域 -->
  <div class="p-6 h-80">
    <div ref="chartRef" class="w-full h-full" />
  </div>
</div>
```

---

## 快捷操作卡片

```html
<div class="bg-white dark:bg-zinc-800 rounded-xl border
            border-gray-200 dark:border-zinc-700 p-6">
  <h3 class="text-base font-semibold text-gray-800 dark:text-gray-100 mb-4">
    快捷操作
  </h3>
  <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
    <button v-for="action in quickActions"
            class="flex flex-col items-center gap-2 p-4 rounded-xl
                   border border-gray-100 dark:border-zinc-700
                   hover:border-primary-200 dark:hover:border-primary-800
                   hover:bg-primary-50/50 dark:hover:bg-primary-900/10
                   cursor-pointer transition-all duration-200
                   group">
      <div :class="action.bgClass"
           class="w-10 h-10 rounded-xl flex items-center justify-center
                  group-hover:scale-110 transition-transform duration-200">
        <Icon :name="action.icon" class="w-5 h-5" :class="action.iconClass" />
      </div>
      <span class="text-xs font-medium text-gray-600 dark:text-gray-400
                   group-hover:text-gray-800 dark:group-hover:text-gray-200">
        {{ action.label }}
      </span>
    </button>
  </div>
</div>
```

---

## 消息 / 公告卡片

```html
<div class="bg-white dark:bg-zinc-800 rounded-xl border
            border-gray-200 dark:border-zinc-700 overflow-hidden">
  <div class="flex items-center justify-between px-6 py-4
              border-b border-gray-100 dark:border-zinc-700">
    <h3 class="text-base font-semibold text-gray-800 dark:text-gray-100">
      系统公告
    </h3>
    <a href="#" class="text-xs text-primary-500 hover:text-primary-600
                       transition-colors">
      查看全部 →
    </a>
  </div>

  <div class="divide-y divide-gray-100 dark:divide-zinc-700">
    <div v-for="item in notices"
         class="px-6 py-4 hover:bg-gray-50 dark:hover:bg-zinc-700/50
                cursor-pointer transition-colors">
      <div class="flex items-start gap-3">
        <!-- 类型图标 -->
        <div :class="item.type === 'info'
               ? 'bg-blue-100 dark:bg-blue-900/20 text-blue-500'
               : 'bg-orange-100 dark:bg-orange-900/20 text-orange-500'"
             class="w-8 h-8 rounded-lg flex items-center justify-center
                    flex-shrink-0 mt-0.5">
          <Icon :name="item.type === 'info' ? 'info' : 'warning'"
                class="w-4 h-4" />
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-gray-800 dark:text-gray-200
                    truncate">
            {{ item.title }}
          </p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1
                    line-clamp-2">
            {{ item.content }}
          </p>
          <p class="text-xs text-gray-400 dark:text-gray-500 mt-1.5">
            {{ item.time }}
          </p>
        </div>
        <!-- 未读红点 -->
        <span v-if="!item.read"
              class="w-2 h-2 rounded-full bg-red-500 flex-shrink-0 mt-2" />
      </div>
    </div>
  </div>
</div>
```

---

## 排行榜卡片

```html
<div class="bg-white dark:bg-zinc-800 rounded-xl border
            border-gray-200 dark:border-zinc-700 p-6">
  <h3 class="text-base font-semibold text-gray-800 dark:text-gray-100 mb-4">
    热门页面
  </h3>
  <div class="space-y-3">
    <div v-for="(item, index) in rankList"
         class="flex items-center gap-3">
      <!-- 排名 -->
      <span :class="index < 3
              ? 'bg-primary-500 text-white'
              : 'bg-gray-100 dark:bg-zinc-700 text-gray-500 dark:text-gray-400'"
            class="w-6 h-6 rounded-full flex items-center justify-center
                   text-xs font-bold flex-shrink-0">
        {{ index + 1 }}
      </span>
      <!-- 名称 -->
      <span class="flex-1 text-sm text-gray-700 dark:text-gray-300 truncate">
        {{ item.name }}
      </span>
      <!-- 数值 + 进度条 -->
      <div class="flex items-center gap-2 w-32">
        <div class="flex-1 h-1.5 bg-gray-100 dark:bg-zinc-700 rounded-full
                    overflow-hidden">
          <div class="h-full bg-primary-500 rounded-full"
               :style="{ width: (item.visits / maxVisits * 100) + '%' }" />
        </div>
        <span class="text-xs text-gray-500 dark:text-gray-400 w-10 text-right
                     tabular-nums">
          {{ item.visits }}
        </span>
      </div>
    </div>
  </div>
</div>
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 统计卡只有数字，没有趋势/对比 | 数值 + 趋势箭头 + 百分比对比 |
| 4 张统计卡颜色一样 | 蓝/紫/绿/橙 4 色区分或不同图标 |
| 图表区域没有头部标题 | 标题 + 副标题 + 时间切换器 |
| 仪表盘布局在小屏幕上挤成一团 | 响应式网格：xl:4 列 → sm:2 列 → 1 列 |
| 统计卡纯白底无变化 | 渐变背景 或 图标装饰色块 |
| 排行榜第 1 和第 10 视觉完全一样 | Top 3 用主色圆形，其余灰色 |
| 图表占满整个页面没有留白 | 图表容器内 p-6 留白 |
| 公告只有标题没有分类图标 | 类型图标 + 颜色区分 + 未读红点 |
