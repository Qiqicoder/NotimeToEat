//
//  ContentView.swift
//  NotimeToEat
//
//  Created by CharlesDai on 3/21/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var receiptStore: ReceiptStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FoodListView()
                .tabItem {
                    Label("食物列表", systemImage: "refrigerator")
                }
                .tag(0)
            
            CategoryView()
                .tabItem {
                    Label("分类", systemImage: "list.bullet")
                }
                .tag(1)
            
            ReceiptListView()
                .tabItem {
                    Label("小票", systemImage: "doc.text.image")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            // 加载小票数据
            receiptStore.load()
        }
    }
}

struct CategoryView: View {
    @EnvironmentObject var foodStore: FoodStore
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Category.allCases, id: \.self) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        HStack {
                            Image(systemName: category.iconName)
                                .foregroundColor(.blue)
                            Text(category.rawValue)
                            Spacer()
                            Text("\(foodStore.items(inCategory: category).count)")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("食物分类")
        }
    }
}

struct CategoryDetailView: View {
    @EnvironmentObject var foodStore: FoodStore
    let category: Category
    
    var body: some View {
        List {
            ForEach(foodStore.items(inCategory: category)) { item in
                FoodItemRow(item: item)
            }
            .onDelete { indexSet in
                let itemsToDelete = indexSet.map { foodStore.items(inCategory: category)[$0] }
                for item in itemsToDelete {
                    foodStore.deleteFood(item)
                }
            }
        }
        .navigationTitle(category.rawValue)
    }
}

struct SettingsView: View {
    @EnvironmentObject var foodStore: FoodStore
    @State private var notificationHours = 24 // 默认提前24小时通知
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("通知设置")) {
                    Stepper("提前 \(notificationHours) 小时通知", value: $notificationHours, in: 1...72)
                    Text("食物过期前将提前\(notificationHours)小时通知您")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("存储管理")) {
                    Button(role: .destructive, action: {
                        foodStore.foodItems.removeAll()
                        foodStore.save()
                        NotificationManager.shared.cancelAllNotifications()
                    }) {
                        Text("清空所有食物")
                    }
                }
                
                Section(header: Text("关于")) {
                    Text("冰箱里的东西该吃了！")
                        .font(.headline)
                    Text("版本: 1.0.0")
                    Text("此应用帮助您管理冰箱中的食物，避免浪费")
                }
            }
            .navigationTitle("设置")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FoodStore())
        .environmentObject(ReceiptStore())
}
