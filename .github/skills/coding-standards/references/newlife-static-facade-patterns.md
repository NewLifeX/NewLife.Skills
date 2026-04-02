# 静态门面模式（Static Facade）

## 适用场景

当一组算法或服务需要以扩展方法的形式暴露给调用方，同时又需要允许全局替换核心实现（测试、框架桥接、自定义扩展）时，使用"静态门面 + 可替换实现"模式。

## 模式结构

```
Utility（静态门面）
  └─ Convert（可替换实现，DefaultConvert 实例）
       └─ ToInt / ToDateTime / ...（虚方法，可重写）

扩展方法 obj.ToInt() 调用 Utility.Convert.ToInt(obj, 0)
```

### 参考实现：Utility.Convert（NewLife.Core）

```csharp
public static class Utility
{
    /// <summary>类型转换提供者，可全局替换为自定义实现</summary>
    public static DefaultConvert Convert { get; set; } = new DefaultConvert();
}

// 扩展方法委托给可替换实现
public static Int32 ToInt(this Object? value, Int32 defaultValue = 0)
    => Utility.Convert.ToInt(value, defaultValue);
```

### 替换实现（测试 / 框架适配）

```csharp
public class MyConvert : DefaultConvert
{
    public override Int32 ToInt(Object? value, Int32 defaultValue)
    {
        if (value is MyCustomType mct)
            return mct.Value;
        return base.ToInt(value, defaultValue);
    }
}

// 启动时全局替换
Utility.Convert = new MyConvert();
```

## 设计规则

| 规则 | 说明 |
|------|------|
| 静态门面仅做委托 | `Utility` 静态类本身不含业务逻辑，全部委托给 `Convert` 实例 |
| 实现类使用虚方法 | `DefaultConvert` 的所有方法均为 `virtual`，子类可按需重写 |
| 默认实现开箱即用 | `DefaultConvert` 覆盖常见场景，不替换时也能正常使用 |
| 替换发生在启动阶段 | 仅在应用启动时替换一次，不在运行时动态切换 |
| 扩展方法保持稳定 | 扩展方法签名不依赖具体实现，保证调用侧不感知切换 |

## 与 IoC 注入的区别

| 对比点 | 静态门面 | IoC 注入 |
|--------|---------|---------|
| 调用方式 | `obj.ToInt()` 直接调用 | 需要注入依赖 |
| 适用场景 | 无上下文的纯工具方法 | 有生命周期、依赖图的服务 |
| 替换成本 | 一行代码全局替换 | 注册时替换，需容器 |
| 测试 | 全局替换后所有测试受影响 | 每个测试独立注入 |

> **最佳实践**：纯工具方法（类型转换、字符串处理、哈希计算等）优先用静态门面；有状态的服务（日志、缓存、配置）优先用 IoC 注入。

## NewLife.Core 中的其他静态门面

| 门面 | 可替换实现 | 用途 |
|------|-----------|------|
| `Utility.Convert` | `DefaultConvert` | 类型转换 |
| `XTrace.Log` | `ILog` | 全局日志输出 |
| `ObjectContainer.Current` | `IObjectMapper` | IoC 容器访问 |

## 来源

- `D:\X\NewLife.Core\Doc\类型转换Utility.md`
- `D:\X\NewLife.Core\NewLife.Core\Common\Utility.cs`
