# NewLife.Core IoC 容器模式证据

> 来源：`Model/ObjectContainer.cs`（UTF-8，编码正常）+ `Doc/对象容器ObjectContainer.md`（GBK 编码损坏）
> 以源码为准。

---

## 1. 核心类层次（源码校验）

```text
IObjectContainer
├── Services: IList<IObject>
├── Add(IObject)
├── TryAdd(IObject) → Boolean
├── Register(serviceType, implType, instance)  [Obsolete，隐藏]
└── 扩展方法：AddSingleton, AddTransient, AddScoped, GetService<T>, GetRequiredService<T>

ObjectContainer : IObjectContainer
├── static Current: IObjectContainer
├── static Provider: IServiceProvider
├── static SetInnerProvider(IServiceProvider)
└── static SetInnerProvider(Func<IServiceProvider>)

ServiceDescriptor : IObject
├── ServiceType: Type
├── ImplementationType: Type?
├── Lifetime: ObjectLifetime
├── Instance: Object?
└── Factory: Func<IServiceProvider, Object>?

ObjectLifetime { Singleton=0, Scoped=1, Transient=2 }
```

---

## 2. 静态构造器初始化顺序（源码）

```csharp
static ObjectContainer()
{
    var ioc = new ObjectContainer();
    Current = ioc;
    Provider = ioc.BuildServiceProvider();  // 早期阶段创建临时提供者
}
```

> **关键**：`BuildServiceProvider()` 在静态构造阶段就被调用，因此早于任何 `AddSingleton/TryAdd` 注册。这意味着应用启动时要先注册再构建，或使用 `SetInnerProvider` 桥接完整 DI。

---

## 3. `TryAdd` vs `Add` 语义差异（源码）

```csharp
// TryAdd：检查 ServiceType 是否已存在，存在则跳过
public Boolean TryAdd(IObject item)
{
    lock (_list)
    {
        if (_list.Any(e => e.ServiceType == item.ServiceType)) return false;
        _list.Add(item);
        return true;
    }
}

// Add：无论如何都加入列表（允许同类型多实现）
public void Add(IObject item) { lock (_list) { _list.Add(item); } }
```

> 库代码用 `TryAdd` 注册默认实现（可被应用覆盖）；`IHostedService` 等多实现接口用 `Add` 多次注册。

---

## 4. SetInnerProvider 两阶段集成（源码注释）

```csharp
// 阶段1（AddXxx 时）：延迟绑定，延迟到需要时才初始化真正的 IServiceProvider
static void SetInnerProvider(Func<IServiceProvider> factory);

// 阶段2（UseXxx / app.Build() 后）：立即替换为已就绪的 IServiceProvider
static void SetInnerProvider(IServiceProvider innerServiceProvider);
```

> 两阶段设计是为了适配 ASP.NET Core 的"先注册后构建"流程：注册阶段无法拿到 `app.Services`，所以先提供工厂；`Configure` 阶段已有 `app.ApplicationServices` 后再更新为实例。

---

## 5. GlobalEnvironment 与构造函数自动注入（文档节选）

```csharp
// ObjectContainer 自动分析构造函数，选择所有参数均已注册的重载
ioc.AddTransient<IUserService, UserService>();
// UserService(ILog log, ICache cache) → 若 ILog/ICache 都已注册，自动注入
```

若构造函数有无法自动解析的参数，用工厂委托：

```csharp
ioc.AddTransient<IUserService>(sp =>
    new UserService(sp.GetRequiredService<ILog>(), customArg: 42));
```

---

## 6. 通用规则 vs NewLife.Core 特例

| 规则 | 通用性 | 说明 |
|------|--------|------|
| Singleton/Transient/Scoped 三生命周期 | ✅ 通用 | 与 MS DI 完全对齐 |
| `IServiceProvider` 标准兼容 | ✅ 通用 | 可直接替换 MS DI |
| `TryAdd` 保护默认注册 | ✅ 通用 | MS DI 中 `TryAdd` 扩展方法语义相同 |
| `ObjectContainer.Current` 全局静态 | ⚠️ NewLife 特有 | 通用替代：通过 DI 传递 `IServiceProvider` |
| `SetInnerProvider` 两阶段桥接 | ⚠️ NewLife 特有 | 适配 ASP.NET Core 的特有集成模式 |
| 构造函数自动选择最优重载 | ⚠️ 行为特有 | MS DI 也支持，但错误消息不同 |
