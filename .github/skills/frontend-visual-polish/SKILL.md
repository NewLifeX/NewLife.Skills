---
name: frontend-visual-polish
description: >
  前端视觉精修检查清单（20+ 项）：字体渲染、颜色对比度、间距一致性、阴影层级、
  动画流畅度、图标统一性、暗色模式完整性、滚动条美化、选中色、光标样式、
  loading/empty/error 三态覆盖、首屏感知速度优化。
  适用于上线前最终视觉打磨、设计走查、前端代码审查等任务。
argument-hint: >
  说明目标页面 URL 或组件名称；
  如有设计稿对照，简述与设计稿的主要差异。
---

# 前端视觉精修检查清单

## 适用场景

- 上线前最终视觉打磨
- 设计走查 / 自查
- 前端代码审查中的视觉一致性检查
- 客户反馈"不好看"后的系统性排查与改进

---

## 检查清单

### 1. 字体与文字

- [ ] **中文友好字体栈**：是否设置了 `"Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif`？
- [ ] **字体渲染平滑**：是否添加 `-webkit-font-smoothing: antialiased`？
- [ ] **字号层级**：是否有明确的字号梯度（12/13/14/16/20/24），不随意出现 15/17/19 等非标尺寸？
- [ ] **行高舒适**：正文行高 ≥ 1.5，标题行高 ≥ 1.25？
- [ ] **文字截断**：长文本是否使用 `truncate`（单行）或 `line-clamp-N`（多行）？
- [ ] **数字等宽**：数据表格/统计卡的数字是否使用 `tabular-nums`？

### 2. 颜色与对比度

- [ ] **主色确认**：是否替换了组件库默认蓝，使用统一品牌色？
- [ ] **对比度达标**：正文文字对比度 ≥ 4.5:1，大标题 ≥ 3:1（WCAG AA）？
- [ ] **功能色统一**：成功绿/警告橙/错误红/信息蓝是否全局一致？
- [ ] **灰色梯度**：是否使用同一灰色系（如 Tailwind gray 或 zinc），不混用不同灰度？
- [ ] **选中色**：`::selection` 是否设为品牌色淡底？

### 3. 间距与对齐

- [ ] **8px 网格**：所有间距是否是 4/8/12/16/20/24/32 的倍数？
- [ ] **内边距一致**：同级别容器（卡片/面板/模态框）的 padding 是否相同？
- [ ] **外边距一致**：卡片间距、section 间距是否全局统一？
- [ ] **垂直居中**：图标与文字是否垂直对齐（`items-center`）？
- [ ] **左对齐**：表单标签 / 表格列标题是否统一左对齐？

### 4. 圆角与边框

- [ ] **圆角梯度**：是否有明确的圆角梯度（4/6/8/12/16/999）？
- [ ] **嵌套圆角递减**：外层容器 12px → 内层元素 8px → 按钮 6px？
- [ ] **边框颜色统一**：是否统一用 `border-gray-200 dark:border-zinc-700`？
- [ ] **边框粗细不超过 1px**：除高亮/激活态，常规边框用 1px？

### 5. 阴影

- [ ] **阴影层级**：是否有 none/sm/md/lg 四级投影，不随意自造阴影值？
- [ ] **暗色模式投影降级**：暗色下投影是否减弱或去掉（暗底上投影不明显）？
- [ ] **hover 投影变化**：可点击卡片 hover 时投影是否从 sm → md？
- [ ] **弹窗投影够重**：模态框/下拉菜单是否有 xl 级投影？

### 6. 动画与过渡

- [ ] **交互反馈 ≤ 200ms**：按钮 hover/active、输入框 focus 的过渡时长？
- [ ] **页面切换 ≤ 300ms**：路由切换、标签页切换的过渡时长？
- [ ] **不撕裂**：动画是否使用 `transform/opacity`（GPU 加速），避免 `width/height/top` 动画？
- [ ] **减弱动画尊重**：是否添加 `prefers-reduced-motion: reduce` 媒体查询？
- [ ] **骨架屏脉冲**：加载状态是否用 `animate-pulse` 而非空白？

### 7. 图标

- [ ] **图标体系统一**：是否全站用同一图标库（如 Material Symbols/Heroicons/Lucide）？
- [ ] **图标尺寸统一**：导航图标 20px、行内图标 16px、按钮图标 16-18px？
- [ ] **图标颜色跟随文字**：图标是否用 `currentColor`？
- [ ] **图标与文字间距**：是否用 `gap-2`（8px）统一？
- [ ] **无 Font Awesome + Material + Heroicons 混用**？

### 8. 暗色模式

- [ ] **背景层级正确**：页面背景最深 → 卡片次深 → 弹窗最浅？
- [ ] **文字颜色适配**：主文字 gray-100、次文字 gray-400、辅助文字 gray-500？
- [ ] **边框可见**：暗色下边框是否比背景略浅（zinc-700）？
- [ ] **图片亮度**：亮色图片在暗色下是否添加 `brightness(0.9)`？
- [ ] **投影调整**：暗色下投影是否比亮色更重或换成边框发光？
- [ ] **焦点环可见**：`focus-visible:ring` 在暗色下是否清晰可见？
- [ ] **防闪烁**：页面加载时是否有 `<head>` 内联脚本防止亮→暗跳变？

### 9. 滚动条

- [ ] **自定义滚动条**：是否用细滚动条（6px）替代浏览器默认粗滚动条？
- [ ] **暗色模式适配**：滚动条颜色是否随主题切换？
- [ ] **hover 显现**：侧边栏/面板内的滚动条是否默认隐藏，hover 时淡入？

### 10. 交互三态覆盖

- [ ] **按钮三态**：hover（变浅）+ active（加深/微缩）+ focus-visible（ring）？
- [ ] **输入框三态**：focus（蓝色边框+ring）+ error（红色边框）+ disabled（灰底+禁止光标）？
- [ ] **卡片两态**：hover（投影加深/边框变色）+ active（微缩 scale 0.98-0.99）？
- [ ] **链接两态**：hover（加深/下划线）+ visited（可选区分）？
- [ ] **disabled 统一**：`opacity-50 + cursor-not-allowed`？

### 11. 页面状态覆盖

- [ ] **Loading 态**：首屏骨架屏、局部加载覆盖层、按钮内 Spinner 三种？
- [ ] **Empty 态**：空列表有插画 + 引导文字 + 行动按钮？
- [ ] **Error 态**：网络错误有重试按钮？表单错误有字段级提示？
- [ ] **403/404/500**：是否有自定义错误页面而非浏览器默认？
- [ ] **成功态**：关键操作成功后有 Toast/Success 页面？

### 12. 响应式

- [ ] **移动端表格**：宽表是否有横向滚动？
- [ ] **移动端导航**：是否有汉堡菜单或底部导航？
- [ ] **触摸友好**：按钮/链接点击区域 ≥ 44×44px？
- [ ] **安全区域**：iPhone 底部是否有 `env(safe-area-inset-bottom)` 留白？

### 13. 细节打磨

- [ ] **Favicon**：是否有品牌 favicon 而非浏览器默认？
- [ ] **页面标题**：每个路由是否有有意义的 `<title>`？
- [ ] **光标**：可点击元素 `cursor-pointer`，不可交互 `cursor-default`，加载中 `cursor-wait`？
- [ ] **拖拽**：可拖拽元素 `cursor-grab` / `cursor-grabbing`？
- [ ] **输入法优化**：搜索框 `enterkeyhint="search"`？

---

## 快速修复代码片段

### 全局字体平滑

```css
body {
  font-family: "Noto Sans SC", "PingFang SC", "Microsoft YaHei",
               -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}
```

### 全局选中色

```css
::selection {
  background-color: rgba(59, 130, 246, 0.2);
  color: inherit;
}
```

### 全局焦点环

```css
:focus-visible {
  outline: none;
  box-shadow: 0 0 0 2px #3B82F6,
              0 0 0 4px rgba(59, 130, 246, 0.2);
}
```

### 减弱动画尊重

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

### 数字等宽

```css
.tabular-nums {
  font-variant-numeric: tabular-nums;
}

/* 用在统计卡、表格数值列 */
```

### 暗色模式防闪烁脚本

```html
<!-- 放在 <head> 最前面 -->
<script>
  (function() {
    var theme = localStorage.getItem('theme');
    if (theme === 'dark' ||
        (!theme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      document.documentElement.classList.add('dark');
    }
  })();
</script>
```

---

## 修复优先级矩阵

| 优先级 | 修复项 | 理由 |
|--------|--------|------|
| **P0 必修** | 字体栈 + 字体平滑 | 最影响整体观感 |
| **P0 必修** | 主色替换 | 去除"默认感" |
| **P0 必修** | 圆角统一 | 现代感标志 |
| **P1 高** | 按钮三态 | 交互品质感 |
| **P1 高** | 表格美化（表头/斑马纹/hover） | 后台核心页面 |
| **P1 高** | 间距统一（8px 网格） | 整体协调 |
| **P2 中** | 暗色模式 | 趋势 / 护眼 |
| **P2 中** | 骨架屏 + 空状态 | 感知性能 |
| **P2 中** | 自定义滚动条 | 细节品质 |
| **P3 低** | 动画/过渡 | 锦上添花 |
| **P3 低** | 减弱动画适配 | 无障碍合规 |

---

## 反模式清单

| ❌ 反模式 | ✅ 正确做法 |
|----------|-----------|
| "看着差不多就行" | 逐项检查清单，逐项确认 |
| 只让设计师做走查 | 开发自查 → 设计走查 → 交叉审查 |
| 修了一个页面忘了其他 | 全局 CSS 变量/Token 管控 |
| 圆角写了 5 种不同值 | 定义 4 级圆角梯度全局复用 |
| 阴影随便写 box-shadow | 定义 4 级投影全局复用 |
| 动画全写 0.3s | 交互 150ms，面板 200ms，路由 300ms |
| 暗色模式只改了背景没改文字/边框 | 完整适配所有颜色语义变量 |
| loading 状态用白屏 | 骨架屏保留页面结构 |
| 错误直接 alert() | Toast / 行级错误提示 |
| 不关注可访问性 | 最低保证色彩对比度和焦点可见 |
