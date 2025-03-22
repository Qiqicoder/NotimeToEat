//
//  ContentView.swift
//  NotimeToEat
//
//  Created by CharlesDai on 3/21/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var receiptManager: ReceiptManager
    @EnvironmentObject var shoppingListStore: ShoppingListStore
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
            
            ShoppingListView()
                .tabItem {
                    Label("购买清单", systemImage: "cart")
                }
                .tag(2)
            
            ReceiptListView()
                .tabItem {
                    Label("小票", systemImage: "doc.text.image")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(4)
        }
        .onAppear {
            // 加载小票数据
            receiptManager.load()
            // 加载购物清单数据
            shoppingListStore.load()
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
    @EnvironmentObject var shoppingListStore: ShoppingListStore
    let category: Category
    
    var body: some View {
        List {
            ForEach(foodStore.items(inCategory: category)) { item in
                FoodItemRow(item: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            foodStore.deleteFood(item)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        
                        Button {
                            foodStore.deleteFood(item)
                            shoppingListStore.addFromFood(item)
                        } label: {
                            Label("删除并添加到购物清单", systemImage: "cart.badge.plus")
                        }
                        .tint(.green)
                    }
            }
        }
        .navigationTitle(category.rawValue)
    }
}

struct SettingsView: View {
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var authService: AuthService
    @State private var notificationHours = 24 // 默认提前24小时通知
    @State private var showingHistoryView = false
    @State private var showingUserAccountView = false
    
    var body: some View {
        NavigationView {
            Form {
                // 账户部分
                Section(header: Text("账户")) {
                    Button(action: {
                        showingUserAccountView = true
                    }) {
                        HStack {
                            if authService.isAuthenticated {
                                // 已登录的用户显示头像和名称
                                if let photoURL = authService.currentUser.photoURL {
                                    AsyncImage(url: photoURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    // 显示初始字母头像
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 40, height: 40)
                                        Text(authService.currentUser.initials)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(authService.currentUser.displayName ?? "未知用户")
                                        .font(.headline)
                                    Text("已登录")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            } else {
                                // 未登录状态
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading) {
                                    Text("点击登录")
                                        .font(.headline)
                                    Text("同步您的数据")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(header: Text("数据统计")) {
                    NavigationLink(destination: HistoryView()) {
                        HStack {
                            Image(systemName: "chart.pie")
                                .foregroundColor(.blue)
                            Text("食物历史统计")
                        }
                    }
                    Text("查看食物消耗和浪费的统计数据")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
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
            .sheet(isPresented: $showingUserAccountView) {
                UserAccountView()
                    .environmentObject(authService)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FoodStore())
        .environmentObject(ReceiptManager.shared)
        .environmentObject(ShoppingListStore())
}
