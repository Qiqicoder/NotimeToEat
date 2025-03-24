import SwiftUI
// Add this line to explicitly import the Edge type
extension Edge {
    // This is just to make the Edge type visible for swipeActions
}

// 导入Globals.swift中定义的类型和管理器
// 导入共享的FoodItemRow组件

// 定义排序选项
enum SortOption: String, CaseIterable, Identifiable {
    case nameAsc = "alpha_asc"
    case nameDesc = "alpha_desc"
    case expirationAsc = "date_recent"
    case expirationDesc = "date_old"
    
    var id: String { self.rawValue }
}

struct FoodListView: View {
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var receiptManager: ReceiptManager
    @EnvironmentObject var shoppingListStore: ShoppingListStore
    @EnvironmentObject var foodHistoryStore: FoodHistoryStore
    @State private var showingAddFood = false
    @State private var showingAddReceipt = false
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .expirationAsc
    @State private var isAddButtonExpanded = false
    @State private var showingDisposalOptions = false
    @State private var selectedFoodItem: FoodItem?
    @State private var selectedCategory: Category? = nil
    
    var filteredItems: [FoodItem] {
        // 首先筛选基本项目
        var baseItems = foodStore.foodItems
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            baseItems = baseItems.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
        
        // 按类别筛选
        if let category = selectedCategory {
            baseItems = baseItems.filter { $0.category == category }
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
            NavigationViewContent()
            FloatingAddButtons()
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
    
    // MARK: - Extracted Components
    
    @ViewBuilder
    private func NavigationViewContent() -> some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部分类导航栏
                ScrollView(.horizontal, showsIndicators: false) {
                    CategoryScrollBar()
                        .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray5)),
                    alignment: .bottom
                )
                
                // 食物列表内容
                FoodListContent()
                    .listStyle(InsetGroupedListStyle())
            }
            .navigationTitle(NSLocalizedString("app_name", comment: ""))
            .searchable(text: $searchText, prompt: NSLocalizedString("search_food", comment: ""))
            .toolbar {
                ToolbarContent()
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
            .sheet(isPresented: $showingAddReceipt) {
                AddReceiptView()
            }
            .confirmationDialog(
                NSLocalizedString("how_to_dispose_food", comment: ""),
                isPresented: $showingDisposalOptions,
                titleVisibility: .visible,
                actions: { DisposalDialogButtons() },
                message: { DisposalDialogMessage() }
            )
        }
    }
    
    @ToolbarContentBuilder
    private func ToolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker(NSLocalizedString("sort_option", comment: ""), selection: $selectedSortOption) {
                    ForEach(SortOption.allCases, id: \.id) { option in
                        Text(NSLocalizedString(option.rawValue, comment: "")).tag(option)
                    }
                }
            } label: {
                Label(NSLocalizedString("sort_option", comment: ""), systemImage: "arrow.up.arrow.down")
            }
        }
    }
    
    @ViewBuilder
    private func FoodListContent() -> some View {
        List {
            // 当未选择特定类别时，显示"即将过期"和"已过期"的分组
            if selectedCategory == nil {
                // Expiring Soon Section
                if !foodStore.expiringSoonItems.isEmpty {
                    ExpiringSoonSection()
                }
                
                // Expired Section
                if !foodStore.expiredItems.isEmpty {
                    ExpiredSection()
                }
            }
            
            // All Food Section - 根据选择的类别显示不同的标题
            Section(header: Text(selectedCategory == nil ? 
                              NSLocalizedString("ALL_FOOD", comment: "") : 
                              selectedCategory!.displayName)) {
                if filteredItems.isEmpty {
                    Text(NSLocalizedString("no_food_items_found", comment: "没有找到食物"))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(filteredItems) { item in
                        FoodItemRow(item: item, showEditButton: true, tagDisplayStyle: .circle)
                            .swipeActions(allowsFullSwipe: false) {
                                SwipeActionButtons(for: item)
                            }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func ExpiringSoonSection() -> some View {
        Section(header: Text(NSLocalizedString("expiring_soon", comment: ""))) {
            if foodStore.expiringSoonItems.isEmpty {
                Text(NSLocalizedString("no_expiring_food", comment: "没有即将过期的食物"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(sortItems(foodStore.expiringSoonItems)) { item in
                    FoodItemRow(item: item, showEditButton: true, tagDisplayStyle: .circle)
                        .swipeActions(allowsFullSwipe: false) {
                            SwipeActionButtons(for: item)
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private func ExpiredSection() -> some View {
        Section(header: Text(NSLocalizedString("expired_food", comment: ""))) {
            if foodStore.expiredItems.isEmpty {
                Text(NSLocalizedString("no_expired_food", comment: "没有过期的食物"))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(sortItems(foodStore.expiredItems)) { item in
                    FoodItemRow(item: item, showEditButton: true, tagDisplayStyle: .circle)
                        .swipeActions(allowsFullSwipe: false) {
                            SwipeActionButtons(for: item)
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private func SwipeActionButtons(for item: FoodItem) -> some View {
        Group {
            Button(role: .destructive) {
                selectedFoodItem = item
                showingDisposalOptions = true
            } label: {
                Label(NSLocalizedString("dispose", comment: ""), systemImage: "archivebox")
            }
            
            Button {
                foodStore.deleteFood(item)
                shoppingListStore.addFromFood(item)
            } label: {
                Label(NSLocalizedString("delete_add_to_shopping_list", comment: ""), systemImage: "cart.badge.plus")
            }
            .tint(.green)
        }
    }
    
    @ViewBuilder
    private func DisposalDialogButtons() -> some View {
        Group {
            Button(NSLocalizedString("consumed", comment: "")) {
                if let item = selectedFoodItem {
                    foodStore.disposeFoodItem(item, disposalType: .consumed, historyStore: foodHistoryStore)
                }
            }
            Button(NSLocalizedString("wasted", comment: ""), role: .destructive) {
                if let item = selectedFoodItem {
                    foodStore.disposeFoodItem(item, disposalType: .wasted, historyStore: foodHistoryStore)
                }
            }
            Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {
                selectedFoodItem = nil
            }
        }
    }
    
    @ViewBuilder
    private func DisposalDialogMessage() -> some View {
        if let item = selectedFoodItem {
            Text(NSLocalizedString("please_select_how_to_dispose_of_\"\(item.name)\"", comment: ""))
        } else {
            Text(NSLocalizedString("please_select_disposal_method", comment: ""))
        }
    }
    
    @ViewBuilder
    private func FloatingAddButtons() -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                // Expanded buttons
                if isAddButtonExpanded {
                    ExpandedAddButtons()
                }
                
                // Main add button
                MainAddButton()
            }
        }
    }
    
    @ViewBuilder
    private func ExpandedAddButtons() -> some View {
        Group {
            // Add food button
            Button(action: {
                showingAddFood = true
                isAddButtonExpanded = false
            }) {
                HStack {
                    Text(NSLocalizedString("nav_title_add_food", comment: ""))
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
            
            // Add receipt button
            Button(action: {
                showingAddReceipt = true
                isAddButtonExpanded = false
            }) {
                HStack {
                    Text(NSLocalizedString("add_receipt", comment: ""))
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
    }
    
    @ViewBuilder
    private func MainAddButton() -> some View {
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
    
    @ViewBuilder
    private func CategoryScrollBar() -> some View {
        HStack(spacing: 12) {
            // 全部选项
            CategoryButton(
                title: NSLocalizedString("all", comment: "全部"),
                iconName: "square.grid.2x2",
                isSelected: selectedCategory == nil
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedCategory = nil
                }
            }
            
            // 每个类别选项
            ForEach(Category.allCases, id: \.self) { category in
                CategoryButton(
                    title: category.displayName,
                    iconName: category.iconName,
                    isSelected: selectedCategory == category,
                    count: foodStore.items(inCategory: category).count
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private func CategoryButton(title: String, iconName: String, isSelected: Bool, count: Int? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: iconName)
                        .font(.caption)
                    
                    Text(title)
                        .font(.caption)
                    
                    if let count = count, count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
                
                if isSelected {
                    Rectangle()
                        .frame(width: 20, height: 2)
                        .foregroundColor(Color.accentColor)
                } else {
                    Rectangle()
                        .frame(width: 20, height: 2)
                        .foregroundColor(.clear)
                }
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

struct FoodListView_Previews: PreviewProvider {
    static var previews: some View {
        FoodListView()
            .environmentObject(FoodStore())
            .environmentObject(ReceiptManager.shared)
            .environmentObject(ShoppingListStore())
    }
} 