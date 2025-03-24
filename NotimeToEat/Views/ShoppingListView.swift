import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject var shoppingListStore: ShoppingListStore
    @State private var showingAddItem = false
    @State private var searchText = ""
    
    var filteredItems: [ShoppingItem] {
        let baseItems = searchText.isEmpty ? shoppingListStore.shoppingItems : shoppingListStore.shoppingItems.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        
        // 按照已购买状态和添加日期排序
        return baseItems.sorted { (item1, item2) in
            if item1.isPurchased != item2.isPurchased {
                return !item1.isPurchased
            }
            return item1.addedDate > item2.addedDate
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                if !shoppingListStore.unpurchasedItems.isEmpty {
                    Section(header: Text(NSLocalizedString("shopping_unpurchased", comment: ""))) {
                        ForEach(shoppingListStore.unpurchasedItems) { item in
                            ShoppingItemRow(item: item)
                        }
                        .onDelete { indexSet in
                            deleteItems(from: shoppingListStore.unpurchasedItems, at: indexSet)
                        }
                    }
                }
                
                if !shoppingListStore.purchasedItems.isEmpty {
                    Section(header: Text(NSLocalizedString("shopping_purchased", comment: ""))) {
                        ForEach(shoppingListStore.purchasedItems) { item in
                            ShoppingItemRow(item: item)
                        }
                        .onDelete { indexSet in
                            deleteItems(from: shoppingListStore.purchasedItems, at: indexSet)
                        }
                    }
                }
                
                if shoppingListStore.shoppingItems.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("shopping_list_empty", comment: ""),
                        systemImage: "cart",
                        description: Text(NSLocalizedString("shopping_list_add_hint", comment: ""))
                    )
                    .padding(.top, 50)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(NSLocalizedString("tab_shopping_list", comment: ""))
            .searchable(text: $searchText, prompt: NSLocalizedString("search_items", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddItem = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddShoppingItemView()
            }
        }
    }
    
    private func deleteItems(from itemList: [ShoppingItem], at offsets: IndexSet) {
        for index in offsets {
            let item = itemList[index]
            shoppingListStore.deleteItem(item)
        }
    }
}

struct ShoppingItemRow: View {
    let item: ShoppingItem
    @EnvironmentObject var shoppingListStore: ShoppingListStore
    @State private var showingEditSheet = false
    
    var body: some View {
        Button(action: {
            showingEditSheet = true
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundColor(item.isPurchased ? .gray : .primary)
                        .strikethrough(item.isPurchased)
                    
                    HStack {
                        Image(systemName: item.category.iconName)
                            .foregroundColor(.secondary)
                        Text(item.category.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    // 切换购买状态
                    if item.isPurchased {
                        shoppingListStore.markAsNotPurchased(item)
                    } else {
                        shoppingListStore.markAsPurchased(item)
                    }
                }) {
                    Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(item.isPurchased ? .green : .gray)
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditShoppingItemView(item: item)
        }
    }
}

struct AddShoppingItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var shoppingListStore: ShoppingListStore
    
    @State private var name = ""
    @State private var category = Category.other
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("section_basic_info", comment: ""))) {
                    TextField(NSLocalizedString("item_name", comment: ""), text: $name)
                    
                    Picker(NSLocalizedString("select_category", comment: ""), selection: $category) {
                        ForEach(Category.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section(header: Text(NSLocalizedString("section_notes", comment: ""))) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(NSLocalizedString("nav_title_add_item", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "")) {
                        saveItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveItem() {
        let item = ShoppingItem(
            name: name,
            category: category,
            notes: notes.isEmpty ? nil : notes
        )
        
        shoppingListStore.addItem(item)
        dismiss()
    }
}

struct EditShoppingItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var shoppingListStore: ShoppingListStore
    
    let item: ShoppingItem
    
    @State private var name: String
    @State private var category: Category
    @State private var notes: String
    @State private var isPurchased: Bool
    
    init(item: ShoppingItem) {
        self.item = item
        
        // 初始化状态变量
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _notes = State(initialValue: item.notes ?? "")
        _isPurchased = State(initialValue: item.isPurchased)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("section_basic_info", comment: ""))) {
                    TextField(NSLocalizedString("item_name", comment: ""), text: $name)
                    
                    Picker(NSLocalizedString("select_category", comment: ""), selection: $category) {
                        ForEach(Category.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    
                    Toggle(NSLocalizedString("purchased", comment: ""), isOn: $isPurchased)
                }
                
                Section(header: Text(NSLocalizedString("section_notes", comment: ""))) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        shoppingListStore.deleteItem(item)
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text(NSLocalizedString("delete_item", comment: ""))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav_title_edit_item", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "")) {
                        saveItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveItem() {
        let updatedItem = ShoppingItem(
//            id: item.id,
            name: name,
            category: category,
            addedDate: item.addedDate,
            isPurchased: isPurchased,
            notes: notes.isEmpty ? nil : notes
        )
        
        shoppingListStore.updateItem(updatedItem)
        dismiss()
    }
}

#Preview {
    ShoppingListView()
        .environmentObject(ShoppingListStore())
} 
