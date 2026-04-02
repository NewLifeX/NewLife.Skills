---
name: map-geocoding
description: >
  使用 NewLife.Map 通过统一 IMap 接口调用百度/高德/腾讯/天地图进行地理编码、
  逆地理编码、驾车距离规划，以及 WGS84/GCJ02/BD09 三种坐标系在线/离线转换。
  涵盖 MapFactory 工厂创建、多 AppKey 轮询与自动熔断恢复、MapHelper 离线坐标算法，
  以及通过 Stardust 服务发现接入 NewLifeMap 聚合后端。
  适用于地址解析、LBS 定位、物流配送距离计算、地图展示等场景。
argument-hint: >
  说明你的地图场景：地址→坐标（正向编码），还是坐标→地址（逆向编码）；
  需要哪个地图服务商（百度/高德/腾讯）；是否需要驾车距离；
  是否需要坐标系转换（GPS 设备 WGS84 转百度 BD09 等）；
  是否需要多 Key 轮询。
---

# 地图地理编码技能（NewLife.Map）

## 适用场景

- 将用户输入的中文地址解析为经纬度坐标（正向地理编码）。
- 将 GPS/网络定位的经纬度转换为可读地址（逆向地理编码），如"北京市海淀区中关村大街"。
- 计算两点间驾车时间与距离，用于物流、外卖配送费用估算和 ETA 展示。
- GPS 设备上报 WGS84 坐标，转换为百度（BD09）或高德（GCJ02）以在地图上正确显示。
- 多地图服务商冗余：主服务商配额耗尽时自动切换备用服务商。
- 代码审查：确认坐标系类型使用一致，避免不同系统间坐标偏移。

## 核心原则

1. **所有操作面向 `IMap` 接口**：业务代码只依赖 `IMap`，不直接引用 `BaiduMap` 具体类；通过 DI 或工厂注入，方便切换服务商。
2. **多 AppKey 逗号分隔实现轮询**：`AppKey = "key1,key2,key3"` 后，每次请求递增取余选取 key；某个 key 报错（配额超限/无效）时自动暂时下线，定时恢复，无需人工干预。
3. **坐标系类型必须明确传入**：`GetGeoAsync` 和 `GetReverseGeoAsync` 的 `coordtype` 参数指定返回/输入坐标系；不传则使用各服务商默认坐标系（通常是各自私有系统），导致坐标偏移。
4. **离线坐标转换优先用 `MapHelper`**：WGS84 ↔ GCJ02 ↔ BD09 的数学转换公式内置在 `MapHelper`，零网络请求、零 API 配额消耗；仅在需要 > 100 个点批量精确转换时才用在线 API。
5. **`GetDistanceAsync` 不是直线距离而是驾车路径**：返回的 `Driving.Distance`（米）是实际路线距离，`Duration`（秒）是预估驾车时间；计算直线距离应用 Haversine 公式或 `RedisGeo`。
6. **`NewLifeMap` 需要 Stardust 服务发现**：`NewLifeMap` 客户端通过 Stardust 注册中心发现后端 MapApi 服务地址，适合企业内部统一管理 API Key 的场景；单应用直接调用外部 API 用其他提供者。

## 执行步骤

### 一、创建地图客户端

```csharp
using NewLife.Map;

// 方式 1：直接实例化（最简单）
IMap map = new BaiduMap { AppKey = "你的百度 AK" };
// 高德地图
IMap amap = new AMap { AppKey = "你的高德 Key" };
// 多 Key 轮询（自动熔断）
IMap mapMulti = new BaiduMap { AppKey = "key1,key2,key3" };

// 方式 2：工厂创建
var map = MapFactory.Create(MapKinds.Baidu);
map.AppKey = "你的百度 AK";

// 方式 3：DI 注入
services.AddSingleton<IMap>(_ => new AMap { AppKey = "你的高德 Key" });
// 使用
public class OrderService(IMap map) { }
```

### 二、正向地理编码（地址 → 坐标）

```csharp
// 地址串 → GeoAddress（包含经纬度坐标）
var geo = await map.GetGeoAsync(
    address: "北京市海淀区上地十街10号",
    city: "北京",              // 可选：限制城市提高精度
    coordtype: "bd09ll"        // 返回坐标系：bd09ll=百度坐标
);

if (geo != null)
{
    Console.WriteLine($"经度: {geo.Location.Longitude}");  // 116.3xxx
    Console.WriteLine($"纬度: {geo.Location.Latitude}");   // 40.0xxx
    Console.WriteLine($"地址: {geo.Address}");
    Console.WriteLine($"区域代码: {geo.Code}");            // 行政区划代码
}
```

### 三、逆向地理编码（坐标 → 地址）

```csharp
// GPS 记录的 WGS84 坐标 → 中文地址
var address = await map.GetReverseGeoAsync(
    point: new GeoPoint(116.30815, 40.056885),
    coordtype: "gcj02"   // 输入坐标系类型
);

if (address != null)
{
    Console.WriteLine($"地址: {address.Address}");      // "北京市海淀区..."
    Console.WriteLine($"省份: {address.Province}");     // "北京市"
    Console.WriteLine($"城市: {address.City}");          // "北京市"
    Console.WriteLine($"区县: {address.District}");     // "海淀区"
    Console.WriteLine($"POI: {address.Title}");          // 最近兴趣点名称
}
```

### 四、驾车距离与时间

```csharp
var route = await map.GetDistanceAsync(
    origin:      new GeoPoint(116.30815, 40.056885),     // 起点（公司）
    destination: new GeoPoint(116.39745, 39.909187),     // 终点（客户）
    coordtype:   "bd09ll",
    type:        0   // 0=驾车，可扩展其他出行方式
);

if (route != null)
{
    Console.WriteLine($"距离: {route.Distance / 1000.0:F1} 公里");
    Console.WriteLine($"时间: {route.Duration / 60} 分钟");
}
```

### 五、坐标系转换

```csharp
// 离线转换（无 API 调用，推荐大批量）
var wgs84Point = new GeoPoint(116.3912, 39.9074);  // GPS 坐标（WGS84）

// WGS84 → GCJ02（火星坐标）
var gcj02 = MapHelper.Wgs84ToGcj02(wgs84Point.Longitude, wgs84Point.Latitude);

// GCJ02 → BD09（百度坐标）
var bd09 = MapHelper.Gcj02ToBd09(gcj02.Lng, gcj02.Lat);

// WGS84 → BD09 一步到位
var bd09Direct = MapHelper.Wgs84ToBd09(wgs84Point.Longitude, wgs84Point.Latitude);

// 在线转换（百度 API，适合精度要求高的单点/少量转换）
var points = await map.ConvertAsync(
    new[] { wgs84Point },
    from: "wgs84ll",
    to:   "bd09ll"
);
```

### 六、坐标系类型代码速查

```csharp
// 各服务商 coordtype 参数值
// 百度 BaiduMap
"bd09ll"    // 百度坐标系（默认）
"gcj02ll"   // 火星坐标系
"wgs84ll"   // WGS84 坐标系

// 高德 AMap
"gcj02"     // 高德/火星坐标（默认，驾车/POI 返回此格式）
"wgs84"     // GPS 原始坐标
```

### 七、MapHelper 离线算法

```csharp
using NewLife.Map;

// WGS84（GPS/国际） → GCJ02（高德/腾讯）
var (gcjLng, gcjLat) = MapHelper.Wgs84ToGcj02(116.3912, 39.9074);

// GCJ02（高德/腾讯） → BD09（百度）
var (bdLng, bdLat) = MapHelper.Gcj02ToBd09(gcjLng, gcjLat);

// BD09（百度） → GCJ02
var (gcj2Lng, gcj2Lat) = MapHelper.Bd09ToGcj02(bdLng, bdLat);

// WGS84 → BD09（直接转换）
var (bdLng2, bdLat2) = MapHelper.Wgs84ToBd09(116.3912, 39.9074);
```

### 八、多 Key 轮询与熔断

```csharp
// 配置多个 Key，自动轮询 + 失败自动下线
var map = new BaiduMap
{
    AppKey = "primaryKey,backupKey1,backupKey2",
};

// 当某个 key 因限流/无效报错时：
// 1. 框架自动将该 key 暂时下线（1 小时后自动恢复）
// 2. 下次请求自动切到下一个可用 key
// 3. 全部 key 下线时 Available 属性为 false
if (!map.Available)
{
    throw new Exception("所有 API Key 均不可用，请检查配额或 key 状态");
}
```

## 地图服务商功能对比

| 服务商 | 类名 | 地理编码 | 逆编码 | 驾车距离 | IP定位 | 坐标转换 |
|--------|------|:-------:|:-----:|:-------:|:------:|:-------:|
| 百度地图 | `BaiduMap` | ✓ | ✓ | ✓ | ✓ | ✓(在线) |
| 高德地图 | `AMap` | ✓ | ✓ | ✓ | — | ✓(离线) |
| 腾讯地图 | `WeMap` | ✓ | ✓ | ✓ | — | — |
| 天地图 | `TianDiTu` | ✓ | ✓ | — | — | — |
| 新生命图 | `NewLifeMap` | ※ | ※ | ※ | — | — |

> ※ `NewLifeMap` 通过 Stardust 服务发现调用内部聚合服务

## GeoAddress 主要字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `Location` | `GeoPoint` | 经纬度坐标（Longitude/Latitude） |
| `Address` | `String` | 完整地址字符串 |
| `Province` | `String` | 省份 |
| `City` | `String` | 城市 |
| `District` | `String` | 区县 |
| `Title` | `String` | 附近 POI 名称 |
| `Code` | `String` | 行政区划代码 |
| `Towncode` | `String` | 街道/镇代码 |

## 常见错误与注意事项

- **坐标系混用导致偏移**：GPS 设备输出 WGS84，若不转换直接在百度地图展示会偏移数百米；转换前必须确认输入坐标系。
- **`coordtype` 参数大小写敏感**：百度 API 要求 `bd09ll`（全小写），传 `BD09LL` 会报参数错误。
- **配额超限后不重试同一 Key**：框架检测到 `TOO_FREQUENT`/`LIMIT` 错误后自动下线该 Key；不要在业务层捕获异常后重试，会加速配额耗尽。
- **批量地址解析有 QPS 限制**：百度/高德均有每秒查询上限（个人免费版 30 QPS），批量处理时加 `Task.Delay` 控速，或使用 `NewLifeMap` 聚合后端统一管理。
- **`GetDistanceAsync` type 参数含义因服务商而异**：百度 `type=0` 是驾车，高德也是 `type=0`；具体值含义参考各服务商文档，不要跨服务商假设一致。
