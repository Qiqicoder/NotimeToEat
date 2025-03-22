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
    
    init() {
        // 检查平台要求】
        PlatformCompatibility.setupUICompatibility()
    }
    
    var body: some Scene {
        WindowGroup {
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
                }
        }
    }
}
#endif
