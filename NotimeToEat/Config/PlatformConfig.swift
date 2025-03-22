import Foundation
import SwiftUI

// iOS应用专用标记
// 这个文件定义了必要的条件编译指令和兼容性工具

#if os(iOS)
// 使用iOS特定的类型和API
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor

// 添加macOS兼容性检查
#else
// 这些代码永远不会执行，因为我们只针对iOS平台
// 但这样可以防止编译错误
public typealias PlatformImage = Any
public typealias PlatformColor = Any
#endif

// MARK: - iOS版本要求

public struct PlatformCompatibility {
    
    // SwiftUI版本兼容性处理
    @available(iOS 14.0, *)
    @available(macOS, unavailable)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public static func setupUICompatibility() {
        // 此函数无实际内容，仅用于标记
        // 通过添加@available标记，告诉编译器我们的代码只支持iOS
    }
}

// MARK: - 全局SwiftUI条件编译助手

#if DEBUG
public func isIOSOnly() -> Bool {
    #if os(iOS)
    return true
    #else
    return false
    #endif
}
#endif 