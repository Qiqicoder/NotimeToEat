# NotimeToEat

一个使用Swift Package Manager管理的iOS应用，帮助用户管理食物和小票。

## 项目结构

该项目已转换为使用Swift Package Manager进行依赖管理：

- `NotimeToEat/`: 主应用程序代码
  - `Models/`: 数据模型
  - `Views/`: SwiftUI视图
  - `Services/`: 服务和管理器
  - `Utilities/`: 工具函数
  - `Resources/`: 资源文件
  - `Config/`: 配置和平台兼容性文件
- `NotimeToEatTests/`: 单元测试
- `NotimeToEatUITests/`: UI测试
- `Package.swift`: Swift Package Manager配置文件

## 重要说明

此应用程序**仅支持iOS 17及以上版本**。虽然在Swift Package Manager配置中我们指定了iOS 15作为最低版本，但应用在运行时会要求iOS 17或更高版本。

## 如何使用

### 打开项目

使用以下方法之一打开项目：

1. 直接在Xcode中打开`Package.swift`文件
2. 在终端中运行`xed .`命令（位于项目根目录）
3. 打开Xcode并选择"File > Open..."，然后选择项目目录

### 添加依赖

要添加新的依赖，编辑`Package.swift`文件：

```swift
dependencies: [
    .package(url: "https://github.com/example/package.git", from: "1.0.0"),
],
```

然后将依赖添加到相应的target中：

```swift
.target(
    name: "NotimeToEat",
    dependencies: ["PackageName"]),
```

### 处理编译警告

如果您在编译时看到类似于`'Color' is only available in macOS 10.15 or newer`的警告，不必担心。这是由于SwiftUI是跨平台框架，而Swift Package Manager在编译时会检查所有平台的兼容性。

我们在`Config/`目录中提供了兼容性文件，帮助解决这些警告：

- `PlatformConfig.swift`: 包含平台特定的类型定义
- `SwiftUICompatibility.swift`: 提供SwiftUI兼容性工具

## 开发指南

请参阅[IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)了解更多实现详情。 