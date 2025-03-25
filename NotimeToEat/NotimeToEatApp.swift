//
//  NotimeToEatApp.swift
//  NotimeToEat
//
//  Created by CharlesDai on 3/21/25.
//

import SwiftUI
import GoogleSignIn
import CoreData
import UserNotifications
import NotimeToEat
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

// Firebase AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
  
  // 处理Gmail登录回调
  func application(_ app: UIApplication,
                  open url: URL,
                  options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
  }
}

#if os(iOS)
@main
struct NotimeToEatApp: App {
    // Firebase app delegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Core Data 持久化控制器
    let persistenceController = PersistenceController.shared
    // Food database (removed StateObject as we access shared instance directly)
    // 食品存储管理器
    @StateObject private var foodStore = Services.FoodStore()
    // 小票存储管理器
    @StateObject private var receiptManager = ReceiptManager.shared
    // 购物清单管理器
    @StateObject private var shoppingListStore = Services.ShoppingListStore()
    // 食物历史记录管理器
    @StateObject private var foodHistoryStore = Services.FoodHistoryStore()
    // 认证服务
    @StateObject private var authService = AuthService.shared
    // 控制过期食材弹窗的显示
    @State private var showExpirationPopup = false
    // 最快过期的食材
    @State private var soonestExpiringFood: FoodItem?
    
    init() {
        // 检查平台要求】
        PlatformCompatibility.setupUICompatibility()
        // Ensure Core Data is initialized and populated at app startup
        print("APP INIT: Initializing Core Data food database")
        let foodDB = CoreDataFoodDatabase.shared
        print("APP INIT: Core Data food database initialized")
        
        // 输出数据库内容，用于调试
        foodDB.dumpDatabaseContent()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(foodStore)
                    .environmentObject(receiptManager)
                    .environmentObject(shoppingListStore)
                    .environmentObject(foodHistoryStore)
                    .environmentObject(authService)
                    .environment(\.managedObjectContext, persistenceController.viewContext)
                    .onAppear {
                        // 加载初始数据
                        loadInitialData()
                    }
                    .onOpenURL { url in
                        // 处理Google登录回调
                        handleURL(url)
                    }
                
                // 自定义弹窗视图
                if showExpirationPopup {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation {
                                showExpirationPopup = false
                            }
                        }
                    
                    ExpirationPopupView(
                        food: soonestExpiringFood,
                        allFoods: foodStore.foodItems,
                        isShowing: $showExpirationPopup
                    )
                    .transition(.scale)
                }
            }
        }
    }
    
    // 处理URL回调
    func handleURL(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }
    
    // 检查最早过期的食材并显示弹窗
    private func checkAndShowExpirationAlert() {
        // 如果食物列表为空
        if foodStore.foodItems.isEmpty {
            soonestExpiringFood = nil
            withAnimation {
                showExpirationPopup = true
            }
            return
        }
        
        // 获取未过期的食材并按过期日期排序
        let validFoods = foodStore.foodItems.filter { $0.daysRemaining >= 0 }
                                          .sorted { $0.expirationDate < $1.expirationDate }
        
        // 如果有未过期的食材，获取最早过期的一个
        if let earliestExpiring = validFoods.first {
            soonestExpiringFood = earliestExpiring
            withAnimation {
                showExpirationPopup = true
            }
        } else {
            // 如果所有食材都已过期
            soonestExpiringFood = nil
            withAnimation {
                showExpirationPopup = true
            }
        }
    }
    
    // 加载初始数据
    private func loadInitialData() {
        // 请求通知权限
        NotificationManager.shared.requestAuthorization()
        
        // 加载食物数据
        foodStore.load()
        
        // 加载购物清单
        shoppingListStore.load()
        
        // 加载食物历史记录
        foodHistoryStore.load()
        
        // 加载小票记录
        receiptManager.load()
        
        // 强制加载常见食物数据库（确保数据在内存中）
        _ = CoreDataFoodDatabase.shared.allFoodNames
        
        // 检查是否有即将过期的食物
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkAndShowExpirationAlert()
        }
    }
}

// 自定义过期提醒弹窗
struct ExpirationPopupView: View {
    let food: FoodItem?
    let allFoods: [FoodItem]
    @Binding var isShowing: Bool
    
    // AI服务
    private let aiService = Services.AIService(apiKey: Services.APIKeys.deepseekAPIKey)
    
    // 菜品推荐状态
    @State private var isLoadingRecommendations = false
    @State private var recommendedDishes: [(formula: String, dish: String)] = []
    @State private var showRecommendations = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部图标
            Image(systemName: food != nil ? "refrigerator.fill" : "refrigerator")
                .font(.system(size: 60))
                .foregroundColor(food != nil ? .blue : .gray)
                .padding(.top)
            
            // 标题
            Text(food != nil ? NSLocalizedString("food_expiration_reminder", comment: "") : NSLocalizedString("refrigerator_status", comment: ""))
                .font(.headline)
                .fontWeight(.bold)
            
            // 消息内容
            if let food = food {
                VStack(alignment: .center, spacing: 8) {
                    Text(food.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "calendar")
                        Text(String(format: NSLocalizedString("expiration_date", comment: ""), dateFormatter.string(from: food.expirationDate)))
                    }
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "clock")
                        Text(NSLocalizedString("days_remaining", comment: ""))
                        Text(String(format: NSLocalizedString("days_count", comment: ""), food.daysRemaining))
                            .foregroundColor(food.daysRemaining <= 3 ? .red : .primary)
                            .fontWeight(.bold)
                    }
                    
                    if food.daysRemaining <= 3 {
                        Text(NSLocalizedString("please_consume_soon", comment: ""))
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                            .padding(.top, 4)
                    }
                    
                    // 食材推荐按钮
                    if !showRecommendations {
                        Button(action: {
                            getRecipeSuggestions(for: food)
                        }) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text(isLoadingRecommendations ? NSLocalizedString("generating_dishes", comment: "") : NSLocalizedString("give_me_dishes_recommendation", comment: ""))
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isLoadingRecommendations ? Color.gray : Color.green)
                            .cornerRadius(8)
                        }
                        .disabled(isLoadingRecommendations)
                        .padding(.top, 8)
                    }
                    
                    // 推荐的菜品
                    if showRecommendations {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(NSLocalizedString("recommended_dishes", comment: ""))
                                .font(.headline)
                                .padding(.top, 10)
                            
                            ForEach(0..<recommendedDishes.count, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 8) {
                                    // 菜品名称
                                    Text(recommendedDishes[index].dish)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    // 公式部分
                                    HStack(spacing: 2) {
                                        Image(systemName: "square.stack.3d.up.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        
                                        Text(recommendedDishes[index].formula)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal)
            } else {
                Text(NSLocalizedString("your_refrigerator_is_empty", comment: ""))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            // 关闭按钮
            Button(action: {
                withAnimation {
                    isShowing = false
                }
            }) {
                Text(NSLocalizedString("confirm", comment: ""))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: UIScreen.main.bounds.width - 60)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
    
    // 获取菜品推荐
    private func getRecipeSuggestions(for food: FoodItem) {
        isLoadingRecommendations = true
        
        // 获取所有其他食材的名称
        let otherFoodNames = allFoods
            .filter { $0.id != food.id }
            .map { $0.name }
        
        // 调用AI服务获取菜品推荐
        aiService.recommendDishesForFood(
            expiringFood: food.name,
            allFoods: otherFoodNames
        ) { dishes in
            isLoadingRecommendations = false
            
            if let dishes = dishes, !dishes.isEmpty {
                // 显示推荐的菜品
                recommendedDishes = dishes
                withAnimation {
                    showRecommendations = true
                }
            } else {
                // 如果失败，显示默认推荐
                recommendedDishes = [
                    (formula: food.name, dish: "\(food.name)炒饭"),
                    (formula: food.name, dish: "清蒸\(food.name)")
                ]
                withAnimation {
                    showRecommendations = true
                }
            }
        }
    }
    
    // 日期格式化
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
}
#endif
