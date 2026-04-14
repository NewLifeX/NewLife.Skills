---
name: frontend-table-styling
description: >
  后台管理系统表格美化：斑马纹、悬停高亮行、操作列固定/浮现、自定义表头、
  单元格标签/Badge/进度条、空数据占位图、加载骨架、排序/筛选图标、行展开详情、选中行高亮。
  适用于数据密集型列表页美化、表格组件定制、数据展示优化等任务。
argument-hint: >
  说明使用的组件库（Element Plus/Ant Design/Arco/TDesign/Naive UI/纯 Tailwind）；
  描述表格包含的列类型和交互需求。
---

# 后台管理表格美化

## 适用场景

- 数据密集型后台管理系统列表页美化
- 组件库表格组件的视觉定制
- 纯 Tailwind CSS 手写表格的样式增强
- 表格空状态、加载状态、选中态的现代化设计

---

## 表格整体容器

### 圆角 + 边框 + 投影

```html
<!-- 表格外层容器 -->
<div class="bg-white dark:bg-zinc-800
            rounded-xl border border-gray-200 dark:border-zinc-700
            shadow-sm overflow-hidden">

  <!-- 表格工具栏 -->
  <div class="flex items-center justify-between px-6 py-4
              border-b border-gray-100 dark:border-zinc-700">
    <h3 class="text-base font-semibold text-gray-800 dark:text-gray-100">
      用户列表
    </h3>
    <div class="flex items-center gap-3">
      <input type="text" placeholder="搜索..."
             class="px-3 py-2 rounded-lg border border-gray-300 dark:border-zinc-600
                    bg-white dark:bg-zinc-700 text-sm w-64
                    focus:outline-none focus:border-primary-500
                    focus:ring-2 focus:ring-primary-500/20" />
      <button class="px-4 py-2 rounded-lg bg-primary-500 text-white text-sm
                     hover:bg-primary-600 transition-colors">
        新建
      </button>
    </div>
  </div>

  <!-- 表格区域（横向可滚动） -->
  <div class="overflow-x-auto">
    <table class="w-full min-w-[800px]">
      ...
    </table>
  </div>

  <!-- 分页器 -->
  <div class="flex items-center justify-between px-6 py-4
              border-t border-gray-100 dark:border-zinc-700">
    <span class="text-sm text-gray-500">共 128 条</span>
    <div class="flex items-center gap-2">...</div>
  </div>
</div>
```

---

## 表头样式

```html
<thead>
  <tr class="bg-gray-50/80 dark:bg-zinc-700/50">
    <th class="px-6 py-3.5 text-left text-xs font-semibold
               text-gray-500 dark:text-gray-400 uppercase tracking-wider
               border-b border-gray-200 dark:border-zinc-600">
      名称
    </th>
    <!-- 可排序表头 -->
    <th class="px-6 py-3.5 text-left text-xs font-semibold
               text-gray-500 dark:text-gray-400 uppercase tracking-wider
               border-b border-gray-200 dark:border-zinc-600
               cursor-pointer select-none
               hover:text-gray-700 dark:hover:text-gray-200
               group transition-colors">
      <span class="inline-flex items-center gap-1">
        创建时间
        <Icon name="unfold_more"
              class="w-4 h-4 opacity-30 group-hover:opacity-70
                     transition-opacity" />
      </span>
    </th>
  </tr>
</thead>
```

---

## 行样式

### 斑马纹 + 悬停高亮

```html
<tbody class="divide-y divide-gray-100 dark:divide-zinc-700">
  <tr v-for="(item, index) in data"
      :class="[
        index % 2 === 0
          ? 'bg-white dark:bg-zinc-800'
          : 'bg-gray-50/50 dark:bg-zinc-800/50',
      ]"
      class="hover:bg-blue-50/50 dark:hover:bg-blue-900/10
             transition-colors duration-100">
    <td class="px-6 py-4 text-sm text-gray-700 dark:text-gray-300
               whitespace-nowrap">
      {{ item.name }}
    </td>
  </tr>
</tbody>
```

### 选中行高亮

```html
<tr :class="[
      selected.includes(item.id)
        ? 'bg-primary-50 dark:bg-primary-900/20 border-l-2 border-l-primary-500'
        : '',
    ]"
    class="hover:bg-blue-50/50 dark:hover:bg-blue-900/10
           transition-colors duration-100 cursor-pointer"
    @click="toggleSelect(item.id)">
```

---

## 单元格内容美化

### 状态 Badge

```html
<td class="px-6 py-4">
  <!-- 成功态 -->
  <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5
               text-xs font-medium rounded-full
               bg-green-100 text-green-700
               dark:bg-green-900/30 dark:text-green-400">
    <span class="w-1.5 h-1.5 rounded-full bg-green-500" />
    正常
  </span>

  <!-- 错误态 -->
  <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5
               text-xs font-medium rounded-full
               bg-red-100 text-red-700
               dark:bg-red-900/30 dark:text-red-400">
    <span class="w-1.5 h-1.5 rounded-full bg-red-500" />
    异常
  </span>
</td>
```

### 进度条

```html
<td class="px-6 py-4">
  <div class="flex items-center gap-3">
    <div class="flex-1 h-2 bg-gray-200 dark:bg-zinc-600 rounded-full overflow-hidden">
      <div class="h-full rounded-full transition-all duration-500"
           :class="item.progress > 80 ? 'bg-green-500' :
                   item.progress > 50 ? 'bg-blue-500' :
                   item.progress > 20 ? 'bg-yellow-500' : 'bg-red-500'"
           :style="{ width: item.progress + '%' }" />
    </div>
    <span class="text-xs text-gray-500 w-10 text-right">
      {{ item.progress }}%
    </span>
  </div>
</td>
```

### 用户信息列（头像 + 名称）

```html
<td class="px-6 py-4">
  <div class="flex items-center gap-3">
    <div class="w-8 h-8 rounded-full overflow-hidden flex-shrink-0
                bg-primary-100 dark:bg-primary-900/30
                flex items-center justify-center
                text-xs font-semibold text-primary-600 dark:text-primary-400">
      <img v-if="item.avatar" :src="item.avatar"
           class="w-full h-full object-cover" />
      <span v-else>{{ item.name.charAt(0) }}</span>
    </div>
    <div class="min-w-0">
      <p class="text-sm font-medium text-gray-800 dark:text-gray-200 truncate">
        {{ item.name }}
      </p>
      <p class="text-xs text-gray-500 dark:text-gray-400 truncate">
        {{ item.email }}
      </p>
    </div>
  </div>
</td>
```

### 时间列（相对时间 + tooltip 完整时间）

```html
<td class="px-6 py-4 text-sm text-gray-500 dark:text-gray-400
           whitespace-nowrap" :title="item.createTime">
  {{ formatRelativeTime(item.createTime) }}
</td>
```

---

## 操作列

### 直接按钮（适合 2-3 个操作）

```html
<td class="px-6 py-4">
  <div class="flex items-center gap-2">
    <button class="text-sm text-primary-500 hover:text-primary-600
                   transition-colors">
      编辑
    </button>
    <span class="text-gray-300 dark:text-zinc-600">|</span>
    <button class="text-sm text-red-500 hover:text-red-600
                   transition-colors">
      删除
    </button>
  </div>
</td>
```

### hover 浮现操作（适合密集数据）

```html
<tr class="group">
  <!-- 其他列 -->
  <td class="px-6 py-4">
    <div class="opacity-0 group-hover:opacity-100
                transition-opacity duration-150
                flex items-center gap-1">
      <button class="p-1.5 rounded-md hover:bg-gray-100 dark:hover:bg-zinc-700
                     text-gray-500 hover:text-primary-500 transition-colors"
              title="编辑">
        <Icon name="edit" class="w-4 h-4" />
      </button>
      <button class="p-1.5 rounded-md hover:bg-gray-100 dark:hover:bg-zinc-700
                     text-gray-500 hover:text-red-500 transition-colors"
              title="删除">
        <Icon name="delete" class="w-4 h-4" />
      </button>
      <button class="p-1.5 rounded-md hover:bg-gray-100 dark:hover:bg-zinc-700
                     text-gray-500 hover:text-gray-700 transition-colors"
              title="更多">
        <Icon name="more_horiz" class="w-4 h-4" />
      </button>
    </div>
  </td>
</tr>
```

### 固定操作列

```html
<th class="px-6 py-3.5 sticky right-0 z-10
           bg-gray-50 dark:bg-zinc-700
           shadow-[-4px_0_8px_rgba(0,0,0,0.04)]">
  操作
</th>

<td class="px-6 py-4 sticky right-0 z-10
           bg-white dark:bg-zinc-800
           group-hover:bg-blue-50/50 dark:group-hover:bg-blue-900/10
           shadow-[-4px_0_8px_rgba(0,0,0,0.04)]">
  ...
</td>
```

---

## 空数据状态

```html
<tr>
  <td :colspan="columns.length" class="py-16">
    <div class="flex flex-col items-center text-center">
      <!-- 空状态插画 -->
      <div class="w-24 h-24 mb-4 text-gray-300 dark:text-zinc-600">
        <svg viewBox="0 0 96 96" fill="none" class="w-full h-full">
          <!-- 简洁线条插画 -->
          <rect x="16" y="20" width="64" height="48" rx="8"
                stroke="currentColor" stroke-width="2" />
          <path d="M16 36h64" stroke="currentColor" stroke-width="2" />
          <circle cx="48" cy="52" r="6" stroke="currentColor" stroke-width="2" />
        </svg>
      </div>
      <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
        暂无数据
      </p>
      <p class="text-xs text-gray-400 dark:text-gray-500 mt-1">
        尚未创建任何记录，点击上方按钮新建
      </p>
    </div>
  </td>
</tr>
```

---

## 加载骨架

```html
<tbody v-if="loading" class="divide-y divide-gray-100 dark:divide-zinc-700">
  <tr v-for="i in 5" class="animate-pulse">
    <td class="px-6 py-4">
      <div class="flex items-center gap-3">
        <div class="w-8 h-8 rounded-full bg-gray-200 dark:bg-zinc-700" />
        <div class="space-y-1.5">
          <div class="h-3.5 bg-gray-200 dark:bg-zinc-700 rounded w-24" />
          <div class="h-3 bg-gray-200 dark:bg-zinc-700 rounded w-32" />
        </div>
      </div>
    </td>
    <td class="px-6 py-4">
      <div class="h-5 bg-gray-200 dark:bg-zinc-700 rounded-full w-16" />
    </td>
    <td class="px-6 py-4">
      <div class="h-3.5 bg-gray-200 dark:bg-zinc-700 rounded w-28" />
    </td>
    <td class="px-6 py-4">
      <div class="h-2 bg-gray-200 dark:bg-zinc-700 rounded-full w-20" />
    </td>
    <td class="px-6 py-4">
      <div class="flex gap-2">
        <div class="h-7 w-7 bg-gray-200 dark:bg-zinc-700 rounded" />
        <div class="h-7 w-7 bg-gray-200 dark:bg-zinc-700 rounded" />
      </div>
    </td>
  </tr>
</tbody>
```

---

## 行展开详情

```html
<template v-for="item in data">
  <tr class="hover:bg-blue-50/50 dark:hover:bg-blue-900/10 transition-colors">
    <td class="px-6 py-4">
      <button @click="toggleExpand(item.id)"
              class="p-0.5 rounded hover:bg-gray-200 dark:hover:bg-zinc-600
                     transition-colors">
        <Icon name="chevron_right"
              :class="expanded.has(item.id) ? 'rotate-90' : ''"
              class="w-4 h-4 text-gray-400 transition-transform duration-200" />
      </button>
    </td>
    <!-- 其他列 -->
  </tr>

  <!-- 展开详情行 -->
  <tr v-if="expanded.has(item.id)">
    <td :colspan="columns.length"
        class="px-6 py-4 bg-gray-50/80 dark:bg-zinc-800/80
               border-b border-gray-200 dark:border-zinc-700">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
        <div>
          <span class="text-gray-500 dark:text-gray-400">创建者</span>
          <p class="mt-0.5 font-medium">{{ item.creator }}</p>
        </div>
        <div>
          <span class="text-gray-500 dark:text-gray-400">更新时间</span>
          <p class="mt-0.5">{{ item.updateTime }}</p>
        </div>
        <div>
          <span class="text-gray-500 dark:text-gray-400">备注</span>
          <p class="mt-0.5">{{ item.remark || '—' }}</p>
        </div>
      </div>
    </td>
  </tr>
</template>
```

---

## 组件库表格定制

### Element Plus 表格美化

```css
/* 覆盖 Element Plus 表格默认样式 */
.el-table {
  --el-table-border-color: #E5E7EB;
  --el-table-header-bg-color: #F9FAFB;
  --el-table-header-text-color: #6B7280;
  --el-table-row-hover-bg-color: #EFF6FF;
  --el-table-border: none;
  border-radius: 12px;
  overflow: hidden;
}

.dark .el-table {
  --el-table-border-color: #3F3F46;
  --el-table-header-bg-color: rgba(63, 63, 70, 0.5);
  --el-table-header-text-color: #9CA3AF;
  --el-table-row-hover-bg-color: rgba(59, 130, 246, 0.05);
  --el-table-bg-color: #1E1E20;
  --el-table-tr-bg-color: #1E1E20;
  --el-table-text-color: #D1D5DB;
}

.el-table th.el-table__cell {
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 表格无边框无投影（纯平） | 圆角容器 + 轻投影 + 边框 |
| 表头和数据行一样的字号字色 | 表头小号 + 大写 + 灰色，数据行标准尺寸 |
| 所有行同色（白底白底白底） | 交替色 + hover 高亮（蓝调） |
| 操作按钮始终 5 个占满 | 2-3 个常用直接显示 + 更多收进下拉 |
| 空数据只显示"暂无数据"四个字 | 空状态插画 + 描述文字 + 引导按钮 |
| 加载时整个表格白屏 | 骨架屏占位，保留表格结构 |
| 操作列不固定，宽表格需右滑才能操作 | `sticky right-0` 固定操作列 |
| 状态用纯文字 | 圆点 + 背景色 Badge |
| 长文本撑破列宽 | `truncate` + tooltip 完整内容 |
| 时间列展示完整 ISO 格式 | 相对时间 + hover 完整时间 |
