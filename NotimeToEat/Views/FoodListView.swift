import SwiftUI
// Add this line to explicitly import the Edge type
extension Edge {
    // This is just to make the Edge type visible for swipeActions
}

// 导入Globals.swift中定义的类型和管理器

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
            FoodListContent()
                .listStyle(InsetGroupedListStyle())
                .navigationTitle(NSLocalizedString("app_name", comment: ""))
                .searchable(text: $searchText, prompt: NSLocalizedString("search_food", comment: ""))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Picker(NSLocalizedString("sort_option", comment: ""), selection: $selectedSortOption) {
                                ForEach(SortOption.allCases) { option in
                                    Text(NSLocalizedString(option.rawValue, comment: "")).tag(option)
                                }
                            }
                        } label: {
                            Label(NSLocalizedString("sort_option", comment: ""), systemImage: "arrow.up.arrow.down")
                        }
                    }
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
    
    @ViewBuilder
    private func FoodListContent() -> some View {
        List {
            // Expiring Soon Section
            if !foodStore.expiringSoonItems.isEmpty {
                ExpiringSoonSection()
            }
            
            // Expired Section
            if !foodStore.expiredItems.isEmpty {
                ExpiredSection()
            }
            
            // All Food Section
            AllFoodSection()
        }
    }
    
    @ViewBuilder
    private func ExpiringSoonSection() -> some View {
        Section(header: Text(NSLocalizedString("expiring_soon", comment: ""))) {
            ForEach(sortItems(foodStore.expiringSoonItems)) { item in
                FoodItemRow(item: item)
                    .swipeActions(allowsFullSwipe: false) {
                        SwipeActionButtons(for: item)
                    }
            }
        }
    }
    
    @ViewBuilder
    private func ExpiredSection() -> some View {
        Section(header: Text(NSLocalizedString("expired_food", comment: ""))) {
            ForEach(sortItems(foodStore.expiredItems)) { item in
                FoodItemRow(item: item)
                    .swipeActions(allowsFullSwipe: false) {
                        SwipeActionButtons(for: item)
                    }
            }
        }
    }
    
    @ViewBuilder
    private func AllFoodSection() -> some View {
        Section(header: Text(NSLocalizedString("ALL_FOOD", comment: ""))) {
            ForEach(filteredItems) { item in
                FoodItemRow(item: item)
                    .swipeActions(allowsFullSwipe: false) {
                        SwipeActionButtons(for: item)
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
            .environmentObject(ReceiptManager.shared)
            .environmentObject(ShoppingListStore())
    }
} 