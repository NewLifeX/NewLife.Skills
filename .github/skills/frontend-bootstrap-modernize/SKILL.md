---
name: frontend-bootstrap-modernize
description: >
  Bootstrap 3/4 后台管理系统现代化美化：不更换框架前提下用 CSS 覆盖提升视觉、
  圆角/投影/色彩全局补丁、Bootstrap 3→5 渐进升级路径、
  ACE 管理模板样式增强、jQuery 组件视觉优化、暗色模式 CSS 变量方案。
  专为 Cube MVC 版（Bootstrap 3.3.7 + ACE + jQuery）定制。
argument-hint: >
  说明当前使用的 Bootstrap 版本和管理模板；
  描述希望改进的具体页面或组件。
---

# Bootstrap 后台现代化美化

## 适用场景

- NewLife.Cube MVC 版（Bootstrap 3.3.7 + ACE 管理模板）视觉升级
- 不更换框架前提下用纯 CSS 覆盖改善现有页面外观
- Bootstrap 3 → 5 渐进升级规划
- jQuery 组件与页面的视觉现代化

---

## 快速美化策略

在 **不修改 HTML 结构和 JS 逻辑** 的前提下，通过追加 CSS 文件快速提升视觉效果。

### 全局基础补丁

```css
/* cube-modern.css — 追加到 Cube.css 之后加载 */

/* === 1. 字体与渲染 === */
body {
  font-family: "Noto Sans SC", "PingFang SC", "Microsoft YaHei",
               -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
  font-size: 14px;
  color: #374151;
  background-color: #F3F4F6;
}

/* === 2. 全局圆角升级 === */
.panel,
.well,
.thumbnail,
.alert,
.modal-content {
  border-radius: 12px;
}

.btn {
  border-radius: 8px;
}

.form-control {
  border-radius: 8px;
}

.dropdown-menu {
  border-radius: 10px;
  box-shadow: 0 10px 15px -3px rgba(0,0,0,0.1),
              0 4px 6px rgba(0,0,0,0.05);
}

.nav-tabs > li > a {
  border-radius: 8px 8px 0 0;
}

/* === 3. 投影升级（去掉粗边框感） === */
.panel {
  border: 1px solid #E5E7EB;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}

.modal-content {
  border: none;
  box-shadow: 0 25px 50px -12px rgba(0,0,0,0.25);
}

/* === 4. 过渡动画 === */
.btn,
.form-control,
.nav > li > a,
.panel,
a {
  transition: all 0.15s ease;
}
```

### 主色替换

```css
/* 品牌色替换（ACE 默认蓝 → 现代蓝） */
:root {
  --cube-primary: #3B82F6;
  --cube-primary-hover: #2563EB;
  --cube-primary-active: #1D4ED8;
  --cube-primary-light: #EFF6FF;
}

.btn-primary,
.btn-info {
  background-color: var(--cube-primary);
  border-color: var(--cube-primary);
}

.btn-primary:hover,
.btn-primary:focus,
.btn-info:hover,
.btn-info:focus {
  background-color: var(--cube-primary-hover);
  border-color: var(--cube-primary-hover);
}

.btn-primary:active,
.btn-info:active {
  background-color: var(--cube-primary-active);
  border-color: var(--cube-primary-active);
}

/* 链接色 */
a { color: var(--cube-primary); }
a:hover { color: var(--cube-primary-hover); }

/* 分页器 */
.pagination > .active > a {
  background-color: var(--cube-primary);
  border-color: var(--cube-primary);
}

/* 选中/聚焦态 */
.form-control:focus {
  border-color: var(--cube-primary);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}
```

---

## 按钮美化

```css
/* 按钮高度统一 + 内间距 */
.btn {
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  line-height: 1.5;
  border-width: 1px;
  outline: none;
}

.btn:focus-visible {
  box-shadow: 0 0 0 2px var(--cube-primary),
              0 0 0 4px rgba(59, 130, 246, 0.2);
}

/* 小号按钮 */
.btn-xs,
.btn-sm {
  padding: 4px 10px;
  font-size: 12px;
  border-radius: 6px;
}

/* 次要按钮（default）美化 */
.btn-default {
  background-color: #FFFFFF;
  border-color: #D1D5DB;
  color: #374151;
}

.btn-default:hover {
  background-color: #F9FAFB;
  border-color: #9CA3AF;
  color: #111827;
}

/* 危险按钮 */
.btn-danger {
  background-color: #EF4444;
  border-color: #EF4444;
}

.btn-danger:hover {
  background-color: #DC2626;
  border-color: #DC2626;
}

/* 成功按钮 */
.btn-success {
  background-color: #10B981;
  border-color: #10B981;
}

.btn-success:hover {
  background-color: #059669;
  border-color: #059669;
}

/* 幽灵按钮（ACE icon-only 按钮） */
.btn-white,
.btn-link {
  border: none;
  background: transparent;
  color: #6B7280;
}

.btn-white:hover,
.btn-link:hover {
  background-color: #F3F4F6;
  color: #111827;
}
```

---

## 表单美化

```css
.form-control {
  height: 40px;
  padding: 8px 12px;
  font-size: 14px;
  border-color: #D1D5DB;
  background-color: #FFFFFF;
  color: #111827;
}

.form-control:focus {
  border-color: var(--cube-primary);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

.form-control::placeholder {
  color: #9CA3AF;
}

/* Select 美化 */
select.form-control {
  appearance: none;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath d='M6 8L1 3h10L6 8z' fill='%236B7280'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: right 12px center;
  padding-right: 32px;
}

/* Checkbox / Radio 美化 */
.checkbox input[type="checkbox"],
.radio input[type="radio"] {
  accent-color: var(--cube-primary);
  width: 16px;
  height: 16px;
}
```

---

## 表格美化

```css
.table {
  border-collapse: separate;
  border-spacing: 0;
}

/* 表头 */
.table > thead > tr > th {
  background-color: #F9FAFB;
  color: #6B7280;
  font-weight: 600;
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 12px 16px;
  border-bottom: 2px solid #E5E7EB;
  border-top: none;
}

/* 数据行 */
.table > tbody > tr > td {
  padding: 12px 16px;
  vertical-align: middle;
  border-top-color: #F3F4F6;
  font-size: 14px;
}

/* 斑马纹 */
.table-striped > tbody > tr:nth-of-type(even) {
  background-color: rgba(249, 250, 251, 0.5);
}

/* 悬停高亮 */
.table-hover > tbody > tr:hover {
  background-color: #EFF6FF;
}

/* 表格圆角容器（包在 panel 里时） */
.panel > .table:first-child > thead > tr:first-child > th:first-child {
  border-top-left-radius: 11px;
}

.panel > .table:first-child > thead > tr:first-child > th:last-child {
  border-top-right-radius: 11px;
}
```

---

## Panel 卡片美化

```css
.panel {
  border: 1px solid #E5E7EB;
  box-shadow: 0 1px 3px rgba(0,0,0,0.06);
  margin-bottom: 20px;
}

.panel-default > .panel-heading {
  background-color: #FFFFFF;
  border-bottom: 1px solid #F3F4F6;
  padding: 16px 20px;
  border-radius: 12px 12px 0 0;
}

.panel-title {
  font-size: 16px;
  font-weight: 600;
  color: #111827;
}

.panel-body {
  padding: 20px;
}

.panel-footer {
  background-color: #FAFAFA;
  border-top: 1px solid #F3F4F6;
  padding: 12px 20px;
  border-radius: 0 0 12px 12px;
}
```

---

## ACE 侧边栏美化

```css
/* ACE 侧边栏底色 */
.sidebar {
  background-color: #1E293B;
}

/* 菜单项 */
.nav-list > li > a {
  padding: 10px 16px;
  color: #CBD5E1;
  font-size: 14px;
  transition: all 0.15s ease;
}

.nav-list > li > a:hover {
  background-color: rgba(255, 255, 255, 0.05);
  color: #F1F5F9;
}

/* 活跃菜单 */
.nav-list > li.active > a {
  background-color: rgba(59, 130, 246, 0.15);
  color: #60A5FA;
  border-left: 3px solid #3B82F6;
}

/* 子菜单 */
.nav-list > li > .submenu > li > a {
  padding-left: 40px;
  font-size: 13px;
  color: #94A3B8;
}

.nav-list > li > .submenu > li > a:hover {
  color: #F1F5F9;
  background-color: rgba(255, 255, 255, 0.03);
}

/* 侧边栏折叠图标 */
.menu-icon {
  font-size: 16px;
  width: 20px;
  text-align: center;
}
```

---

## 顶部导航栏美化

```css
.navbar {
  background-color: #FFFFFF;
  border-bottom: 1px solid #E5E7EB;
  box-shadow: 0 1px 2px rgba(0,0,0,0.04);
  min-height: 56px;
}

.navbar-brand {
  font-weight: 700;
  color: #111827;
}

.navbar-nav > li > a {
  color: #6B7280;
  font-size: 14px;
  padding: 16px 12px;
}

.navbar-nav > li > a:hover {
  color: #111827;
  background-color: #F3F4F6;
}

/* 用户下拉 */
.navbar-nav > li.dropdown > a .badge {
  background-color: #EF4444;
  font-size: 10px;
  padding: 2px 5px;
  border-radius: 999px;
}
```

---

## 模态框美化

```css
.modal-content {
  border: none;
  border-radius: 16px;
  box-shadow: 0 25px 50px -12px rgba(0,0,0,0.25);
  overflow: hidden;
}

.modal-header {
  padding: 16px 24px;
  border-bottom: 1px solid #F3F4F6;
}

.modal-title {
  font-size: 18px;
  font-weight: 600;
  color: #111827;
}

.modal-body {
  padding: 24px;
}

.modal-footer {
  padding: 12px 24px;
  border-top: 1px solid #F3F4F6;
  background-color: #FAFAFA;
}

/* 遮罩 */
.modal-backdrop.in {
  opacity: 0.4;
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
}
```

---

## 分页器美化

```css
.pagination > li > a,
.pagination > li > span {
  border-color: #E5E7EB;
  color: #6B7280;
  padding: 6px 12px;
  font-size: 14px;
  margin: 0 2px;
  border-radius: 8px;
  transition: all 0.15s ease;
}

.pagination > li > a:hover {
  background-color: #F3F4F6;
  border-color: #D1D5DB;
  color: #111827;
}

.pagination > .active > a,
.pagination > .active > a:hover {
  background-color: var(--cube-primary);
  border-color: var(--cube-primary);
  color: #FFFFFF;
}

.pagination > .disabled > a {
  opacity: 0.5;
  cursor: not-allowed;
}
```

---

## Bootstrap 3 → 5 渐进升级路径

如果团队决定逐步升级框架：

| 阶段 | 目标 | 方法 |
|------|------|------|
| **Phase 0** | 视觉补丁（当前） | CSS 覆盖文件，不改 HTML/JS |
| **Phase 1** | jQuery → 原生 | 逐步替换 `$.ajax` → `fetch`，简单 DOM 操作 → `querySelector` |
| **Phase 2** | Bootstrap 3.3.7 → 5.3 | 引入 BS5 CSS，逐页迁移 class 名（`panel` → `card`，`btn-default` → `btn-secondary`） |
| **Phase 3** | ACE 模板 → 自定义布局 | 用 BS5 Grid + Utilities 重写布局，去除 ACE 依赖 |
| **Phase 4** | jQuery 插件 → 原生或 Stimulus | DataTables → 原生 table + 分页，Select2 → 原生 `<datalist>` 或轻量替代 |

### 类名映射表（BS3 → BS5）

| Bootstrap 3 | Bootstrap 5 |
|-------------|-------------|
| `.panel` | `.card` |
| `.panel-heading` | `.card-header` |
| `.panel-body` | `.card-body` |
| `.panel-footer` | `.card-footer` |
| `.btn-default` | `.btn-secondary` 或 `.btn-outline-secondary` |
| `.btn-xs` | `.btn-sm`（BS5 无 xs） |
| `.well` | `.card` 或 `.bg-light p-3 rounded` |
| `.label` | `.badge` |
| `.label-success` | `.badge bg-success` |
| `.pull-right` | `.float-end` |
| `.pull-left` | `.float-start` |
| `.hidden-xs` | `.d-none d-sm-block` |
| `.visible-xs` | `.d-block d-sm-none` |
| `.img-responsive` | `.img-fluid` |

---

## 暗色模式 CSS 变量方案（可选）

```css
/* 暗色模式基础（通过 body class 切换） */
body.dark-mode {
  --cube-bg-page: #18181B;
  --cube-bg-card: #27272A;
  --cube-bg-input: #3F3F46;
  --cube-text-primary: #F3F4F6;
  --cube-text-secondary: #A1A1AA;
  --cube-border: #3F3F46;
}

body.dark-mode {
  background-color: var(--cube-bg-page);
  color: var(--cube-text-primary);
}

body.dark-mode .panel,
body.dark-mode .modal-content {
  background-color: var(--cube-bg-card);
  border-color: var(--cube-border);
}

body.dark-mode .form-control {
  background-color: var(--cube-bg-input);
  border-color: var(--cube-border);
  color: var(--cube-text-primary);
}

body.dark-mode .table > thead > tr > th {
  background-color: rgba(63, 63, 70, 0.5);
  color: var(--cube-text-secondary);
}

body.dark-mode .table > tbody > tr > td {
  border-top-color: var(--cube-border);
}

body.dark-mode .sidebar {
  background-color: #0F172A;
}
```

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| 直接修改 Bootstrap 源 CSS | 追加覆盖 CSS 文件，保持升级能力 |
| 混用 BS3 和 BS5 CSS（全量引入） | 渐进迁移，一个页面一个页面替换 |
| 覆盖到处用 `!important` | 增加选择器特异性（如 `.cube .btn`） |
| 只改按钮不改其他元素 | 全局统一：按钮+表单+表格+面板+导航 |
| 圆角只改了外层没改内层 | 嵌套元素圆角要递减（外 12px → 内 8px） |
| 暗色模式用 `filter: invert()` | 用 CSS 变量正确定义每个颜色 |
| 整个替换框架 | 先补丁再渐进，保证业务稳定 |
