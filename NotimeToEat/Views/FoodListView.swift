import SwiftUI
// 导入Globals.swift中定义的类型和管理器

// 定义排序选项
enum SortOption: String, CaseIterable, Identifiable {
    case nameAsc = "按名称 (A-Z)"
    case nameDesc = "按名称 (Z-A)"
    case expirationAsc = "按过期日期 (最近)"
    case expirationDesc = "按过期日期 (最远)"
    
    var id: String { self.rawValue }
}

struct FoodListView: View {
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var receiptStore: ReceiptStore
    @State private var showingAddFood = false
    @State private var showingAddReceipt = false
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .expirationAsc
    @State private var isAddButtonExpanded = false
    
    var filteredItems: [FoodItem] {
        let baseItems = searchText.isEmpty ? foodStore.foodItems : foodStore.foodItems.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) 
        }
        
        return sortItems(baseItems)
    }
    
    // 根据选定的排序选项对食物项进行排序
    func sortItems(_ items: [FoodItem]) -> [FoodItem] {
        switch selectedSortOption {
        case .nameAsc:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .expirationAsc:
            return items.sorted { $0.expirationDate < $1.expirationDate }
        case .expirationDesc:
            return items.sorted { $0.expirationDate > $1.expirationDate }
        }
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                List {
                    if !foodStore.expiringSoonItems.isEmpty {
                        Section(header: Text("即将过期")) {
                            ForEach(sortItems(foodStore.expiringSoonItems)) { item in
                                FoodItemRow(item: item)
                            }
                            .onDelete { indexSet in
                                deleteItems(from: foodStore.expiringSoonItems, at: indexSet)
                            }
                        }
                    }
                    
                    if !foodStore.expiredItems.isEmpty {
                        Section(header: Text("已过期")) {
                            ForEach(sortItems(foodStore.expiredItems)) { item in
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
                        Menu {
                            Picker("排序方式", selection: $selectedSortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Label("排序", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
                .sheet(isPresented: $showingAddFood) {
                    AddFoodView()
                }
                .sheet(isPresented: $showingAddReceipt) {
                    AddReceiptView()
                }
            }
            
            // 右下角浮动的功能按钮组
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    
                    // 展开后的两个选项按钮
                    if isAddButtonExpanded {
                        // 添加食物按钮
                        Button(action: {
                            showingAddFood = true
                            isAddButtonExpanded = false
                        }) {
                            HStack {
                                Text("添加食物")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                
                                Image(systemName: "carrot")
                                    .font(.footnote)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .clipShape(Capsule())
                            .shadow(radius: 2)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .padding(.trailing, 8)
                        
                        // 添加小票按钮
                        Button(action: {
                            showingAddReceipt = true
                            isAddButtonExpanded = false
                        }) {
                            HStack {
                                Text("添加小票")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                
                                Image(systemName: "doc.text.image")
                                    .font(.footnote)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(Capsule())
                            .shadow(radius: 2)
                        }
                        .transition(.scale.combined(with: .opacity))
                        .padding(.trailing, 8)
                    }
                    
                    // 主添加按钮
                    Button(action: {
                        withAnimation(.spring()) {
                            isAddButtonExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isAddButtonExpanded ? "xmark" : "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(isAddButtonExpanded ? Color.red : Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                            .rotationEffect(.degrees(isAddButtonExpanded ? 90 : 0))
                            .animation(.spring(), value: isAddButtonExpanded)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .onChange(of: showingAddFood) { newValue in
            // 确保当表单关闭时，展开状态也被重置
            if !newValue && isAddButtonExpanded {
                isAddButtonExpanded = false
            }
        }
        .onChange(of: showingAddReceipt) { newValue in
            // 确保当表单关闭时，展开状态也被重置
            if !newValue && isAddButtonExpanded {
                isAddButtonExpanded = false
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
            .environmentObject(ReceiptStore())
    }
} 