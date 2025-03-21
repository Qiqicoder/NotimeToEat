import SwiftUI

struct FoodListView: View {
    @EnvironmentObject var foodStore: FoodStore
    @State private var showingAddFood = false
    @State private var searchText = ""
    
    var filteredItems: [FoodItem] {
        if searchText.isEmpty {
            return foodStore.sortedByExpirationDate
        } else {
            return foodStore.sortedByExpirationDate.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !foodStore.expiringSoonItems.isEmpty {
                    Section(header: Text("即将过期")) {
                        ForEach(foodStore.expiringSoonItems) { item in
                            FoodItemRow(item: item)
                        }
                        .onDelete { indexSet in
                            deleteItems(from: foodStore.expiringSoonItems, at: indexSet)
                        }
                    }
                }
                
                if !foodStore.expiredItems.isEmpty {
                    Section(header: Text("已过期")) {
                        ForEach(foodStore.expiredItems) { item in
                            FoodItemRow(item: item)
                        }
                        .onDelete { indexSet in
                            deleteItems(from: foodStore.expiredItems, at: indexSet)
                        }
                    }
                }
                
                Section(header: Text("所有食物")) {
                    ForEach(filteredItems) { item in
                        FoodItemRow(item: item)
                    }
                    .onDelete { indexSet in
                        deleteItems(from: filteredItems, at: indexSet)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("冰箱里的东西该吃了！")
            .searchable(text: $searchText, prompt: "搜索食物")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddFood = true
                    }) {
                        Label("添加食物", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
        }
    }
    
    private func deleteItems(from itemList: [FoodItem], at offsets: IndexSet) {
        for index in offsets {
            let item = itemList[index]
            foodStore.deleteFood(item)
        }
    }
}

struct FoodItemRow: View {
    let item: FoodItem
    @EnvironmentObject var foodStore: FoodStore
    @State private var showingEditSheet = false
    
    var body: some View {
        Button(action: {
            showingEditSheet = true
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: item.category.iconName)
                            .foregroundColor(.secondary)
                        Text(item.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(item.expirationDate.remainingDaysDescription())
                        .font(.caption)
                        .foregroundColor(Color.forRemainingDays(item.daysRemaining))
                }
                
                Spacer()
                
                // 显示标签
                HStack(spacing: 2) {
                    ForEach(item.tags, id: \.self) { tag in
                        Image(systemName: tag.iconName)
                            .foregroundColor(tag.color)
                            .font(.caption)
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(tag.color.opacity(0.2))
                            )
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditFoodView(item: item)
        }
    }
}

struct FoodListView_Previews: PreviewProvider {
    static var previews: some View {
        FoodListView()
            .environmentObject(FoodStore())
    }
} 