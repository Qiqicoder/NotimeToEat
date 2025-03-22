//
//  NotimeToEatApp.swift
//  NotimeToEat
//
//  Created by CharlesDai on 3/21/25.
//

import SwiftUI

#if os(iOS)
@main
struct NotimeToEatApp: App {
    // 食品存储管理器
    @StateObject private var foodStore = FoodStore()
    // 小票存储管理器
    @StateObject private var receiptManager = ReceiptManager.shared
    // 购物清单管理器
    @StateObject private var shoppingListStore = ShoppingListStore()
    // 食物历史记录管理器
    @StateObject private var foodHistoryStore = FoodHistoryStore()
    // 控制过期食材弹窗的显示
    @State private var showExpirationPopup = false
    // 最快过期的食材
    @State private var soonestExpiringFood: FoodItem?
    
    init() {
        // 检查平台要求】
        PlatformCompatibility.setupUICompatibility()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(foodStore)
                    .environmentObject(receiptManager)
                    .environmentObject(shoppingListStore)
                    .environmentObject(foodHistoryStore)
                    .onAppear {
                        // 请求通知权限
                        NotificationManager.shared.requestAuthorization()
                        // 加载存储的食品数据
                        foodStore.load()
                        // 加载小票数据
                        receiptManager.load()
                        // 加载购物清单数据
                        shoppingListStore.load()
                        // 加载食物历史数据
                        foodHistoryStore.load()
                        
                        // 延迟显示过期食材弹窗，确保数据已加载
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            checkAndShowExpirationAlert()
                        }
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
            Text(food != nil ? "食材过期提醒" : "冰箱状态")
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
                        Text("过期时间：\(dateFormatter.string(from: food.expirationDate))")
                    }
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "clock")
                        Text("剩余天数：")
                        Text("\(food.daysRemaining) 天")
                            .foregroundColor(food.daysRemaining <= 3 ? .red : .primary)
                            .fontWeight(.bold)
                    }
                    
                    if food.daysRemaining <= 3 {
                        Text("请尽快食用！")
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
                                Text(isLoadingRecommendations ? "生成菜品中..." : "给我菜品推荐")
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
                            Text("推荐菜品")
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
                Text("你的冰箱空空如也，没有任何食材。")
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
                Text("知道了")
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
