---
name: testing-strategy
description: 'NewLife 项目测试策略：单元测试（xUnit + DisplayName）、集成测试（XCode SQLite 轻量集成 + 真实网络）、E2E 测试、测试项目结构约定。使用场景：写测试/补测试/测试失败排查/新建测试项目/审查测试覆盖率。'
argument-hint: '说明测试目标（单元/集成/E2E）、被测模块、是否需要 SQLite 集成测试。'
---

# NewLife 测试策略

## 适用场景

- 新建测试项目或为现有项目补充测试
- 代码变更后运行测试验证
- 测试失败排查
- 审查测试覆盖率是否足够
- 判断某段逻辑应该用单元测试还是集成测试

## 核心原则

- **测试服务于质量，不服务于覆盖率数字**
- **单元测试优先**：纯逻辑、无外部依赖的代码必须用单元测试覆盖
- **集成测试补位**：涉及数据库、网络、文件 I/O 的逻辑用集成测试验证
- **不因测试而改变代码架构**：不为方便测试而包装虚方法、引入多余接口
- **测试代码也是代码**：遵守同样的编码规范

## 测试项目结构

### 命名与位置

```
{Solution}/
├── {Project}/                     # 被测项目
├── XUnitTest/                     # 测试项目
│   ├── XUnitTest.csproj           # 引用所有被测项目
│   ├── {Project}/                 # 按被测项目分子目录
│   │   ├── {Namespace}/           # 按命名空间分子目录
│   │   │   ├── {ClassName}Tests.cs
│   │   │   └── ...
│   │   └── ...
│   └── ...
└── {Solution}.sln
```

**规则**：
- 测试项目名统一为 `XUnitTest`
- 测试类命名 `{ClassName}Tests`，与被测类一一对应
- 目录结构映射被测项目的命名空间层级
- 网络端口使用 `0`/随机端口，IO 使用临时目录

### 项目文件

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.*" />
    <PackageReference Include="xunit" Version="2.*" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.*" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\{Project}\{Project}.csproj" />
  </ItemGroup>
</Project>
```

## 单元测试规范

### 编写规范

- 测试方法加 `[DisplayName("中文描述意图")]`
- 覆盖：核心逻辑 + 边界条件 + 异常路径 + 空值处理
- 纯函数优先，被测方法不应依赖外部状态
- 单个测试方法 < 50 行，超过则拆分
- 使用 `[Theory]` + `[InlineData]` 覆盖多组输入

```csharp
public class StringHelperTests
{
    [Fact]
    [DisplayName("SplitAsInt_空字符串_返回空数组")]
    public void SplitAsInt_EmptyString_ReturnsEmptyArray()
    {
        var result = "".SplitAsInt(",");
        Assert.Empty(result);
    }

    [Theory]
    [DisplayName("SplitAsInt_有效输入_正确解析")]
    [InlineData("1,2,3", new[] { 1, 2, 3 })]
    [InlineData("10,20", new[] { 10, 20 })]
    public void SplitAsInt_ValidInput_ParsesCorrectly(String input, Int32[] expected)
    {
        var result = input.SplitAsInt(",");
        Assert.Equal(expected, result);
    }

    [Fact]
    [DisplayName("SplitAsInt_Null输入_抛出ArgumentNullException")]
    public void SplitAsInt_NullInput_ThrowsArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(() => ((String)null!).SplitAsInt(","));
    }
}
```

### 断言选择

| 场景 | 断言 |
|------|------|
| 等值比较 | `Assert.Equal(expected, actual)` |
| 集合比较 | `Assert.Equal(expectedList, actualList)` |
| 异常验证 | `Assert.Throws<T>(() => ...)` |
| 空/非空 | `Assert.Null(value)` / `Assert.NotNull(value)` |
| 布尔条件 | `Assert.True(condition)` / `Assert.False(condition)` |
| 范围断言 | `Assert.InRange(value, low, high)` |
| 字符串包含 | `Assert.Contains(substring, value)` |

## 集成测试规范

### 适用场景

- 数据库 CRUD 操作验证
- 网络通信（客户端-服务端交互）
- 文件 I/O（读写完整文件）
- 多组件协作流程

### SQLite 轻量集成测试

利用 XCode 多数据库抽象，将连接串指向 SQLite 即可零架构侵入测试实体和 Service：

```csharp
public class UserServiceTests : IDisposable
{
    private readonly String _tempDb;

    public UserServiceTests()
    {
        _tempDb = Path.GetTempFileName();
        // 配置 XCode 使用 SQLite
        var connStr = $"Data Source={_tempDb};Mode=Memory";
        // 初始化表结构...
    }

    [Fact]
    [DisplayName("CreateUser_有效数据_成功插入并返回用户")]
    public void CreateUser_ValidData_InsertsAndReturns()
    {
        var user = new User { Name = "测试用户", Age = 25 };
        user.Insert();

        Assert.True(user.ID > 0);
        var found = User.FindByID(user.ID);
        Assert.NotNull(found);
        Assert.Equal("测试用户", found.Name);
    }

    public void Dispose()
    {
        if (File.Exists(_tempDb)) File.Delete(_tempDb);
    }
}
```

### 真实环境集成测试

- 允许访问数据库和网络
- 用户需预配置 appkey / 登录信息 / 连接串
- 使用 `[Trait("Category", "Integration")]` 分类，便于 CI 按需跳过
- 测试失败不污染生产数据——使用测试专用库/表

## E2E 测试

### 适用场景

- 前端页面交互流程验证
- 前后端配合的完整业务流程
- 关键用户路径回归

### 实施建议

- 使用 Playwright / Selenium 等浏览器自动化工具
- 覆盖核心路径，不做穷举
- 独立于单元/集成测试运行（耗时长）
- 失败截图 + 日志辅助排查

## 反模式（禁止）

| 反模式 | 说明 | 正确做法 |
|--------|------|---------|
| 为测试包装虚方法 | 为方便 mock 而把方法标 `virtual` | 使用 SQLite 集成测试代替 mock |
| 过度 mock | 每个依赖都 mock，测试变成 mock 配置测试 | 优先使用真实轻量依赖（SQLite/内存流） |
| 测试实现细节 | 测试私有方法、内部状态 | 测试公开 API 行为 |
| 测试间共享可变状态 | 一个测试的副作用影响另一个 | 每个测试独立初始化/清理 |
| 测试代码不需要规范 | 测试类不写注释、随意命名 | 测试代码遵守同样规范 |
| 跳过失败的测试 | 标记 `[Skip]` 而不修复 | 修复代码或更新测试预期 |

## 强制测试规则（开发流程硬约束）

**每次实现功能，默认同步补充测试，测试通过后方可标记完成。**

| 规则 | 说明 |
|------|------|
| 默认补充单元测试 | 实现功能代码后，同步编写对应单元测试，覆盖核心逻辑 + 边界条件 |
| 默认执行测试 | 修改代码后默认执行相关单元测试 |
| 失败循环修复 | 测试不通过 → 分析原因 → 修复代码或测试 → 重跑，循环直到全部通过 |
| 跳过需明确声明 | 仅当用户明确说"不跑测试"/"跳过测试"时方可跳过 |
| 测试通过后更新状态 | 功能清单中对应功能标记 ✅ 已完成 |

### 测试类型选择

| 功能类型 | 测试类型 | 详见 |
|----------|---------|------|
| 纯逻辑/算法/工具方法 | 单元测试 | 本 skill |
| 数据库 CRUD/文件 I/O/网络通信 | 集成测试（SQLite 或真实环境） | 本 skill |
| 文件格式/网络协议/编解码 | 竞品交叉兼容测试 | `cross-compatibility-testing` |
| 前端交互/前后端流程 | E2E 测试 | 本 skill |
| 性能敏感路径 | 基准测试 | `benchmark-testing` |

## 测试执行原则

- 代码变更后默认执行相关单元测试
- 不通过则修复后重跑，循环直到全部通过
- 除非用户明确说"不跑测试"，否则不得跳过
- 集成测试和 E2E 测试可在 CI 中按需运行
- 测试通过后更新功能模块清单状态

## 参考资料

- 竞品交叉兼容测试：参见 `cross-compatibility-testing` 技能
- 性能基准测试：参见 `benchmark-testing` 技能
- 架构分层与测试策略：参见 `project-architecture` 技能
