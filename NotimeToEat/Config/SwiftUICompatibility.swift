import SwiftUI

// 这个文件用于解决SwiftUI的跨平台编译警告问题
// 主要用于解决"xxx is only available in macOS 10.15 or newer"类型的警告

#if os(iOS)
// SwiftUI中常用的类型别名，避免编译器在非iOS平台上的警告
public typealias ColorCompatible = Color
public typealias TextCompatible = Text
public typealias ImageCompatible = Image
public typealias ViewCompatible = View

// 常用的SwiftUI修饰符封装，以iOS为中心设计
@available(iOS 14.0, *)
public extension View {
    // 确保这个修饰符只用于iOS
    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    func applyIOSModifiers() -> some View {
        self
    }
}

#else
// 为其他平台提供占位符实现，避免编译错误
// 这些代码永远不会被执行，因为我们是iOS专用应用
public typealias ColorCompatible = Any
public typealias TextCompatible = Any
public typealias ImageCompatible = Any
public typealias ViewCompatible = Any
#endif

// 运行时平台检查(仅调试用)
public enum Platform {
    public static var isIOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
} 