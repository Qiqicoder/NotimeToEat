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
        case vegetable = "vegetable"
        case fruit = "fruit"
        case meat = "meat"
        case seafood = "seafood"
        case dairy = "dairy"
        case grain = "grain"
        case condiment = "condiment"
        case beverage = "beverage"
        case snack = "snack"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .vegetable: return NSLocalizedString("category_vegetable", comment: "")
            case .fruit: return NSLocalizedString("category_fruit", comment: "")
            case .meat: return NSLocalizedString("category_meat", comment: "")
            case .seafood: return NSLocalizedString("category_seafood", comment: "")
            case .dairy: return NSLocalizedString("category_dairy", comment: "")
            case .grain: return NSLocalizedString("category_grain", comment: "")
            case .condiment: return NSLocalizedString("category_condiment", comment: "")
            case .beverage: return NSLocalizedString("category_beverage", comment: "")
            case .snack: return NSLocalizedString("category_snack", comment: "")
            case .other: return NSLocalizedString("category_other", comment: "")
            }
        }
        
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
        case refrigerated = "refrigerated"
        case frozen = "frozen"
        case roomTemperature = "roomTemperature"
        case favorite = "favorite"
        case leftover = "leftover"
        
        var displayName: String {
            switch self {
            case .refrigerated: return NSLocalizedString("tag_refrigerated", comment: "")
            case .frozen: return NSLocalizedString("tag_frozen", comment: "")
            case .roomTemperature: return NSLocalizedString("tag_room_temperature", comment: "")
            case .favorite: return NSLocalizedString("tag_favorite", comment: "")
            case .leftover: return NSLocalizedString("tag_leftover", comment: "")
            }
        }
        
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
    
    // 购物清单项目
    struct ShoppingItem: Identifiable, Codable {
        var id = UUID()
        var name: String
        var category: Category
        var addedDate: Date
        var isPurchased: Bool
        var notes: String?
        
        init(name: String, category: Category = .other, addedDate: Date = Date(), isPurchased: Bool = false, notes: String? = nil) {
            self.name = name
            self.category = category
            self.addedDate = addedDate
            self.isPurchased = isPurchased
            self.notes = notes
        }
        
        init(id: UUID, name: String, category: Category = .other, addedDate: Date = Date(), isPurchased: Bool = false, notes: String? = nil) {
            self.id = id
            self.name = name
            self.category = category
            self.addedDate = addedDate
            self.isPurchased = isPurchased
            self.notes = notes
        }
    }

    // 食物处理方式
    enum FoodDisposalType: String, Codable {
        case consumed = "consumed"
        case wasted = "wasted"
        
        var displayName: String {
            switch self {
            case .consumed: return NSLocalizedString("status_consumed", comment: "")
            case .wasted: return NSLocalizedString("status_wasted", comment: "")
            }
        }
    }
    
    // 食物历史记录条目
    struct FoodHistoryEntry: Identifiable, Codable {
        var id = UUID()
        var foodName: String
        var category: Category
        var disposalType: FoodDisposalType
        var disposalDate: Date
        
        init(foodName: String, category: Category, disposalType: FoodDisposalType, disposalDate: Date = Date()) {
            self.foodName = foodName
            self.category = category
            self.disposalType = disposalType
            self.disposalDate = disposalDate
        }
    }
}

// 食物示例数据
extension Models.FoodItem {
    static let sampleItems: [FoodItem] = [
        FoodItem(
            name: NSLocalizedString("sample_food_milk", comment: ""),
            expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            category: .dairy,
            tags: [.refrigerated],
            addedDate: Date()
        ),
        FoodItem(
            name: NSLocalizedString("sample_food_apple", comment: ""),
            expirationDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            category: .fruit,
            tags: [.refrigerated],
            addedDate: Date()
        ),
        FoodItem(
            name: NSLocalizedString("sample_food_chicken", comment: ""),
            expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            category: .meat,
            tags: [.frozen],
            addedDate: Date(),
            notes: NSLocalizedString("sample_food_note", comment: "")
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
                    print(NSLocalizedString("notification_permission_success", comment: ""))
                } else {
                    print(NSLocalizedString("notification_permission_failed", comment: ""))
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
                identifier: "food-expiration-\(item.id)",
                content: content,
                trigger: trigger
            )
            
            // 添加通知
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("ERROR: 添加通知失败: \(error.localizedDescription)")
                }
            }
        }
        
        // 取消食品的通知
        func cancelNotification(for item: FoodItem) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["food-expiration-\(item.id)"])
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
            
            // 自动同步到云端
            syncToCloudIfLoggedIn()
        }
        
        // 更新现有食物
        func updateFood(_ item: FoodItem) {
            if let index = foodItems.firstIndex(where: { $0.id == item.id }) {
                foodItems[index] = item
                save()
                
                // 更新通知
                NotificationManager.shared.scheduleExpirationNotification(for: item)
                
                // 自动同步到云端
                syncToCloudIfLoggedIn()
            }
        }
        
        // 删除食物
        func deleteFood(_ item: FoodItem) {
            foodItems.removeAll { $0.id == item.id }
            save()
            
            // 取消通知
            NotificationManager.shared.cancelNotification(for: item)
            
            // 如果已登录，从云端删除该食物项
            if AuthService.shared.isAuthenticated {
                FirestoreService.shared.deleteFoodItem(withID: item.id) { success, error in
                    if success {
                        print("成功从云端删除食物: \(item.name)")
                    } else if let error = error {
                        print("从云端删除食物失败: \(error.localizedDescription)")
                    }
                }
            }
            
            // 自动同步到云端 - 已经单独删除了，不需要再次同步
            // syncToCloudIfLoggedIn()
        }
        
        // 如果用户已登录，自动同步到云端
        private func syncToCloudIfLoggedIn() {
            // 检查用户是否已登录
            if AuthService.shared.isAuthenticated {
                syncToCloud { success, error in
                    if success {
                        print("自动同步食物列表到云端成功")
                    } else if let error = error {
                        print("自动同步食物列表到云端失败: \(error.localizedDescription)")
                    }
                }
            } else {
                print("用户未登录，跳过自动同步")
            }
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

        // 删除食物，并记录处理方式
        func disposeFoodItem(_ item: FoodItem, disposalType: FoodDisposalType, historyStore: FoodHistoryStore) {
            // 记录到历史
            historyStore.addEntryFromFood(item, disposalType: disposalType)
            
            // 删除食物
            deleteFood(item)
        }

        // MARK: - 云端同步功能
        
        /// 将食物数据同步到Firestore
        /// - Parameter completion: 完成回调
        func syncToCloud(completion: @escaping (Bool, Error?) -> Void) {
            // 首先上传本地食物项目
            FirestoreService.shared.uploadFoodItems(foodItems) { [weak self] success, error in
                guard let self = self else {
                    completion(false, nil)
                    return
                }
                
                if !success {
                    if let error = error {
                        print("同步到云端失败: \(error.localizedDescription)")
                    }
                    completion(false, error)
                    return
                }
                
                print("成功将\(self.foodItems.count)个食物项目同步到云端")
                
                // 然后同步删除操作 - 删除云端存在但本地已删除的项目
                let localItemIDs = Set(self.foodItems.map { $0.id })
                FirestoreService.shared.syncDeletedItems(localItemIDs: localItemIDs) { deleteSuccess, deleteError in
                    if deleteSuccess {
                        print("成功同步删除操作到云端")
                    } else if let deleteError = deleteError {
                        print("同步删除操作到云端失败: \(deleteError.localizedDescription)")
                    }
                    
                    // 无论删除同步是否成功，都返回上传的结果
                    // 因为主要功能是确保本地数据已上传
                    completion(success, error)
                }
            }
        }
        
        /// 从Firestore获取数据并合并到本地
        /// - Parameter completion: 完成回调
        func fetchFromCloud(completion: @escaping (Bool, Error?) -> Void) {
            FirestoreService.shared.fetchFoodItems { [weak self] cloudItems, error in
                guard let self = self else { 
                    completion(false, nil)
                    return 
                }
                
                if let error = error {
                    print("从云端获取数据失败: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }
                
                if let cloudItems = cloudItems {
                    // 合并云端和本地数据
                    let mergedItems = FirestoreService.shared.mergeFoodItems(
                        localItems: self.foodItems,
                        cloudItems: cloudItems
                    )
                    
                    // 更新本地数据
                    DispatchQueue.main.async {
                        self.foodItems = mergedItems
                        self.save()
                        completion(true, nil)
                    }
                } else {
                    completion(false, nil)
                }
            }
        }
        
        /// 登录时的完全双向同步（保留本地和云端的所有数据）
        /// - Parameter completion: 完成回调
        func syncOnLogin(completion: @escaping (Bool, Error?) -> Void) {
            // 1. 先获取云端数据
            FirestoreService.shared.fetchFoodItems { [weak self] cloudItems, error in
                guard let self = self else { 
                    completion(false, nil)
                    return 
                }
                
                if let error = error {
                    print("登录同步: 从云端获取数据失败: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }
                
                var mergedItems = self.foodItems
                
                // 2. 合并云端数据到本地
                if let cloudItems = cloudItems, !cloudItems.isEmpty {
                    // 合并云端和本地数据
                    mergedItems = FirestoreService.shared.mergeFoodItems(
                        localItems: self.foodItems,
                        cloudItems: cloudItems
                    )
                    
                    // 更新本地数据
                    DispatchQueue.main.async {
                        self.foodItems = mergedItems
                        self.save()
                    }
                    
                    print("登录同步: 已合并 \(cloudItems.count) 个云端食物项目")
                }
                
                // 3. 将合并后的完整数据上传到云端，但不同步删除（保留所有数据）
                FirestoreService.shared.uploadFoodItems(mergedItems) { success, uploadError in
                    if success {
                        print("登录同步: 成功将 \(mergedItems.count) 个合并后的食物项目上传到云端")
                        completion(true, nil)
                    } else {
                        if let uploadError = uploadError {
                            print("登录同步: 上传合并数据失败: \(uploadError.localizedDescription)")
                        }
                        completion(false, uploadError)
                    }
                }
            }
        }
        
        /// 清空本地数据
        func clearLocalData() {
            foodItems.removeAll()
            save()
            
            // 取消所有通知
            NotificationManager.shared.cancelAllNotifications()
        }
    }

    class ShoppingListStore: ObservableObject {
        @Published var shoppingItems: [ShoppingItem] = []
        
        private static func fileURL() throws -> URL {
            try FileManager.default.url(for: .documentDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: false)
                .appendingPathComponent("shoppingItems.data")
        }
        
        // 从磁盘加载数据
        func load() {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                
                do {
                    let fileURL = try Self.fileURL()
                    guard let data = try? Data(contentsOf: fileURL) else {
                        // 如果文件不存在，使用空数组
                        DispatchQueue.main.async {
                            self.shoppingItems = []
                        }
                        return
                    }
                    
                    let decoder = JSONDecoder()
                    let items = try decoder.decode([ShoppingItem].self, from: data)
                    
                    DispatchQueue.main.async {
                        self.shoppingItems = items
                    }
                } catch {
                    print("ERROR: 无法加载购物清单: \(error.localizedDescription)")
                }
            }
        }
        
        // 保存数据到磁盘
        func save() {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                
                do {
                    let data = try JSONEncoder().encode(self.shoppingItems)
                    let outfile = try Self.fileURL()
                    try data.write(to: outfile)
                } catch {
                    print("ERROR: 无法保存购物清单: \(error.localizedDescription)")
                }
            }
        }
        
        // 添加新商品
        func addItem(_ item: ShoppingItem) {
            shoppingItems.append(item)
            save()
        }
        
        // 根据FoodItem创建并添加购物项
        func addFromFood(_ foodItem: FoodItem) {
            let item = ShoppingItem(
                name: foodItem.name,
                category: foodItem.category,
                notes: foodItem.notes
            )
            addItem(item)
        }
        
        // 更新现有商品
        func updateItem(_ item: ShoppingItem) {
            if let index = shoppingItems.firstIndex(where: { $0.id == item.id }) {
                shoppingItems[index] = item
                save()
            }
        }
        
        // 删除商品
        func deleteItem(_ item: ShoppingItem) {
            shoppingItems.removeAll { $0.id == item.id }
            save()
        }
        
        // 标记为已购买
        func markAsPurchased(_ item: ShoppingItem) {
            var updatedItem = item
            updatedItem.isPurchased = true
            updateItem(updatedItem)
        }
        
        // 标记为未购买
        func markAsNotPurchased(_ item: ShoppingItem) {
            var updatedItem = item
            updatedItem.isPurchased = false
            updateItem(updatedItem)
        }
        
        // 未购买的商品
        var unpurchasedItems: [ShoppingItem] {
            return shoppingItems.filter { !$0.isPurchased }
        }
        
        // 已购买的商品
        var purchasedItems: [ShoppingItem] {
            return shoppingItems.filter { $0.isPurchased }
        }
        
        // 按分类筛选
        func items(inCategory category: Category) -> [ShoppingItem] {
            return shoppingItems.filter { $0.category == category }
        }
    }

    class FoodHistoryStore: ObservableObject {
        @Published var historyEntries: [FoodHistoryEntry] = []
        
        private static func fileURL() throws -> URL {
            try FileManager.default.url(for: .documentDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: false)
                .appendingPathComponent("foodHistory.data")
        }
        
        // 从磁盘加载数据
        func load() {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                
                do {
                    let fileURL = try Self.fileURL()
                    guard let data = try? Data(contentsOf: fileURL) else {
                        // 如果文件不存在，使用空数组
                        DispatchQueue.main.async {
                            self.historyEntries = []
                        }
                        return
                    }
                    
                    let decoder = JSONDecoder()
                    let entries = try decoder.decode([FoodHistoryEntry].self, from: data)
                    
                    DispatchQueue.main.async {
                        self.historyEntries = entries
                    }
                } catch {
                    print("ERROR: 无法加载食物历史记录: \(error.localizedDescription)")
                }
            }
        }
        
        // 保存数据到磁盘
        func save() {
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                
                do {
                    let data = try JSONEncoder().encode(self.historyEntries)
                    let outfile = try Self.fileURL()
                    try data.write(to: outfile)
                } catch {
                    print("ERROR: 无法保存食物历史记录: \(error.localizedDescription)")
                }
            }
        }
        
        // 添加历史记录
        func addEntry(_ entry: FoodHistoryEntry) {
            historyEntries.append(entry)
            save()
        }
        
        // 从食物项添加历史记录
        func addEntryFromFood(_ foodItem: FoodItem, disposalType: FoodDisposalType) {
            let entry = FoodHistoryEntry(
                foodName: foodItem.name,
                category: foodItem.category,
                disposalType: disposalType
            )
            addEntry(entry)
        }
        
        // 获取特定周的历史记录
        func entriesForWeek(date: Date) -> [FoodHistoryEntry] {
            let calendar = Calendar.current
            let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            
            return historyEntries.filter { entry in
                let entryWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: entry.disposalDate)
                return entryWeekComponents.yearForWeekOfYear == weekComponents.yearForWeekOfYear &&
                       entryWeekComponents.weekOfYear == weekComponents.weekOfYear
            }
        }
        
        // 获取特定周的统计数据
        func weeklyStatistics(date: Date) -> (consumed: Int, wasted: Int) {
            let weekEntries = entriesForWeek(date: date)
            let consumed = weekEntries.filter { $0.disposalType == .consumed }.count
            let wasted = weekEntries.filter { $0.disposalType == .wasted }.count
            return (consumed, wasted)
        }
    }

    // ReceiptStore and OCRManager have been moved to ReceiptManager.swift
} 