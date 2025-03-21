import SwiftUI

struct EditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodStore: FoodStore
    
    let item: FoodItem
    
    @State private var name: String
    @State private var expirationDate: Date
    @State private var category: Category
    @State private var selectedTags: Set<Tag>
    @State private var notes: String
    
    init(item: FoodItem) {
        self.item = item
        
        // 初始化状态变量
        _name = State(initialValue: item.name)
        _expirationDate = State(initialValue: item.expirationDate)
        _category = State(initialValue: item.category)
        _selectedTags = State(initialValue: Set(item.tags))
        _notes = State(initialValue: item.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本信息")) {
                    TextField("食物名称", text: $name)
                    
                    DatePicker("过期日期", selection: $expirationDate, displayedComponents: [.date])
                }
                
                Section(header: Text("分类")) {
                    Picker("选择分类", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section(header: Text("标签")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Tag.allCases, id: \.self) { tag in
                                TagButton(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag),
                                    action: {
                                        toggleTag(tag)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("备注")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                Section {
                    Button(role: .destructive, action: {
                        foodStore.deleteFood(item)
                        dismiss()
                    }) {
                        HStack {
                            Spacer()
                            Text("删除食物")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("编辑食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveFood()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func toggleTag(_ tag: Tag) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }
    
    private func saveFood() {
        let updatedFood = FoodItem(
            id: item.id,
            name: name,
            expirationDate: expirationDate,
            category: category,
            tags: Array(selectedTags),
            addedDate: item.addedDate,
            notes: notes.isEmpty ? nil : notes
        )
        
        foodStore.updateFood(updatedFood)
        dismiss()
    }
}

struct EditFoodView_Previews: PreviewProvider {
    static var previews: some View {
        EditFoodView(item: FoodItem.sampleItems[0])
            .environmentObject(FoodStore())
    }
} 