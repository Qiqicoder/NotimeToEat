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
                    .onAppear {
                        // 请求通知权限
                        NotificationManager.shared.requestAuthorization()
                        // 加载存储的食品数据
                        foodStore.load()
                        // 加载小票数据
                        receiptManager.load()
                        // 加载购物清单数据
                        shoppingListStore.load()
                        
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
    @Binding var isShowing: Bool
    
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
