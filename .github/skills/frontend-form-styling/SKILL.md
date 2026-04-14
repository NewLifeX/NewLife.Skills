---
name: frontend-form-styling
description: >
  后台管理系统表单美化：浮动标签/内联标签切换、实时校验反馈（红底线+抖动动画）、
  分组与分步表单、输入框前后图标装饰、密码强度指示器、搜索栏自动补全、
  日期选择器美化、只读态与编辑态视觉区分。
  适用于表单页面美化、新建/编辑页定制、搜索筛选区优化等任务。
argument-hint: >
  说明表单场景（新建/编辑/搜索筛选/登录注册）和使用的组件库或 Tailwind。
---

# 后台管理表单美化

## 适用场景

- 后台管理系统新建/编辑表单美化
- 登录/注册页面视觉提升
- 搜索栏和筛选区域优化
- 分步向导（Step Form）设计
- 只读详情与编辑表单的视觉对比

---

## 基础表单布局

### 垂直布局（推荐）

```html
<form class="space-y-6 max-w-2xl">
  <!-- 表单分组 -->
  <fieldset class="space-y-5">
    <legend class="text-base font-semibold text-gray-800 dark:text-gray-100
                   pb-3 border-b border-gray-200 dark:border-zinc-700 w-full">
      基本信息
    </legend>

    <!-- 字段项 -->
    <div class="space-y-1.5">
      <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
        用户名 <span class="text-red-500">*</span>
      </label>
      <input type="text" placeholder="请输入用户名"
             class="w-full px-3.5 py-2.5 rounded-lg
                    border border-gray-300 dark:border-zinc-600
                    bg-white dark:bg-zinc-800
                    text-gray-900 dark:text-gray-100 text-sm
                    placeholder:text-gray-400 dark:placeholder:text-gray-500
                    focus:outline-none focus:border-primary-500
                    focus:ring-2 focus:ring-primary-500/20
                    transition-all duration-150" />
      <p class="text-xs text-gray-500 dark:text-gray-400">
        3-20 个字符，支持字母、数字和下划线
      </p>
    </div>
  </fieldset>
</form>
```

### 水平布局（宽屏适用）

```html
<div class="grid grid-cols-[140px_1fr] gap-x-6 gap-y-5 items-start">
  <label class="text-sm font-medium text-gray-700 dark:text-gray-300
                text-right pt-2.5">
    用户名 <span class="text-red-500">*</span>
  </label>
  <div class="space-y-1.5">
    <input type="text" class="w-full px-3.5 py-2.5 rounded-lg ..." />
    <p class="text-xs text-gray-500">3-20 个字符</p>
  </div>
</div>
```

### 多列布局

```html
<div class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-5">
  <!-- 每个字段项占一列 -->
  <div class="space-y-1.5">
    <label>姓名</label>
    <input />
  </div>
  <div class="space-y-1.5">
    <label>手机号</label>
    <input />
  </div>
  <!-- 跨两列字段 -->
  <div class="space-y-1.5 md:col-span-2">
    <label>备注</label>
    <textarea></textarea>
  </div>
</div>
```

---

## 浮动标签

输入框为空时标签在内部居中显示，聚焦或有值时浮到上方：

```html
<div class="relative">
  <input id="email" type="email"
         placeholder=" "
         class="peer w-full px-3.5 pt-5 pb-2 rounded-lg
                border border-gray-300 dark:border-zinc-600
                bg-white dark:bg-zinc-800
                text-sm text-gray-900 dark:text-gray-100
                focus:outline-none focus:border-primary-500
                focus:ring-2 focus:ring-primary-500/20
                transition-all duration-200
                placeholder-transparent" />

  <label for="email"
         class="absolute left-3.5 top-1/2 -translate-y-1/2
                text-sm text-gray-400 dark:text-gray-500
                pointer-events-none
                transition-all duration-200 origin-left
                peer-focus:top-2.5 peer-focus:translate-y-0
                peer-focus:text-xs peer-focus:text-primary-500
                peer-[:not(:placeholder-shown)]:top-2.5
                peer-[:not(:placeholder-shown)]:translate-y-0
                peer-[:not(:placeholder-shown)]:text-xs">
    邮箱地址
  </label>
</div>
```

---

## 校验反馈

### 错误态

```html
<div class="space-y-1.5">
  <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
    邮箱
  </label>
  <!-- 错误态输入框：红色边框 + 红色 ring -->
  <input type="email" :value="form.email"
         class="w-full px-3.5 py-2.5 rounded-lg text-sm
                transition-all duration-150"
         :class="errors.email
           ? 'border-red-400 dark:border-red-500 focus:ring-red-400/20 focus:border-red-400'
           : 'border-gray-300 dark:border-zinc-600 focus:ring-primary-500/20 focus:border-primary-500'" />
  <!-- 错误提示（带图标） -->
  <p v-if="errors.email"
     class="flex items-center gap-1 text-xs text-red-500 dark:text-red-400
            animate-[shake_0.3s_ease-in-out]">
    <Icon name="error" class="w-3.5 h-3.5" />
    {{ errors.email }}
  </p>
</div>
```

### 抖动动画

```css
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  20%  { transform: translateX(-4px); }
  40%  { transform: translateX(4px); }
  60%  { transform: translateX(-2px); }
  80%  { transform: translateX(2px); }
}
```

### 成功态

```html
<div class="relative">
  <input class="w-full px-3.5 py-2.5 pr-10 rounded-lg
                border-green-400 dark:border-green-500
                focus:ring-green-400/20" />
  <!-- 右侧对勾图标 -->
  <span class="absolute right-3 top-1/2 -translate-y-1/2 text-green-500">
    <Icon name="check_circle" class="w-5 h-5" />
  </span>
</div>
```

---

## 输入框图标装饰

### 左侧图标

```html
<div class="relative">
  <span class="absolute left-3 top-1/2 -translate-y-1/2
               text-gray-400 dark:text-gray-500 pointer-events-none">
    <Icon name="person" class="w-5 h-5" />
  </span>
  <input type="text" placeholder="请输入用户名"
         class="w-full pl-10 pr-3.5 py-2.5 rounded-lg
                border border-gray-300 dark:border-zinc-600
                text-sm focus:outline-none focus:border-primary-500
                focus:ring-2 focus:ring-primary-500/20" />
</div>
```

### 左侧选择 + 右侧输入

```html
<div class="flex rounded-lg overflow-hidden
            border border-gray-300 dark:border-zinc-600
            focus-within:border-primary-500
            focus-within:ring-2 focus-within:ring-primary-500/20">
  <select class="px-3 py-2.5 bg-gray-50 dark:bg-zinc-700
                 border-r border-gray-300 dark:border-zinc-600
                 text-sm text-gray-700 dark:text-gray-300
                 outline-none">
    <option>+86</option>
    <option>+1</option>
  </select>
  <input type="tel" placeholder="请输入手机号"
         class="flex-1 px-3.5 py-2.5 bg-white dark:bg-zinc-800
                text-sm outline-none" />
</div>
```

---

## 密码强度指示器

```html
<div class="space-y-2">
  <input type="password" v-model="password"
         class="w-full px-3.5 py-2.5 rounded-lg border ..." />

  <!-- 强度条 -->
  <div class="flex gap-1.5">
    <div v-for="i in 4"
         class="h-1 flex-1 rounded-full transition-all duration-300"
         :class="i <= strengthLevel
           ? strengthColors[strengthLevel]
           : 'bg-gray-200 dark:bg-zinc-700'" />
  </div>

  <!-- 强度文字 -->
  <p class="text-xs"
     :class="strengthTextColors[strengthLevel]">
    {{ ['', '弱', '较弱', '中等', '强'][strengthLevel] }}
  </p>
</div>
```

```typescript
const strengthColors: Record<number, string> = {
  1: 'bg-red-500',
  2: 'bg-orange-500',
  3: 'bg-yellow-500',
  4: 'bg-green-500',
}
```

---

## 分步表单（Step Form）

```html
<div class="max-w-2xl mx-auto">
  <!-- 步骤指示器 -->
  <div class="flex items-center mb-8">
    <template v-for="(step, index) in steps">
      <!-- 步骤圆圈 -->
      <div class="flex items-center">
        <div :class="[
               index < currentStep
                 ? 'bg-primary-500 text-white'           // 已完成
                 : index === currentStep
                   ? 'bg-primary-500 text-white ring-4 ring-primary-100' // 当前
                   : 'bg-gray-200 dark:bg-zinc-600 text-gray-500'        // 未到
             ]"
             class="w-8 h-8 rounded-full flex items-center justify-center
                    text-sm font-semibold transition-all duration-300">
          <Icon v-if="index < currentStep" name="check" class="w-4 h-4" />
          <span v-else>{{ index + 1 }}</span>
        </div>
        <span class="ml-2 text-sm font-medium"
              :class="index <= currentStep
                ? 'text-gray-800 dark:text-gray-100'
                : 'text-gray-400 dark:text-gray-500'">
          {{ step.title }}
        </span>
      </div>
      <!-- 连接线 -->
      <div v-if="index < steps.length - 1"
           class="flex-1 h-0.5 mx-4"
           :class="index < currentStep
             ? 'bg-primary-500'
             : 'bg-gray-200 dark:bg-zinc-600'" />
    </template>
  </div>

  <!-- 步骤内容 -->
  <div class="bg-white dark:bg-zinc-800 rounded-xl border
              border-gray-200 dark:border-zinc-700 p-6">
    <component :is="steps[currentStep].component" />
  </div>

  <!-- 操作按钮 -->
  <div class="flex justify-between mt-6">
    <button v-if="currentStep > 0" @click="prev"
            class="px-6 py-2.5 rounded-lg border border-gray-300
                   text-sm font-medium hover:bg-gray-50
                   transition-colors">
      上一步
    </button>
    <button @click="next"
            class="px-6 py-2.5 rounded-lg bg-primary-500 text-white
                   text-sm font-medium hover:bg-primary-600
                   transition-colors ml-auto">
      {{ currentStep === steps.length - 1 ? '提交' : '下一步' }}
    </button>
  </div>
</div>
```

---

## 搜索栏

### 带筛选条件的搜索区

```html
<div class="bg-white dark:bg-zinc-800 rounded-xl border
            border-gray-200 dark:border-zinc-700 p-5 mb-4">
  <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
    <div class="space-y-1.5">
      <label class="text-xs font-medium text-gray-500 dark:text-gray-400">
        关键词
      </label>
      <input type="text" placeholder="名称/编码"
             class="w-full px-3 py-2 rounded-lg border border-gray-300
                    dark:border-zinc-600 bg-white dark:bg-zinc-700
                    text-sm focus:outline-none focus:border-primary-500
                    focus:ring-2 focus:ring-primary-500/20" />
    </div>
    <div class="space-y-1.5">
      <label class="text-xs font-medium text-gray-500 dark:text-gray-400">
        状态
      </label>
      <select class="w-full px-3 py-2 rounded-lg border border-gray-300
                     dark:border-zinc-600 bg-white dark:bg-zinc-700
                     text-sm focus:outline-none focus:border-primary-500">
        <option value="">全部</option>
        <option>启用</option>
        <option>禁用</option>
      </select>
    </div>
    <div class="space-y-1.5">
      <label class="text-xs font-medium text-gray-500 dark:text-gray-400">
        时间范围
      </label>
      <input type="date" class="w-full px-3 py-2 rounded-lg border ..." />
    </div>
    <!-- 操作按钮 -->
    <div class="flex items-end gap-2">
      <button class="flex-1 px-4 py-2 rounded-lg bg-primary-500 text-white
                     text-sm font-medium hover:bg-primary-600 transition-colors">
        查询
      </button>
      <button class="px-4 py-2 rounded-lg border border-gray-300
                     dark:border-zinc-600 text-sm text-gray-600
                     dark:text-gray-300 hover:bg-gray-50
                     dark:hover:bg-zinc-700 transition-colors">
        重置
      </button>
    </div>
  </div>
</div>
```

---

## 只读态与编辑态

```html
<!-- 只读态：无边框，背景略灰 -->
<div class="space-y-1.5">
  <label class="text-xs text-gray-500 dark:text-gray-400">用户名</label>
  <p class="px-3.5 py-2.5 rounded-lg
            bg-gray-50 dark:bg-zinc-700/50
            text-sm text-gray-800 dark:text-gray-200">
    admin
  </p>
</div>

<!-- 编辑态：有边框，可交互 -->
<div class="space-y-1.5">
  <label class="text-sm font-medium text-gray-700 dark:text-gray-300">
    用户名
  </label>
  <input type="text" value="admin"
         class="w-full px-3.5 py-2.5 rounded-lg border border-gray-300
                dark:border-zinc-600 bg-white dark:bg-zinc-800
                text-sm focus:border-primary-500
                focus:ring-2 focus:ring-primary-500/20" />
</div>
```

---

## 表单底部操作栏

```html
<!-- 固定底部操作栏 -->
<div class="sticky bottom-0 z-10
            bg-white/90 dark:bg-zinc-800/90
            backdrop-blur-md
            border-t border-gray-200 dark:border-zinc-700
            px-6 py-4
            flex items-center justify-end gap-3">
  <button class="px-6 py-2.5 rounded-lg
                 border border-gray-300 dark:border-zinc-600
                 text-sm font-medium text-gray-700 dark:text-gray-300
                 hover:bg-gray-50 dark:hover:bg-zinc-700
                 transition-colors">
    取消
  </button>
  <button class="px-6 py-2.5 rounded-lg
                 bg-primary-500 text-white text-sm font-medium
                 hover:bg-primary-600
                 disabled:opacity-50 disabled:cursor-not-allowed
                 transition-colors"
          :disabled="submitting">
    <span v-if="submitting" class="inline-flex items-center gap-2">
      <span class="w-4 h-4 border-2 border-white/30 border-t-white
                   rounded-full animate-spin" />
      提交中...
    </span>
    <span v-else>保存</span>
  </button>
</div>
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 标签和输入框间距不统一 | `space-y-1.5`（标签到输入框），`space-y-5`（字段间） |
| 错误提示只有红色文字 | 红色边框 + ring + 图标 + 抖动动画 |
| 必填项没有标记 | `<span class="text-red-500">*</span>` |
| 输入框太矮（< 36px） | 最低 py-2.5（约 40px），触摸友好 |
| 表单按钮和表单等宽 | 右对齐，按钮用固定宽度 |
| 提交中没有加载反馈 | 按钮内 Spinner + 禁用态 |
| 只读态和编辑态视觉一样 | 只读去边框加灰底，编辑有边框白底 |
| 搜索区每个字段一行 | 响应式多列网格 |
| 长表单一口气全显示 | 分组 fieldset 或分步 Step Form |
| placeholder 当标签用（聚焦后消失不知道是什么字段） | 独立标签 + placeholder 仅做示例 |
