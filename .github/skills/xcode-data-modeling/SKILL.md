---
name: xcode-data-modeling
description: >
  使用 NewLife.XCode 进行数据建模，涵盖 Model.xml 完整属性体系（Option/Table/Column/Index）、
  主键设计约定（Int32 自增 vs Int64 雪花 ID）、Map 外键关联、ShowIn 显示控制、DataScale 分表字段、
  xcode 命令生成实体类，以及多模块项目目录结构。
  适用于新建数据层项目、设计表结构、修改 *.xml 模型文件等任务。
argument-hint: >
  说明业务场景：需要建哪些表、主要字段类型、外键关系、是否有分表需求、是否需要生成魔方控制器。
---

# XCode 数据建模

## 适用场景

- 新建 XCode 数据类库，从零开始创建 `Model.xml` 进行数据建模。
- 向已有模型文件添加新表或新字段。
- 设计合理的主键策略（普通表 vs 大数据表）。
- 配置字段外键关联（Map）、界面显示控制（ShowIn）、分表标记（DataScale）。
- 执行 `xcode` 命令生成实体类、模型接口、数据字典、魔方控制器。

## 环境准备

```powershell
# 安装 XCode NuGet 包
dotnet add package NewLife.XCode

# 安装 xcodetool 代码生成工具
dotnet tool install xcodetool -g

# 安装项目模板（发布日期须 > 2025-08-01）
dotnet new details NewLife.Templates
dotnet new install NewLife.Templates   # 未安装或版本过旧时执行

# 创建数据类库项目
dotnet new xcode -n Zero.Data

# 创建 Web 管理后台（可选）
dotnet new cube -n ZeroWeb

# 创建控制台应用（可选）
dotnet new nconsole -n ZeroApp
```

## Model.xml 文件结构

```xml
<?xml version="1.0" encoding="utf-8"?>
<EntityModel xmlns:xs="http://www.w3.org/2001/XMLSchema-instance"
             xs:schemaLocation="https://newlifex.com https://newlifex.com/Model202509.xsd"
             xmlns="https://newlifex.com/Model202509.xsd">
  <Option>
    <!-- 全局配置 -->
  </Option>
  <Tables>
    <Table>
      <Columns>
        <Column />
      </Columns>
      <Indexes>
        <Index />
      </Indexes>
    </Table>
  </Tables>
</EntityModel>
```

## Option 配置项

| 配置项 | 说明 | 示例 |
|--------|------|------|
| `Namespace` | 命名空间 | `Zero.Data` |
| `ConnName` | 数据库连接名 | `Zero` |
| `Output` | 实体类输出目录 | `.\` |
| `BaseClass` | 实体基类 | `Entity` |
| `ChineseFileName` | 使用中文文件名 | `True` |
| `Nullable` | 生成可空引用类型 | `True` |
| `HasIModel` | 实现 IModel 接口 | `True` |
| `ModelClass` | 模型类模板 | `{name}Model` |
| `ModelsOutput` | 模型类输出目录 | `.\Models\` |
| `ModelInterface` | 模型接口模板 | `I{name}` |
| `InterfacesOutput` | 接口输出目录 | `.\Interfaces\` |
| `DisplayName` | 魔方区域显示名 | `订单管理` |
| `CubeOutput` | 魔方控制器输出目录 | `../../OrderWeb/Areas/Order` |
| `NameFormat` | 命名格式 | `Default`/`Upper`/`Lower`/`Underline` |
| `ExtendNameSpace` | 额外引用命名空间（逗号分隔）| `System.Xml.Serialization` |

## Table 属性

| 属性 | 说明 | 示例 |
|------|------|------|
| `Name` | 实体类名 | `Order` |
| `TableName` | 数据库表名（可选，默认同 Name）| `sys_order` |
| `Description` | 表说明（`。`后为注释）| `订单。电商订单主表` |
| `ConnName` | 独立连接名（覆盖全局）| `Log` |
| `BaseType` | 基类（支持实体继承）| `EntityBase` |
| `InsertOnly` | 仅插入模式（日志表优化）| `True` |
| `IsView` | 视图标识 | `True` |

## Column 属性完整参考

### 基础属性

| 属性 | 说明 | 示例 |
|------|------|------|
| `Name` | 属性名 | `UserName` |
| `ColumnName` | 数据库列名（可选）| `user_name` |
| `DataType` | 数据类型 | `Int32`/`Int64`/`String`/`DateTime`/`Boolean`/`Double`/`Decimal` |
| `Description` | 字段说明 | `用户名。登录账号` |
| `Length` | 字符串长度 | `50`/`200`/`-1`（大文本）|
| `Precision` | 数值精度 | `18` |
| `Scale` | 小数位数 | `2` |
| `Nullable` | 允许空 | `False` |
| `DefaultValue` | 默认值 | `0`/`''`/`getdate()` |

### 主键设计约定

| 场景 | 数据类型 | 必填属性 | 说明 |
|------|---------|---------|------|
| 普通表 | `Int32` | `PrimaryKey="True" Identity="True"` | 自增整数 |
| 大数据表 | `Int64` | `PrimaryKey="True" DataScale="time"` | 雪花 ID，不设 Identity |

```xml
<!-- 普通表主键 -->
<Column Name="Id" DataType="Int32" PrimaryKey="True" Identity="True" Description="编号" />

<!-- 大数据表主键（雪花 ID） -->
<Column Name="Id" DataType="Int64" PrimaryKey="True" DataScale="time" Description="编号" />
```

### 主字段（Master）

业务主要字段（通常是名称、编号等，在列表中突出显示）：

```xml
<Column Name="Name" DataType="String" Master="True" Length="50" Nullable="False" Description="名称" />
```

### Map 外键关联

格式：`表名@主键字段@显示字段` 或 `表名@主键@显示字段@属性名`

| 格式 | 说明 | 示例 |
|------|------|------|
| `Table@Id@Name` | 三段（属性名自动推导）| `Role@Id@Name` |
| `Table@Id@Name@RoleName` | 四段（指定属性名）| `Role@Id@Name@RoleName` |
| `NS.Table@Id@Path@AreaPath` | 完整命名空间 | `XCode.Membership.Area@Id@Path@AreaPath` |

```xml
<Column Name="UserId" DataType="Int32" Map="User@Id@Name" Description="用户" />
<Column Name="RoleId" DataType="Int32" Map="Role@Id@Name@RoleName" Description="角色" />
```

### 字段类型（DataType）与 ItemType

`DataType` 决定 C# 属性类型；`ItemType` 用于魔方前端渲染指定 UI 组件：

| ItemType 值 | 用途 |
|------------|------|
| `image` | 图片 URL，预览缩略图 |
| `file` | 文件路径，显示下载链接 |
| `url` | 超链接 |
| `mail` | 电子邮件 |
| `mobile` | 手机号 |
| `html` | 富文本 HTML |
| `code` | 代码块 |
| `json` | JSON 内容 |
| `TimeSpan` | 时间间隔（毫秒转为可读格式）|
| `GMK` | 字节数转为 GB/MB/KB 显示 |

### ShowIn 显示控制

控制字段在各区域（列表/详情/新增/编辑/搜索）的显示。

**区域别名**：`List(L)` / `Detail(D)` / `AddForm(Add/A)` / `EditForm(Edit/E)` / `Search(S)` / `Form(F)`（同时控制 Add 和 Edit）

```xml
<!-- 具名列表语法（推荐） -->
<Column ShowIn="List,Search" ... />        <!-- 仅 List 和 Search 显示 -->
<Column ShowIn="-EditForm,-Detail" ... />  <!-- 编辑表单和详情隐藏 -->
<Column ShowIn="All,-Detail" ... />        <!-- 全部显示，详情隐藏 -->

<!-- 管道分隔语法 -->
<Column ShowIn="Y|Y|N||A" ... />           <!-- List=显示|Detail=显示|Add=隐藏|Edit=自动|Search=自动 -->

<!-- 5字符掩码语法 -->
<Column ShowIn="11110" ... />              <!-- 1=显示, 0=隐藏, A/?/-=自动 -->
```

### DataScale 分表字段

| 值 | 说明 |
|----|------|
| `time` | 大数据单表的时间字段（雪花 ID 内嵌时间）|
| `timeShard:yyMMdd` | 分表字段，按日期格式自动分表 |
| `timeShard:yyyyMM` | 分表字段，按月分表 |

### 其他常用属性

| 属性 | 说明 | 示例 |
|------|------|------|
| `Type` | 枚举类型 | `Zero.Data.OrderStatus` |
| `Category` | 表单分组 | `登录信息`/`扩展` |
| `Model` | 是否包含在模型类中 | `False` |
| `Attribute` | 额外特性 | `XmlIgnore, IgnoreDataMember` |
| `RawType` | 原始数据库类型 | `varchar(50)` |

## Index 属性

| 属性 | 说明 | 示例 |
|------|------|------|
| `Columns` | 索引列（逗号分隔）| `Name`/`Category,CreateTime` |
| `Unique` | 唯一索引 | `True` |

## 自动拦截器扩展字段约定

以下字段由内置拦截器自动填充，**无需业务代码手动赋值**，建议统一设置 `Model="False" Category="扩展"`：

```xml
<Column Name="CreateUser"   DataType="String"   Description="创建者"   Model="False" Category="扩展" />
<Column Name="CreateUserID" DataType="Int32"    Description="创建者"   Model="False" Category="扩展" />
<Column Name="CreateTime"   DataType="DateTime" Description="创建时间" Model="False" Category="扩展" />
<Column Name="CreateIP"     DataType="String"   Description="创建地址" Model="False" Category="扩展" />
<Column Name="UpdateUser"   DataType="String"   Description="更新者"   Model="False" Category="扩展" />
<Column Name="UpdateUserID" DataType="Int32"    Description="更新者"   Model="False" Category="扩展" />
<Column Name="UpdateTime"   DataType="DateTime" Description="更新时间" Model="False" Category="扩展" />
<Column Name="UpdateIP"     DataType="String"   Description="更新地址" Model="False" Category="扩展" />
<Column Name="TraceId"      DataType="String"   Description="链路追踪" Model="False" Category="扩展" />
```

## 完整 Model.xml 示例

```xml
<?xml version="1.0" encoding="utf-8"?>
<EntityModel xmlns:xs="http://www.w3.org/2001/XMLSchema-instance"
             xs:schemaLocation="https://newlifex.com https://newlifex.com/Model202509.xsd"
             xmlns="https://newlifex.com/Model202509.xsd">
  <Option>
    <Namespace>Order.Data</Namespace>
    <ConnName>Order</ConnName>
    <Output>.\</Output>
    <ChineseFileName>True</ChineseFileName>
    <Nullable>True</Nullable>
    <HasIModel>True</HasIModel>
    <DisplayName>订单管理</DisplayName>
    <CubeOutput>../../OrderWeb/Areas/Order</CubeOutput>
  </Option>
  <Tables>
    <Table Name="Order" Description="订单。电商订单主表">
      <Columns>
        <Column Name="Id"          DataType="Int64"    PrimaryKey="True" DataScale="time"        Description="编号" />
        <Column Name="OrderNo"     DataType="String"   Master="True"     Length="50" Nullable="False" Description="订单号" />
        <Column Name="UserId"      DataType="Int32"    Map="User@Id@Name"                         Description="用户" />
        <Column Name="Status"      DataType="Int32"    Type="Order.Data.OrderStatus"              Description="状态" />
        <Column Name="TotalAmount" DataType="Decimal"  Precision="18"    Scale="2"               Description="总金额" />
        <Column Name="Remark"      DataType="String"   Length="500"      Category="扩展"         Description="备注" />
        <Column Name="CreateUser"  DataType="String"   Model="False"     Category="扩展"         Description="创建者" />
        <Column Name="CreateTime"  DataType="DateTime" Nullable="False"  Category="扩展"         Description="创建时间" />
        <Column Name="UpdateTime"  DataType="DateTime" Model="False"     Category="扩展"         Description="更新时间" />
      </Columns>
      <Indexes>
        <Index Columns="OrderNo" Unique="True" />
        <Index Columns="UserId" />
        <Index Columns="Status,CreateTime" />
      </Indexes>
    </Table>
  </Tables>
</EntityModel>
```

## xcode 命令

```powershell
# 在模型文件所在目录执行（自动查找所有 *.xml）
xcode

# 指定模型文件
xcode Model.xml
xcode Order.xml
```

**生成物**：
1. `实体名.cs` — 自动生成的数据映射代码，**每次 xcode 会覆盖，禁止手动修改**
2. `实体名.Biz.cs` — 业务扩展代码，仅首次生成，**可自由修改**
3. `实体名.htm` — 数据字典（字段说明文档）
4. 模型类（配置了 `ModelClass` 时）
5. 接口（配置了 `ModelInterface` 时）
6. 魔方控制器（配置了 `CubeOutput` 时）

## 多模块项目结构

```
Zero.Data/
├── Order/           # 订单模块
│   ├── Order.xml    # 订单模型
│   ├── 订单.cs
│   ├── 订单.Biz.cs
│   └── 订单明细.cs
├── Product/         # 商品模块
│   ├── Product.xml
│   ├── 商品.cs
│   └── 分类.cs
└── Member/          # 会员模块
    ├── Member.xml
    └── 会员.cs
```

每个模块目录内有独立的 `*.xml`，在各自目录执行 `xcode` 生成。

## 数据库连接配置

连接名对应 Model.xml 的 `ConnName`。未配置时，默认创建同名 SQLite 数据库文件。

```json
{
  "ConnectionStrings": {
    "Order": "Server=.;Database=Order;Uid=sa;Pwd=xxx"
  }
}
```

## 反向工程（自动建表）模式

通过 `XCode.json` 或 `appsettings.json` 的 `XCode` 节配置：

| 模式 | 说明 | 适用场景 |
|------|------|---------|
| `Off` | 关闭，不检查不执行 | 生产环境（表结构由 DBA 管理）|
| `ReadOnly` | 只读，检查差异但不执行 DDL | 生产环境排查 |
| `On` | 仅新建表/列（**默认值**）| 开发/测试环境 |
| `Full` | 可修改列类型、删除列/索引 | 开发初期快速迭代 |

```json
{
  "XCode": {
    "Migration": "Off",
    "ShowSQL": false,
    "SQLPath": "../SqlLog",
    "TraceSQLTime": 500
  }
}
```

## 注意事项

- `实体名.cs` 每次执行 `xcode` 会覆盖；字段调整始终在 `Model.xml` 中进行，再重新生成。
- `String` 类型字段必须指定合理的 `Length`；大文本用 `-1`。
- `Master="True"` 最多设置一个字段，作为列表主显示字段。
- 同一个系统的不同模块可使用不同 `ConnName`，分别连接不同数据库。
