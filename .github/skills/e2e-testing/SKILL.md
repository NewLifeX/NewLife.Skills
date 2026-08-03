---
name: e2e-testing
description: 'NewLife 前端/Cube 项目的 E2E 测试标准：Playwright 项目搭建、Cube 登录会话复用、标准 E2E 场景清单（页面加载/列表/增删改/表单校验/空状态/错误状态/权限拦截）、失败截图与追踪、测试数据隔离。使用场景：写 E2E 测试/补 E2E 覆盖/审查前端功能完成度。'
argument-hint: '说明被测前端项目（Cube/SPA）、是否已有 Playwright 环境、需要覆盖的前端功能编码。'
---

# NewLife E2E 测试标准

## 适用场景

- 前端功能点（页面/界面）的开发完成验证
- 前后端配合的完整业务流程验证
- 关键用户路径回归
- 审查前端功能是否"真正可用"（页面能点、数据能查、操作能落库）

## 核心原则

- **E2E 服务于"功能真正可用"**，不是跑通 happy path 就算完
- 每个前端功能点**必须覆盖下面的标准场景清单**，缺场景即视为未完成（与 dev-loop 步骤③ 前端 DoD 对齐）
- 独立于单元/集成测试运行（耗时长，单独执行）
- 失败必须留下截图 + 追踪，方便定位
- 测试数据必须隔离，不污染开发/生产数据

## Playwright 项目搭建

### 位置约定

在项目根目录建立独立 E2E 测试目录，与后端 XUnitTest 平级：

```
{Solution}/
├── {Project}.Web/                 # 前端项目（Cube/SPA）
├── XUnitTest/                     # 后端单元/集成测试
└── E2ETest/                       # Playwright E2E 测试
    ├── playwright.config.ts
    ├── tests/
    │   ├── login.spec.ts          # 登录与会话复用
    │   └── {模块}/{功能}.spec.ts  # 按模块/功能组织
    └── .auth/
        └── admin.json             # 登录态（storageState）
```

### 运行方式

- 本地：`npx playwright test`
- 先启动被测站点（Cube 站点通常 `dotnet run`），再跑 E2E
- 基地址通过 `playwright.config.ts` 的 `baseURL` 配置（默认 `http://localhost:5000`）

## Cube 登录会话复用

Cube 后台默认登录地址 `/Admin/Login`。每个 spec 都从登录开始会非常慢，用 **storageState 会话复用**：

1. 全局 setup 登录一次，保存登录态：

```typescript
// tests/global-setup.ts
import { chromium } from '@playwright/test';
export default async function () {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('/Admin/Login');
  await page.fill('#txtUser', 'admin');
  await page.fill('#txtPass', '******');
  await page.click('#btnLogin');
  await page.waitForURL('**/Admin/**');
  await page.context().storageState({ path: '.auth/admin.json' });
  await browser.close();
}
```

2. 各 spec 直接复用登录态：

```typescript
import { test, expect } from '@playwright/test';
test.use({ storageState: '.auth/admin.json' });
```

> 凭据从环境变量读取（`process.env.ADMIN_USER` / `ADMIN_PASS`），禁止硬编码进测试文件。

### 菜单导航

Cube 菜单基于权限动态生成。测试中优先用**直接访问 URL**（`/Admin/Area/Controller`）而非点击菜单，避免菜单文案变化导致脆弱；仅"菜单可见性/权限"相关场景才断言菜单项。

## 标准 E2E 场景清单

> 每个前端功能点至少覆盖以下场景。按功能性质适用——纯展示页可跳过"增删改"，仅列表功能可跳过表单。**能适用却缺失的场景 = 功能未完成。**

| # | 场景 | 验证内容 | 示例断言 |
|---|------|----------|----------|
| 1 | **页面加载** | 页面可访问、无 JS 控制台错误、标题/关键元素存在 | `expect(page).toHaveTitle(...)`；监听 `console`/`pageerror` 无错误 |
| 2 | **列表展示** | 数据列表渲染，列字段正确，有数据时行数 > 0 | `await expect(page.locator('tbody tr').first()).toBeVisible()` |
| 3 | **分页/搜索** | 数据多时分页可用；搜索框按关键词过滤出正确结果 | 输入关键词 → 断言结果行变化 |
| 4 | **新增** | 打开新增页 → 填表单 → 提交 → 列表出现新记录 | 提交后列表第一行含新值 |
| 5 | **编辑** | 打开已有记录 → 修改字段 → 保存 → 值已更新 | 详情/列表显示新值 |
| 6 | **删除** | 删除操作 → 确认 → 记录消失 | 删除后行数减少、记录不可查 |
| 7 | **表单校验** | 必填项为空 / 格式错误时提交被拦截并提示错误 | `expect(page.locator('.text-danger')).toBeVisible()` 或对应校验提示 |
| 8 | **空状态** | 无数据时展示友好空状态，而非白屏/报错 | 空列表有"暂无数据"类提示 |
| 9 | **错误状态** | 后端报错（如删除被依赖数据）时展示错误提示，页面不崩 | 错误消息可见，页面仍可操作 |
| 10 | **权限拦截** | 无权限用户访问该功能被拒（403/跳转登录），不泄露页面 | 无权限时看到拒绝提示而非数据 |

### 后端联动断言

前端操作**必须验证数据真正落库**，不能只断言 UI 变化：

- 新增/编辑后：刷新页面或重新搜索，断言记录仍存在且值正确（防"前端看似成功、后端未保存"）
- 删除后：刷新页面断言记录不再出现

## 场景骨架示例

```typescript
// tests/Device/DeviceList.spec.ts
import { test, expect } from '@playwright/test';
test.use({ storageState: '.auth/admin.json' });

test('设备列表 - 加载无错误', async ({ page }) => {
  const errors: string[] = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push(e.message));

  await page.goto('/Admin/Device/Device');
  await expect(page.locator('h1, .page-title')).toBeVisible();
  expect(errors).toEqual([]);
});

test('设备列表 - 新增后落库可查', async ({ page }) => {
  const name = `E2E设备${Date.now()}`;
  await page.goto('/Admin/Device/Device/Add');
  await page.fill('input[name="Name"]', name);
  await page.click('button[type="submit"]');
  await page.waitForURL('**/Device/Device');

  // 刷新后重新搜索，验证真正落库
  await page.goto('/Admin/Device/Device');
  await page.fill('input[placeholder*="搜索"], .search-input', name);
  await expect(page.locator('tbody tr', { hasText: name })).toHaveCount(1);
});
```

## 失败截图与追踪

- `playwright.config.ts` 开启自动截图 + trace：

```typescript
export default defineConfig({
  use: {
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
    baseURL: 'http://localhost:5000',
  },
  reporter: [['html', { open: 'never' }]],
});
```

- 失败定位顺序：先看截图 → 再看 trace（`npx playwright show-trace`）→ 再看页面截图与 console 错误

## 测试数据隔离

- 测试数据统一前缀（如 `E2E_` + 时间戳），断言时用唯一值，互不干扰
- 优先在测试内自建自清（新增 → 验证 → 删除），不依赖预置数据
- 运行前/后可清理由本次测试创建的数据（`E2E_` 前缀批量删除）
- 禁止对开发/生产数据做不可逆操作；有 `[Trait]`/环境开关跳过破坏性用例

## 与开发循环集成

前端功能点（页面类）在 dev-loop 中的完成标准：

1. 步骤②（运行测试）通过（后端单测 + 本功能 E2E 测试通过）
2. 步骤③ DoD 自检中，前端功能必须逐项对照本技能的标准场景清单（可适用项全覆盖）
3. 步骤④ 完成凭证中，测试凭证必须列出本功能实际的 E2E 测试用例名（`{功能}.spec.ts` 中的 `test(...)` 名称）
4. 缺 E2E 覆盖（可适用场景缺失）→ 视为未完成，回到步骤① 补充后重验

## 反模式（禁止）

| 反模式 | 说明 | 正确做法 |
|--------|------|----------|
| 只测 happy path | 仅"打开页面+点一下"就标完成 | 覆盖标准场景清单的可适用项 |
| 断言 UI 不验证落库 | 只断言提交成功提示，不验证数据 | 刷新/搜索后断言记录存在 |
| 硬编码凭据 | 测试文件里写死账号密码 | 环境变量读取 |
| 点击菜单导航 | 依赖菜单文案，易碎 | 直接访问 URL，仅权限场景断言菜单 |
| 测试数据无隔离 | 用真实数据增删改 | `E2E_` 前缀 + 自建自清 |
| 失败无留痕 | 失败后无截图无 trace | 开启 only-on-failure 截图 + trace |
