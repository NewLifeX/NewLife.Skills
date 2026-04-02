---
name: dependency-injection-ioc
description: >
  使用 NewLife.Core 内置轻量级 IoC 容器（ObjectContainer）进行依赖注入，
  涵盖服务生命周期注册（Singleton/Transient/Scoped）、全局工厂访问、
  工厂委托注册、Add vs TryAdd 语义，以及与 ASP.NET Core DI 的两阶段集成。
  适用于应用启动配置、跨组件解耦、IoC 容器桥接与代码审查任务。
argument-hint: >
  说明你的 DI 场景：纯控制台/Worker 应用还是 ASP.NET Core；
  需要用 AddSingleton/AddTransient/AddScoped；是否需要工厂委托注册；
  是否要与 ASP.NET Core 内置 DI 容器联动（SetInnerProvider）。
---

# 依赖注入与 IoC 容器技能

## 适用场景

- 新建应用需要简单的 DI，不想依赖 ASP.NET Core 的完整 DI 框架。
- 库或组件注册自身服务到全局容器（`ObjectContainer.Current`），供宿主应用解析。
- 在 ASP.NET Core 应用中，需要将 `ObjectContainer` 与内置容器桥接，使两套容器共享注册。
- 代码审查：确认服务生命周期选择恰当，避免 Scoped 服务注入 Singleton，避免 `new` 代替注入。

## 核心原则

1. **全局容器唯一入口**：`ObjectContainer.Current`（注册时使用）和 `ObjectContainer.Provider`（解析时使用）是应用级全局单例，库代码通过它们读写服务，不传递容器实例。
2. **`TryAdd` vs `Add` 语义差异**：`TryAdd` 仅在该服务类型尚未注册时才添加（库代码注册默认实现用此模式）；`Add` 允许同类型重复注册（同一类型多实例场景，如多个 `IHostedService`）。
3. **生命周期选择**：`Singleton` 共享全程；`Transient` 每次都 `new`；`Scoped` 仅在 Web 场景每请求共享——纯控制台应用一般不需要 Scoped。
4. **构造函数自动注入**：`ObjectContainer` 会自动分析构造函数参数，选择所有参数都已注册的重载；若构造函数有未注册参数，请用工厂委托手动提供。
5. **两阶段初始化（ASP.NET Core）**：`ObjectContainer.Current` 先注册，应用构建后用 `SetInnerProvider(app.Services)` 桥接，之后 `ObjectContainer.Provider` 的解析请求会委托给真正的 `IServiceProvider`。

## 执行步骤

### 一、基础注册与解析

```csharp
var ioc = ObjectContainer.Current;

// Singleton：整个应用生命周期只有一个实例
ioc.AddSingleton<IAppConfig, AppConfig>();

// Transient：每次 GetService 都创建新实例
ioc.AddTransient<IUserService, UserService>();

// 注册已有实例（常用于配置对象）
ioc.AddSingleton<DatabaseOptions>(new DatabaseOptions { ConnStr = "..." });

// 解析
var config = ObjectContainer.Provider.GetService<IAppConfig>();
var userSvc = ObjectContainer.Provider.GetRequiredService<IUserService>();
```

### 二、工厂委托注册

```csharp
// 需要在创建时访问其他服务时，使用工厂委托
ioc.AddSingleton<IDbConnectionFactory>(sp =>
{
    var opts = sp.GetRequiredService<DatabaseOptions>();
    return new SqlConnectionFactory(opts.ConnStr);
});

// Transient 工厂
ioc.AddTransient<ICommand>(sp =>
{
    var log = sp.GetRequiredService<ILog>();
    return new SyncCommand(log, retryCount: 3);
});
```

### 三、TryAdd 保护默认实现

```csharp
// 库代码：只在用户未手动注册时提供默认实现
ioc.TryAddSingleton<ITracer, DefaultTracer>();
ioc.TryAddSingleton<ICache, MemoryCache>();

// 应用代码可覆盖：调用时机必须在库注册之前，或在 TryAdd 之后用 Add 覆盖
ioc.AddSingleton<ITracer>(myCustomTracer);  // Add 不受保护，直接追加
```

### 四、多实现注册（如 IHostedService）

```csharp
// Add（而非 TryAdd）可以为同一接口注册多个实现
ioc.Add(new ServiceDescriptor(typeof(IHostedService), typeof(MetricsService), ObjectLifetime.Singleton));
ioc.Add(new ServiceDescriptor(typeof(IHostedService), typeof(CleanupService), ObjectLifetime.Singleton));

// 解析：GetServices<T>（扩展方法）返回所有注册实现
var services = ObjectContainer.Provider.GetServices<IHostedService>();
```

### 五、ASP.NET Core 双容器桥接

```csharp
// Program.cs — 注册阶段（AddXxx 时）
var ioc = ObjectContainer.Current;
ioc.AddSingleton<ICustomService, CustomService>();  // 注册到 NewLife 容器

// 也可以将 IServiceCollection 委托到 ObjectContainer
builder.Services.AddFromObjectContainer(ioc);  // 若有此扩展

// 构建完成后，桥接到 ASP.NET Core 内置 DI
var app = builder.Build();
ObjectContainer.SetInnerProvider(app.Services);

// 之后 ObjectContainer.Provider.GetService<T>()
// 会先查 NewLife 自身，再查 app.Services（内部提供者）
```

### 六、Scoped 作用域（Web 请求）

```csharp
// 注册 Scoped
ioc.AddScoped<IDbContext, AppDbContext>();

// 在中间件中手动创建作用域（若不用 IServiceScopeFactory 自动处理）
using var scope = ObjectContainer.Provider.CreateScope();
var dbCtx = scope.ServiceProvider.GetRequiredService<IDbContext>();
await dbCtx.SaveChangesAsync();
// scope.Dispose() → dbCtx 被释放
```

## 重点检查项

- [ ] Scoped 服务是否被注入到 Singleton 服务中（捕获依赖问题，导致 Scoped 退化为 Singleton）？
- [ ] 库代码是否使用 `TryAdd` 而非 `Add` 注册默认实现（避免覆盖用户自定义）？
- [ ] `GetRequiredService` 在服务未注册时会抛出，是否有意料外的 `InvalidOperationException`？
- [ ] `SetInnerProvider` 是否在 `app.Build()` 之后调用，而不是在注册阶段？
- [ ] Transient 服务实现了 `IDisposable` 时，是否由容器在正确时机释放（还是泄漏）？
- [ ] 是否有绕过 DI 直接 `new` 服务实例的代码，导致其依赖未被注入？

## 输出要求

- **接口**：`IObjectContainer`（注册 API）、`IServiceProvider`（解析 API，标准兼容）、`IObject`/`ServiceDescriptor`（注册元数据）。
- **生命周期**：`ObjectLifetime.Singleton/Transient/Scoped` 枚举。
- **全局入口**：`ObjectContainer.Current`（注册）、`ObjectContainer.Provider`（解析）。
- **扩展方法**：`AddSingleton<T,TImpl>()`/`AddTransient<T,TImpl>()`/`AddScoped<T,TImpl>()`（流式 API）。
- **测试**：测试时可为每个测试用例创建独立 `new ObjectContainer()`，避免全局状态污染。

## 参考资料

参考示例与模式证据见 `references/newlife-ioc-patterns.md`。
