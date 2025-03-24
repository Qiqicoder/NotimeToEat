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
                Section(header: Text(NSLocalizedString("section_basic_info", comment: ""))) {
                    TextField(NSLocalizedString("food_name", comment: ""), text: $name)
                    
                    DatePicker(NSLocalizedString("expiration_date", comment: ""), selection: $expirationDate, displayedComponents: [.date])
                }
                
                Section(header: Text(NSLocalizedString("section_category", comment: ""))) {
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
                
                Section(header: Text(NSLocalizedString("section_tags", comment: ""))) {
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
                
                Section(header: Text(NSLocalizedString("section_notes", comment: ""))) {
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
                            Text(NSLocalizedString("delete_food", comment: ""))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav_title_edit_food", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "")) {
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