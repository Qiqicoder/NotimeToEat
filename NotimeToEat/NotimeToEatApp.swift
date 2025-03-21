//
//  NotimeToEatApp.swift
//  NotimeToEat
//
//  Created by CharlesDai on 3/21/25.
//

import SwiftUI

@main
struct NotimeToEatApp: App {
    // 食品存储管理器
    @StateObject private var foodStore = FoodStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(foodStore)
                .onAppear {
                    // 请求通知权限
                    NotificationManager.shared.requestAuthorization()
                    // 加载存储的食品数据
                    foodStore.load()
                }
        }
    }
}
