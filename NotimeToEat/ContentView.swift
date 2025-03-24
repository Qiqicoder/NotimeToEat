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
                    Label(NSLocalizedString("tab_food_list", comment: ""), systemImage: "refrigerator")
                }
                .tag(0)
            
            ShoppingListView()
                .tabItem {
                    Label(NSLocalizedString("tab_shopping_list", comment: ""), systemImage: "cart")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label(NSLocalizedString("tab_profile", comment: ""), systemImage: "person.circle")
                }
                .tag(2)
        }
        .onAppear {
            // 加载小票数据
            receiptManager.load()
            // 加载购物清单数据
            shoppingListStore.load()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var receiptManager: ReceiptManager
    @State private var notificationHours = 24 // 默认提前24小时通知
    @State private var showingHistoryView = false
    @State private var showingUserAccountView = false
    
    var body: some View {
        NavigationView {
            Form {
                // 账户部分
                Section(header: Text(NSLocalizedString("section_account", comment: ""))) {
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
                                    Text(authService.currentUser.displayName ?? NSLocalizedString("unknown_user", comment: ""))
                                        .font(.headline)
                                    Text(NSLocalizedString("logged_in", comment: ""))
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
                                    Text(NSLocalizedString("click_to_login", comment: ""))
                                        .font(.headline)
                                    Text(NSLocalizedString("sync_data", comment: ""))
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
                
                // 小票管理部分
                Section(header: Text(NSLocalizedString("section_receipts", comment: ""))) {
                    NavigationLink(destination: ReceiptListView()) {
                        HStack {
                            Image(systemName: "doc.text.image")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("nav_title_receipts", comment: ""))
                        }
                    }
                    Text(NSLocalizedString("manage_receipts", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text(NSLocalizedString("section_statistics", comment: ""))) {
                    NavigationLink(destination: HistoryView()) {
                        HStack {
                            Image(systemName: "chart.pie")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("food_history_stats", comment: ""))
                        }
                    }
                    Text(NSLocalizedString("view_consumption_stats", comment: ""))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text(NSLocalizedString("section_notification_settings", comment: ""))) {
                    Stepper(String(format: NSLocalizedString("notify_hours_before", comment: ""), notificationHours), value: $notificationHours, in: 1...72)
                    Text(String(format: NSLocalizedString("expiration_notification_description", comment: ""), notificationHours))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section(header: Text(NSLocalizedString("section_storage_management", comment: ""))) {
                    Button(role: .destructive, action: {
                        foodStore.foodItems.removeAll()
                        foodStore.save()
                        NotificationManager.shared.cancelAllNotifications()
                    }) {
                        Text(NSLocalizedString("clear_all_food", comment: ""))
                    }
                }
                
                Section(header: Text(NSLocalizedString("section_about", comment: ""))) {
                    Text(NSLocalizedString("app_slogan", comment: ""))
                        .font(.headline)
                        .bold()
                    Text("Ver: 1.0.0")
                    Text(NSLocalizedString("app_description", comment: ""))
                }
            }
            .navigationTitle(NSLocalizedString("nav_title_profile", comment: ""))
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
        .environmentObject(AuthService.shared)
}

#Preview("Profile View") {
    SettingsView()
        .environmentObject(FoodStore())
        .environmentObject(ReceiptManager.shared)
        .environmentObject(ShoppingListStore())
        .environmentObject(AuthService.shared)
}
