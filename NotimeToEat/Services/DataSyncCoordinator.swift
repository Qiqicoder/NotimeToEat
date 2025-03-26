import SwiftUI
import Foundation

// Import DataSyncPromptType from the view file
// We need to define it here since we use it in this file
enum DataSyncPromptType {
    case uploadLocal     // 上传本地数据到云端
    case deleteLocal     // 删除本地数据
}

/// 数据同步协调器，用于处理登录、注销和用户切换时的数据同步
class DataSyncCoordinator: ObservableObject {
    
    // 单例模式
    static let shared = DataSyncCoordinator()
    
    // 依赖服务
    private let authService = AuthService.shared
    
    // FoodStore将从外部注入
    // 这样可以确保使用与UI相同的实例
    var foodStore: FoodStore!
    
    // 同步状态
    @Published var isSyncing: Bool = false
    @Published var showSyncPrompt: Bool = false
    @Published var syncPromptType: DataSyncPromptType = .uploadLocal
    
    // 初始化
    private init() {
        print("DataSyncCoordinator 初始化中...")
        // 初始时不设置监听器，等foodStore注入后再设置
        print("DataSyncCoordinator 初始化完成，等待FoodStore注入")
    }
    
    // 设置FoodStore并开始监听认证状态
    func setFoodStore(_ store: FoodStore) {
        print("DataSyncCoordinator: 注入FoodStore，包含 \(store.foodItems.count) 个食物项目")
        foodStore = store
        setupAuthListeners()
    }
    
    // 设置认证状态监听
    private func setupAuthListeners() {
        print("设置 AuthService 登录状态监听...")
        
        // 确保foodStore已注入
        guard foodStore != nil else {
            print("错误: 尝试设置认证监听器，但FoodStore尚未注入")
            return
        }
        
        // Check if authService is initialized
        if let _ = authService.onLoginStateChanged {
            print("AuthService.onLoginStateChanged 存在，设置监听器")
        } else {
            print("错误: AuthService.onLoginStateChanged 为 nil，无法设置登录状态监听")
        }
        
        // 设置登录状态变更监听器
        // Using a capture list to avoid strong reference cycle
        authService.onLoginStateChanged = { [weak self] stateChange in
            guard let self = self else { return }
            guard let foodStore = self.foodStore else {
                print("错误: 收到登录状态变更事件，但FoodStore尚未注入")
                return
            }
            
            switch stateChange {
            case .loggedIn(let user):
                // 用户登录（之前未登录）
                print("用户登录: \(user.email ?? "unknown")")
                self.handleNewLogin(user: user)
                
            case .loggedOut(let user):
                // 用户登出
                print("用户登出: \(user.email ?? "unknown")")
                self.handleLogout(user: user)
            }
        }
        
        print("已设置数据同步的登录状态监听")
    }
    
    // MARK: - 处理不同的认证场景
    
    /// 处理新用户登录
    private func handleNewLogin(user: User) {
        guard let foodStore = foodStore else {
            print("错误: 处理新用户登录，但FoodStore尚未注入")
            return
        }
        
        print("处理新用户登录: \(user.email ?? "unknown")")
        print("FoodStore状态: 包含 \(foodStore.foodItems.count) 个食物项目")
        
        // 如果本地有数据，询问是否上传
        if !foodStore.foodItems.isEmpty {
            // 显示询问上传的提示
            print("本地有 \(foodStore.foodItems.count) 个食物项目，显示上传提示")
            syncPromptType = .uploadLocal
            showSyncPrompt = true
        } else {
            // 本地没有数据，直接从云端获取
            print("本地没有数据，直接从云端获取")
            fetchCloudData()
        }
    }
    
    /// 处理用户登出
    private func handleLogout(user: User) {
        print("处理用户登出: \(user.email ?? "unknown")")
        // 询问是否删除本地数据
        if !foodStore.foodItems.isEmpty {
            print("本地有 \(foodStore.foodItems.count) 个食物项目，显示删除提示")
            syncPromptType = .deleteLocal
            showSyncPrompt = true
        }
    }
    

    
    // MARK: - 数据同步操作
    
    /// 确认上传本地数据到云端
    func confirmUploadData() {
        print("开始双向同步数据")
        isSyncing = true
        
        // 使用新的双向同步方法，可以保留本地和云端的所有数据
        foodStore.syncOnLogin { [weak self] success, error in
            guard let self = self else { return }
            
            self.isSyncing = false
            
            if success {
                print("登录时双向同步数据成功")
            } else {
                // 处理错误...
                print("登录时双向同步数据失败: \(error?.localizedDescription ?? "未知错误")")
            }
        }
    }
    
    /// 确认删除本地数据
    func confirmDeleteLocalData() {
        print("确认删除本地数据")
        foodStore.clearLocalData()
    }
    
    
    /// 从云端获取数据
    private func fetchCloudData() {
        print("开始从云端获取数据")
        isSyncing = true
        
        foodStore.fetchFromCloud { [weak self] success, error in
            guard let self = self else { return }
            
            self.isSyncing = false
            
            if success {
                print("从云端获取数据成功")
            } else {
                // 处理错误...
                print("从云端获取数据失败: \(error?.localizedDescription ?? "未知错误")")
            }
        }
    }
    
    /// 取消数据同步提示
    func cancelSyncPrompt() {
        print("取消数据同步提示")
        showSyncPrompt = false
        
    }
}

// 使Services能够访问DataSyncCoordinator
extension Services {
    typealias DataSyncCoordinator = NotimeToEat.DataSyncCoordinator
} 