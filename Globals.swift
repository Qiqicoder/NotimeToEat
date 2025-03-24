import SwiftUI
import Foundation
import UserNotifications
import PhotosUI
import Vision

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// 此文件在项目中导入常用类型，简化跨文件导入

// Need to ensure Services namespace is defined before using it
enum Services {}

// 重新导出模型
typealias FoodItem = Models.FoodItem
typealias Category = Models.Category
typealias Tag = Models.Tag
typealias Receipt = Models.Receipt
typealias ShoppingItem = Models.ShoppingItem
typealias FoodHistoryEntry = Models.FoodHistoryEntry
typealias FoodDisposalType = Models.FoodDisposalType

// 重新导出管理器
typealias NotificationManager = Services.NotificationManager
typealias FoodStore = Services.FoodStore
typealias ShoppingListStore = Services.ShoppingListStore
typealias FoodHistoryStore = Services.FoodHistoryStore
// ReceiptManager now exists as a standalone class
// Use standard import to access it

// 声明命名空间
enum Models {}

// 将类型添加到命名空间 