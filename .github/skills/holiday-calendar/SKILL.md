---
name: holiday-calendar
description: >
  使用 NewLife.Holiday 判断中国法定节假日与调休工作日、查询农历日期与生肖节气，
  涵盖 DateTime 扩展方法（IsChinaHoliday/IsGuangxiHoliday）、IHoliday 接口、
  HolidayInfo 详情查询、Lunar 农历结构体与 SolarTerm 二十四节气枚举，
  以及自定义区域假期扩展（继承 ChinaHoliday/IHoliday）。
  适用于工作日/休假判断、薪资计算、业务日历、提醒系统等场景。
argument-hint: >
  说明你的假期需求：判断某日是否为法定假日；还是需要调休详情（放假几天/哪天补班）；
  是否需要广西三月三等地方节假日；是否需要农历转换或节气信息；
  是否需要自定义区域假期。
---

# 中国节假日与农历日历技能（NewLife.Holiday）

## 适用场景

- 薪资系统判断某日是否为工作日、法定节假日或调休补班日。
- 业务系统在节假日自动切换服务策略（如电商大促、节日提醒）。
- 物流、快递系统计算有效运营日（排除节假日）。
- 需要展示农历日期、生肖、天干地支、二十四节气的日历/日程应用。
- 广西等有地方特色节假日（农历三月三）的业务系统。

## 核心原则

1. **零配置自动加载**：库使用嵌入式 CSV 资源文件，构造时自动加载，无需显式初始化或配置文件；直接引入 NuGet 包即可使用扩展方法。
2. **`IsChinaHoliday()` 含双休日判断**：返回 `true` 表示"不用上班"——既包括法定节假日，也包括普通週六/日；调休工作日（`HolidayStatus.Off`）返回 `false`，即"需要上班"。
3. **调休补班要单独查询**：`IsChinaHoliday()` 只返回 bool；要知道某天是"放假几天"还是"调休上班"，应用 `IHoliday.Query(date)` 取 `HolidayInfo` 列表，检查 `HolidayStatus.Off`。
4. **数据覆盖范围 2020–2026 年**：超出此范围的日期仅能按周末规则判断，无法识别法定节假日和调休安排；数据按年度更新，使用前确认已引用最新 NuGet 版本。
5. **`Lunar` 是 readonly struct，不可为 null**：`Lunar.FromDateTime(date)` 始终返回有效值；年份范围 1901–2100；不要与 `DateTime.MinValue` 混用。
6. **地方节假日通过继承扩展**：广西三月三等地方节假日由 `GuangxiHoliday` 提供；自定义区域假期继承 `ChinaHoliday` 并重写相关逻辑，保留全国假期基础。

## 执行步骤

### 一、判断是否为节假日（最简用法）

```csharp
using NewLife.Holiday;

// 是否为节假日（含周末，但调休工作日返回 false）
var date = new DateTime(2024, 2, 10);   // 2024 年春节
if (date.IsChinaHoliday())
{
    Console.WriteLine("今天放假");
}

// 是否为工作日（包含调休补班）
var isWorkday = !date.IsChinaHoliday();

// 广西三月三额外假期
var guangxiDate = new DateTime(2024, 4, 11);  // 2024 年农历三月三
if (guangxiDate.IsGuangxiHoliday())
{
    Console.WriteLine("广西三月三放假");
}
```

### 二、查询假期详情

```csharp
// 查询指定日期的假期详情列表
var holidays = HolidayExtensions.China.Query(new DateTime(2024, 2, 10));
foreach (var h in holidays)
{
    // h.Name    = "春节"
    // h.Date    = 2024/2/10
    // h.Days    = 8  （本次假期总天数）
    // h.Status  = HolidayStatus.On（放假） / HolidayStatus.Off（调休补班）
    Console.WriteLine($"{h.Name}: 共{h.Days}天, 状态:{h.Status}");
}

// 检查是否为调休补班日
var compDays = HolidayExtensions.China.Query(new DateTime(2024, 2, 4));
var isCompensation = compDays.Any(h => h.Status == HolidayStatus.Off);
Console.WriteLine($"2024-02-04 是调休补班日: {isCompensation}");  // true（春节前调休）
```

### 三、农历转换

```csharp
// DateTime → 农历
var lunar = Lunar.FromDateTime(new DateTime(2024, 2, 10));

Console.WriteLine($"农历月份: {lunar.MonthText}");    // "正月"
Console.WriteLine($"农历日期: {lunar.DayText}");     // "初一"
Console.WriteLine($"生肖:     {lunar.Zodiac}");       // "龙"
Console.WriteLine($"天干地支: {lunar.YearGanzhi}");  // "甲辰"
Console.WriteLine($"闰月:     {lunar.IsLeapMonth}"); // false

// 组合显示
Console.WriteLine($"{lunar.YearGanzhi}年 {lunar.MonthText}{lunar.DayText}");
// 输出："甲辰年 正月初一"
```

### 四、二十四节气

```csharp
// SolarTerm 枚举（从小寒开始）
var term = SolarTerm.QingMing;   // 清明

// 通过 HolidayInfo.Category 区分节气与假期
var infos = HolidayExtensions.China.Query(new DateTime(2024, 4, 4));
var qingming = infos.FirstOrDefault(h => h.Name == "清明节");
Console.WriteLine($"清明节: {qingming?.Status}");  // On（法定假日）
```

### 五、计算区间内的工作日天数

```csharp
// 统计 2024 年 2 月有多少个工作日
var start  = new DateTime(2024, 2, 1);
var end    = new DateTime(2024, 2, 29);
var workdays = Enumerable.Range(0, (end - start).Days + 1)
    .Select(i => start.AddDays(i))
    .Count(d => !d.IsChinaHoliday());
Console.WriteLine($"2024 年 2 月工作日: {workdays} 天");
```

### 六、自定义区域假期

```csharp
// 继承 ChinaHoliday，添加企业内部假期
public class CompanyHoliday : ChinaHoliday
{
    protected override IEnumerable<HolidayInfo> GetExtraHolidays(DateTime date)
    {
        // 公司年会日（每年 1 月 15 日）
        if (date.Month == 1 && date.Day == 15)
        {
            yield return new HolidayInfo
            {
                Name     = "公司年会",
                Date     = date,
                Days     = 1,
                Status   = HolidayStatus.On,
                Category = "Company",
            };
        }
    }
}

// 注册为 DI 服务
services.AddSingleton<IHoliday, CompanyHoliday>();
```

## HolidayInfo 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `Name` | `String` | 假期名称，如"春节"、"国庆节" |
| `Category` | `String` | 来源分类："China" / "Guangxi" / 自定义 |
| `Date` | `DateTime` | 假期起始日期 |
| `Days` | `Int32` | 本次假期总天数（从 Date 起连续） |
| `Status` | `HolidayStatus` | `On`=放假，`Off`=调休补班，`Normal`=普通工作日 |

## Lunar（农历）属性速查

| 属性 | 类型 | 示例 |
|------|------|------|
| `Year` | `Int32` | 2024 |
| `Month` | `Int32` | 1（正月）|
| `Day` | `Int32` | 1（初一）|
| `IsLeapMonth` | `Boolean` | false |
| `MonthText` | `String` | "正月" |
| `DayText` | `String` | "初一" |
| `Zodiac` | `String` | "龙" |
| `YearGanzhi` | `String` | "甲辰" |

## 常见错误与注意事项

- **误用 `IsChinaHoliday()` 代替"非法定节假日"**：返回 true 包含普通周末；要判断"仅法定节假日"需检查 `Query()` 结果的 `Category` 和 `Status`。
- **忽略调休补班日**：`IsChinaHoliday()` 的调休补班日返回 `false`（需要上班），依赖此方法计算工资时不要漏判。
- **超出数据年份范围**：2020 年前或 2026 年后的日期只能按普通周末规则判断，法定节假日和调休无法识别。
- **`Lunar.FromDateTime` 不抛异常**：日期超出范围时返回默认（零值）结构体而非 null，应检查 `Year > 0` 进行有效性验证。
