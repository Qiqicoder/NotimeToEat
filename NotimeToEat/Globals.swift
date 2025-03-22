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

// 重新导出模型
typealias FoodItem = Models.FoodItem
typealias Category = Models.Category
typealias Tag = Models.Tag
typealias Receipt = Models.Receipt

// 重新导出管理器
typealias NotificationManager = Services.NotificationManager
typealias FoodStore = Services.FoodStore
// ReceiptManager now exists as a standalone class
// Use standard import to access it

// 声明命名空间
enum Models {}

// 将类型添加到命名空间
extension Models {
    struct FoodItem: Identifiable, Codable {
        var id = UUID()
        var name: String
        var expirationDate: Date
        var category: Category
        var tags: [Tag]
        var addedDate: Date
        var notes: String?
        
        // 计算剩余天数
        var daysRemaining: Int {
            let calendar = Calendar.current
            return calendar.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        }
        
        // 检查是否即将过期（3天内）
        var isExpiringSoon: Bool {
            return daysRemaining >= 0 && daysRemaining <= 3
        }
        
        // 检查是否已过期
        var isExpired: Bool {
            return daysRemaining < 0
        }
    }

    enum Category: String, Codable, CaseIterable {
        case vegetable = "蔬菜"
        case fruit = "水果"
        case meat = "肉类"
        case seafood = "海鲜"
        case dairy = "乳制品"
        case grain = "谷物"
        case condiment = "调味品"
        case beverage = "饮料"
        case snack = "零食"
        case other = "其他"
        
        var iconName: String {
            switch self {
            case .vegetable: return "leaf"
            case .fruit: return "apple.logo"
            case .meat: return "fork.knife"
            case .seafood: return "fish"
            case .dairy: return "cup.and.saucer"
            case .grain: return "bolt"
            case .condiment: return "tuningfork"
            case .beverage: return "mug"
            case .snack: return "birthday.cake"
            case .other: return "questionmark"
            }
        }
    }

    enum Tag: String, Codable, CaseIterable {
        case refrigerated = "需冷藏"
        case frozen = "冷冻"
        case roomTemperature = "常温"
        case favorite = "常用"
        case leftover = "剩菜"
        
        var iconName: String {
            switch self {
            case .refrigerated: return "thermometer.snowflake"
            case .frozen: return "snow"
            case .roomTemperature: return "thermometer"
            case .favorite: return "star.fill"
            case .leftover: return "takeoutbag.and.cup.and.straw"
            }
        }
        
        var color: Color {
            switch self {
            case .refrigerated: return .blue
            case .frozen: return .cyan
            case .roomTemperature: return .orange
            case .favorite: return .yellow
            case .leftover: return .purple
            }
        }
    }

    struct Receipt: Identifiable, Codable {
        var id = UUID()
        var imageID: String
        var foodItemID: UUID?
        var foodItemIDs: [UUID]
        var addedDate: Date
        var ocrText: String?
        var aiAnalysisResult: String?
        
        init(imageID: String, foodItemID: UUID? = nil, foodItemIDs: [UUID] = [], addedDate: Date = Date(), ocrText: String? = nil, aiAnalysisResult: String? = nil) {
            self.imageID = imageID
            self.foodItemID = foodItemID
            self.foodItemIDs = foodItemIDs
            self.addedDate = addedDate
            self.ocrText = ocrText
            self.aiAnalysisResult = aiAnalysisResult
        }
    }
}

// 食物示例数据
extension Models.FoodItem {
    static let sampleItems: [FoodItem] = [
        FoodItem(
            name: "牛奶",
            expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            category: .dairy,
            tags: [.refrigerated],
            addedDate: Date()
        ),
        FoodItem(
            name: "苹果",
            expirationDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            category: .fruit,
            tags: [.refrigerated],
            addedDate: Date()
        ),
        FoodItem(
            name: "鸡肉",
            expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            category: .meat,
            tags: [.frozen],
            addedDate: Date(),
            notes: "周末烧烤用"
        )
    ]
}

// 将服务添加到命名空间
extension Services {
    class NotificationManager: ObservableObject {
        static let shared = NotificationManager()
        
        private init() {}
        
        // 请求通知权限
        func requestAuthorization() {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            UNUserNotificationCenter.current().requestAuthorization(options: options) { success, error in
                if let error = error {
                    print("ERROR: 通知权限请求失败: \(error.localizedDescription)")
                }
                if success {
                    print("通知权限获取成功")
                } else {
                    print("通知权限获取失败")
                }
            }
        }
        
        // 为食品创建过期通知
        func scheduleExpirationNotification(for item: FoodItem) {
            // 取消旧的通知（如果存在）
            cancelNotification(for: item)
            
            // 创建通知内容
            let content = UNMutableNotificationContent()
            content.title = "食物即将过期！"
            content.body = "您的\(item.name)即将过期，请尽快食用。"
            content.sound = .default
            
            // 计算通知时间
            var notificationDate = item.expirationDate
            // 提前一天通知
            notificationDate = Calendar.current.date(byAdding: .day, value: -1, to: notificationDate) ?? notificationDate
            
            // 创建日期组件
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // 创建请求
            let request = UNNotificationRequest(
                identifier: item.id.uuidString,
                content: content,
                trigger: trigger
            )
            
            // 添加通知请求
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("ERROR: 无法安排通知: \(error.localizedDescription)")
                }
            }
        }
        
        // 取消食品的通知
        func cancelNotification(for item: FoodItem) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
        }
        
        // 取消所有通知
        func cancelAllNotifications() {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }

    class FoodStore: ObservableObject {
        @Published var foodItems: [FoodItem] = []
        
        private static func fileURL() throws -> URL {
            try FileManager.default.url(for: .documentDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: false)
                .appendingPathComponent("foodItems.data")
        }
        
        // 从磁盘加载数据
        func load() {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                
                do {
                    let fileURL = try Self.fileURL()
                    guard let data = try? Data(contentsOf: fileURL) else {
                        // 如果文件不存在，使用样本数据
                        DispatchQueue.main.async {
                            self.foodItems = FoodItem.sampleItems
                        }
                        return
                    }
                    
                    let decoder = JSONDecoder()
                    let items = try decoder.decode([FoodItem].self, from: data)
                    
                    DispatchQueue.main.async {
                        self.foodItems = items
                    }
                } catch {
                    print("ERROR: 无法加载食物列表: \(error.localizedDescription)")
                }
            }
        }
        
        // 保存数据到磁盘
        func save() {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                
                do {
                    let data = try JSONEncoder().encode(self.foodItems)
                    let outfile = try Self.fileURL()
                    try data.write(to: outfile)
                } catch {
                    print("ERROR: 无法保存食物列表: \(error.localizedDescription)")
                }
            }
        }
        
        // 添加新食物
        func addFood(_ item: FoodItem) {
            foodItems.append(item)
            save()
            
            // 安排通知
            NotificationManager.shared.scheduleExpirationNotification(for: item)
        }
        
        // 更新现有食物
        func updateFood(_ item: FoodItem) {
            if let index = foodItems.firstIndex(where: { $0.id == item.id }) {
                foodItems[index] = item
                save()
                
                // 更新通知
                NotificationManager.shared.scheduleExpirationNotification(for: item)
            }
        }
        
        // 删除食物
        func deleteFood(_ item: FoodItem) {
            foodItems.removeAll { $0.id == item.id }
            save()
            
            // 取消通知
            NotificationManager.shared.cancelNotification(for: item)
        }
        
        // 按照过期日期排序的食物
        var sortedByExpirationDate: [FoodItem] {
            return foodItems.sorted { $0.expirationDate < $1.expirationDate }
        }
        
        // 即将过期的食物（3天内）
        var expiringSoonItems: [FoodItem] {
            return sortedByExpirationDate.filter { $0.isExpiringSoon }
        }
        
        // 已经过期的食物
        var expiredItems: [FoodItem] {
            return sortedByExpirationDate.filter { $0.isExpired }
        }
        
        // 按分类筛选
        func items(inCategory category: Category) -> [FoodItem] {
            return foodItems.filter { $0.category == category }
        }
        
        // 按标签筛选
        func items(withTag tag: Tag) -> [FoodItem] {
            return foodItems.filter { $0.tags.contains(tag) }
        }
    }

    // ReceiptStore and OCRManager have been moved to ReceiptManager.swift
} 