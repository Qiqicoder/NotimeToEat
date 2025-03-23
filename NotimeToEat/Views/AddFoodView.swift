import SwiftUI
import PhotosUI
import Foundation

// The app uses these typealias declarations from Globals.swift
// FoodStore, Category, Tag, and Models are globally defined
// ReceiptManager is now used instead of ReceiptStore

struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var receiptManager: ReceiptManager
    
    @State private var name = ""
    @State private var expirationDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 默认一周后过期
    @State private var category = Category.other
    @State private var selectedTags: Set<Tag> = []
    @State private var notes = ""
    @State private var receiptImageData: Data? = nil
    
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
            }
            .navigationTitle("添加食物")
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
        let newFood = Models.FoodItem(
            name: name,
            expirationDate: expirationDate,
            category: category,
            tags: Array(selectedTags),
            addedDate: Date(),
            notes: notes.isEmpty ? nil : notes
        )
        
        foodStore.addFood(newFood)
        
        // 如果有小票图片，保存到ReceiptManager
        if let imageData = receiptImageData {
            receiptManager.addReceiptWithOCR(imageData: imageData, foodItemID: newFood.id)
        }
        
        dismiss()
    }
}

struct TagButton: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: tag.iconName)
                Text(tag.rawValue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? tag.color.opacity(0.2) : Color.gray.opacity(0.1))
            )
            .foregroundColor(isSelected ? tag.color : .gray)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? tag.color : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct AddFoodView_Previews: PreviewProvider {
    static var previews: some View {
        AddFoodView()
            .environmentObject(FoodStore())
            .environmentObject(ReceiptManager.shared)
    }
} 
