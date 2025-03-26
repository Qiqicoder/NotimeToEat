import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// A service class to handle data synchronization with Firestore
class FirestoreService: ObservableObject {
    // 单例模式
    static let shared = FirestoreService()
    
    // Firestore database reference
    private let db = Firestore.firestore()
    
    // 认证服务引用
    private let authService = AuthService.shared
    
    // 发布订阅属性，用于UI状态管理
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: Error?
    
    private init() {
        // 私有初始化方法以确保单例
        print("FirestoreService 初始化完成")
    }
    
    // MARK: - 上传食物数据到Firestore
    
    /// 上传本地食物数据到Firestore
    /// - Parameter foodItems: 要上传的食物项数组
    /// - Parameter completion: 完成回调，返回成功状态和可能的错误
    func uploadFoodItems(_ foodItems: [FoodItem], completion: @escaping (Bool, Error?) -> Void) {
        guard authService.isAuthenticated else {
            print("上传食物数据失败: 用户未登录")
            completion(false, NSError(domain: "com.notimetoeat.firestore", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"]))
            return
        }
        
        isSyncing = true
        syncError = nil
        
        let userID = authService.currentUser.id
        let batch = db.batch()
        
        print("准备上传 \(foodItems.count) 个食物项目到 Firestore")
        
        // 创建一个包含所有食物项目的集合引用
        let foodCollectionRef = db.collection("users").document(userID).collection("foods")
        
        for food in foodItems {
            let foodDocRef = foodCollectionRef.document(food.id.uuidString)
            
            // 转换为Firestore可存储的数据
            let foodData: [String: Any] = [
                "id": food.id.uuidString,
                "name": food.name,
                "expirationDate": food.expirationDate,
                "category": food.category.rawValue,
                "notes": food.notes ?? "",
                "addedDate": food.addedDate,
                "tags": food.tags.map { $0.rawValue },
                "syncTimestamp": FieldValue.serverTimestamp()
            ]
            
            batch.setData(foodData, forDocument: foodDocRef, merge: true)
        }
        
        // 将上传时间记录到用户文档
        let userDocRef = db.collection("users").document(userID)
        batch.setData([
            "lastFoodSync": FieldValue.serverTimestamp()
        ], forDocument: userDocRef, merge: true)
        
        // 提交批处理
        batch.commit { [weak self] error in
            guard let self = self else { return }
            
            self.isSyncing = false
            
            if let error = error {
                self.syncError = error
                print("Firestore上传食物数据失败: \(error.localizedDescription)")
                completion(false, error)
            } else {
                self.lastSyncTime = Date()
                print("Firestore成功上传\(foodItems.count)个食物数据项")
                completion(true, nil)
            }
        }
    }
    
    // MARK: - 从Firestore获取食物数据
    
    /// 从Firestore获取食物数据
    /// - Parameter completion: 完成回调，返回食物项数组和可能的错误
    func fetchFoodItems(completion: @escaping ([FoodItem]?, Error?) -> Void) {
        guard authService.isAuthenticated else {
            print("获取食物数据失败: 用户未登录")
            completion(nil, NSError(domain: "com.notimetoeat.firestore", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"]))
            return
        }
        
        isSyncing = true
        syncError = nil
        
        let userID = authService.currentUser.id
        let foodCollectionRef = db.collection("users").document(userID).collection("foods")
        
        print("开始从 Firestore 获取食物数据")
        
        foodCollectionRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            self.isSyncing = false
            
            if let error = error {
                self.syncError = error
                print("从Firestore获取食物数据失败: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("从Firestore获取到0个食物项目 (空文档)")
                completion([], nil)
                return
            }
            
            print("从Firestore获取到 \(documents.count) 个文档")
            
            // 解析文档为食物项
            var foodItems: [FoodItem] = []
            
            for document in documents {
                let data = document.data()
                
                // 从Firestore数据解析食物项
                if let idString = data["id"] as? String,
                   let name = data["name"] as? String,
                   let expirationTimestamp = data["expirationDate"] as? Timestamp,
                   let categoryString = data["category"] as? String,
                   let addedTimestamp = data["addedDate"] as? Timestamp {
                    
                    // 转换Firestore时间戳为Date
                    let expirationDate = expirationTimestamp.dateValue()
                    let addedDate = addedTimestamp.dateValue()
                    
                    // 解析UUID
                    guard let id = UUID(uuidString: idString) else {
                        print("警告: 无法解析UUID: \(idString)")
                        continue
                    }
                    
                    // 解析枚举
                    guard let category = Category(rawValue: categoryString) else {
                        print("警告: 无法解析Category: \(categoryString)")
                        continue
                    }
                    
                    // 解析标签
                    var tags: [Tag] = []
                    if let tagStrings = data["tags"] as? [String] {
                        tags = tagStrings.compactMap { Tag(rawValue: $0) }
                    }
                    
                    // 创建食物项
                    let foodItem = FoodItem(
                        id: id,
                        name: name,
                        expirationDate: expirationDate,
                        category: category,
                        tags: tags,
                        addedDate: addedDate,
                        notes: data["notes"] as? String
                    )
                    
                    foodItems.append(foodItem)
                }
            }
            
            self.lastSyncTime = Date()
            print("从Firestore成功解析 \(foodItems.count)/\(documents.count) 个食物数据项")
            completion(foodItems, nil)
        }
    }
    
    // MARK: - 合并本地和云端数据
    
    /// 将本地食物数据与云端数据合并
    /// - Parameters:
    ///   - localItems: 本地食物项
    ///   - cloudItems: 云端食物项
    /// - Returns: 合并后的食物项数组
    func mergeFoodItems(localItems: [FoodItem], cloudItems: [FoodItem]) -> [FoodItem] {
        var mergedItems = localItems
        
        // 创建一个基于ID的本地食物项字典，以便快速查找
        let localItemsDict = Dictionary(uniqueKeysWithValues: localItems.map { ($0.id, $0) })
        
        var newItemsCount = 0
        
        // 遍历云端项目
        for cloudItem in cloudItems {
            // 如果本地没有这个项目，添加它
            if localItemsDict[cloudItem.id] == nil {
                mergedItems.append(cloudItem)
                newItemsCount += 1
            }
            // 注意：如果本地和云端都有相同ID的项目，我们保留本地版本
            // 这种策略可以根据需要调整，例如可以比较时间戳选择较新的版本
        }
        
        print("数据合并完成: 本地 \(localItems.count) 项 + 云端新增 \(newItemsCount) 项 = \(mergedItems.count) 项")
        return mergedItems
    }
    
    // MARK: - 删除本地数据
    
    /// 从Firestore删除指定的食物数据
    /// - Parameters:
    ///   - foodItemID: 要删除的食物项ID
    ///   - completion: 完成回调，返回成功状态和可能的错误
    func deleteFoodItem(withID foodItemID: UUID, completion: @escaping (Bool, Error?) -> Void) {
        guard authService.isAuthenticated else {
            print("删除食物数据失败: 用户未登录")
            completion(false, NSError(domain: "com.notimetoeat.firestore", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"]))
            return
        }
        
        isSyncing = true
        syncError = nil
        
        let userID = authService.currentUser.id
        let foodDocRef = db.collection("users").document(userID).collection("foods").document(foodItemID.uuidString)
        
        print("准备从Firestore删除食物数据: \(foodItemID.uuidString)")
        
        foodDocRef.delete { [weak self] error in
            guard let self = self else { return }
            
            self.isSyncing = false
            
            if let error = error {
                self.syncError = error
                print("从Firestore删除食物数据失败: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("从Firestore成功删除食物数据: \(foodItemID.uuidString)")
                completion(true, nil)
            }
        }
    }
    
    /// 删除本地已删除但云端仍存在的食物数据
    /// - Parameters:
    ///   - localItemIDs: 本地食物项ID集合
    ///   - completion: 完成回调，返回成功状态和可能的错误
    func syncDeletedItems(localItemIDs: Set<UUID>, completion: @escaping (Bool, Error?) -> Void) {
        guard authService.isAuthenticated else {
            print("同步删除操作失败: 用户未登录")
            completion(false, NSError(domain: "com.notimetoeat.firestore", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"]))
            return
        }
        
        isSyncing = true
        syncError = nil
        
        let userID = authService.currentUser.id
        let foodCollectionRef = db.collection("users").document(userID).collection("foods")
        
        // 获取云端所有食物数据
        foodCollectionRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.isSyncing = false
                self.syncError = error
                print("获取Firestore食物数据失败: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                // 云端没有数据，不需要删除
                self.isSyncing = false
                print("Firestore中没有需要同步删除的数据")
                completion(true, nil)
                return
            }
            
            // 创建批量删除操作
            let batch = self.db.batch()
            var deletedCount = 0
            
            // 查找云端存在但本地已删除的项目
            for document in documents {
                if let idString = document.data()["id"] as? String,
                   let id = UUID(uuidString: idString),
                   !localItemIDs.contains(id) {
                    // 如果云端存在但本地没有，则需要从云端删除
                    batch.deleteDocument(document.reference)
                    deletedCount += 1
                }
            }
            
            if deletedCount == 0 {
                // 没有需要删除的项目
                self.isSyncing = false
                print("没有需要从Firestore删除的食物数据")
                completion(true, nil)
                return
            }
            
            // 执行批量删除
            batch.commit { [weak self] error in
                guard let self = self else { return }
                
                self.isSyncing = false
                
                if let error = error {
                    self.syncError = error
                    print("从Firestore批量删除食物数据失败: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("成功从Firestore删除\(deletedCount)个食物数据项")
                    completion(true, nil)
                }
            }
        }
    }
    
    /// 从Firestore删除用户的所有食物数据
    /// - Parameter completion: 完成回调，返回成功状态和可能的错误
    func deleteAllFoodItems(completion: @escaping (Bool, Error?) -> Void) {
        guard authService.isAuthenticated else {
            print("删除食物数据失败: 用户未登录")
            completion(false, NSError(domain: "com.notimetoeat.firestore", code: 401, userInfo: [NSLocalizedDescriptionKey: "用户未登录"]))
            return
        }
        
        isSyncing = true
        syncError = nil
        
        let userID = authService.currentUser.id
        let foodCollectionRef = db.collection("users").document(userID).collection("foods")
        
        print("准备从 Firestore 删除所有食物数据")
        
        // 首先获取所有食物文档
        foodCollectionRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                self.isSyncing = false
                self.syncError = error
                print("获取Firestore食物数据失败: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                // 没有文档需要删除
                self.isSyncing = false
                print("Firestore中没有食物数据需要删除")
                completion(true, nil)
                return
            }
            
            print("找到 \(documents.count) 个文档需要删除")
            
            // 创建一个批量删除操作
            let batch = self.db.batch()
            
            // 添加每个文档的删除操作
            for document in documents {
                batch.deleteDocument(document.reference)
            }
            
            // 执行批量操作
            batch.commit { [weak self] error in
                guard let self = self else { return }
                
                self.isSyncing = false
                
                if let error = error {
                    self.syncError = error
                    print("删除Firestore食物数据失败: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("成功从Firestore删除\(documents.count)个食物数据项")
                    completion(true, nil)
                }
            }
        }
    }
}

//// 使Services能够访问FirestoreService
//extension Services {
//    typealias FirestoreService = FirestoreService
//} 
