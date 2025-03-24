import SwiftUI
import PhotosUI
import Foundation
import UIKit

// We need to explicitly import the ReceiptManager since it's not in Globals.swift
import NotimeToEat

// The app uses these typealias declarations from Globals.swift
// FoodStore, Category, Tag, and Models are globally defined

struct FoodNameInputView: View {
    @Binding var text: String
    @EnvironmentObject var foodStore: Services.FoodStore
    @EnvironmentObject var foodHistoryStore: Services.FoodHistoryStore
    @State private var showSuggestions = false
    @State private var suggestions: [String] = []
    @State private var isFocused = false
    var category: Models.Category? = nil  // Optional category parameter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(NSLocalizedString("food_name", comment: ""), text: $text, onEditingChanged: { editing in
                self.isFocused = editing
                updateSuggestions()
                if editing {
                    showSuggestions = !text.isEmpty && !suggestions.isEmpty
                }
            })
            .onChange(of: text) { newValue in
                updateSuggestions()
                showSuggestions = isFocused && !newValue.isEmpty && !suggestions.isEmpty
            }
            
            if showSuggestions {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: {
                                self.text = suggestion
                                self.showSuggestions = false
                            }) {
                                Text(suggestion)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .transition(.opacity)
            }
        }
    }
    
    private func updateSuggestions() {
        guard !text.isEmpty else {
            suggestions = []
            return
        }
        
        // Get unique food names from multiple sources
        var uniqueFoodNames = Set<String>()
        var categorySpecificNames = Set<String>()
        
        // 1. Add names from current food inventory
        foodStore.foodItems.forEach { item in
            if let selectedCategory = category, item.category == selectedCategory {
                categorySpecificNames.insert(item.name)
            } else {
                uniqueFoodNames.insert(item.name)
            }
        }
        
        // 2. Add names from food history entries
        foodHistoryStore.historyEntries.forEach { entry in
            if let selectedCategory = category, entry.category == selectedCategory {
                categorySpecificNames.insert(entry.foodName)
            } else {
                uniqueFoodNames.insert(entry.foodName)
            }
        }
        
        // 3. Add sample food names
        Models.FoodItem.sampleItems.forEach { item in
            if let selectedCategory = category, item.category == selectedCategory {
                categorySpecificNames.insert(item.name)
            } else {
                uniqueFoodNames.insert(item.name)
            }
        }
        
        // 4. Add common foods from our database
        if let selectedCategory = category {
            // Add foods from the selected category
            CommonFoodDatabase.foods(for: selectedCategory).forEach { food in
                categorySpecificNames.insert(food)
            }
        } else {
            // Add all common foods
            CommonFoodDatabase.allCommonFoods.forEach { food in
                uniqueFoodNames.insert(food)
            }
        }
        
        // Filter and sort suggestions that match the current text
        var categorySuggestions = Array(categorySpecificNames)
            .filter { $0.localizedCaseInsensitiveContains(text) && $0 != text }
            .sorted()
        
        var generalSuggestions = Array(uniqueFoodNames)
            .filter { $0.localizedCaseInsensitiveContains(text) && $0 != text }
            .sorted()
        
        // Prioritize category-specific suggestions
        suggestions = categorySuggestions + generalSuggestions
        
        // Limit the number of suggestions
        if suggestions.count > 15 {
            suggestions = Array(suggestions.prefix(15))
        }
    }
}

struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodStore: Services.FoodStore
    @EnvironmentObject var receiptManager: ReceiptManager
    @EnvironmentObject var foodHistoryStore: Services.FoodHistoryStore
    
    @State private var name = ""
    @State private var expirationDate = Date().addingTimeInterval(7 * 24 * 60 * 60) // 默认一周后过期
    @State private var category = Models.Category.other
    @State private var selectedTags: Set<Models.Tag> = []
    @State private var notes = ""
    @State private var receiptImageData: Data? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("section_basic_info", comment: ""))) {
                    FoodNameInputView(text: $name, category: category)
                    
                    DatePicker(NSLocalizedString("expiration_date", comment: ""), selection: $expirationDate, displayedComponents: [.date])
                }
                
                Section(header: Text(NSLocalizedString("section_category", comment: ""))) {
                    Picker(NSLocalizedString("select_category", comment: ""), selection: $category) {
                        ForEach(Models.Category.allCases, id: \.self) { category in
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
                            ForEach(Models.Tag.allCases, id: \.self) { tag in
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
            }
            .navigationTitle(NSLocalizedString("nav_title_add_food", comment: ""))
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
    
    private func toggleTag(_ tag: Models.Tag) {
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
    let tag: Models.Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: tag.iconName)
                Text(NSLocalizedString(tag.displayName, comment: ""))
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
            .environmentObject(Services.FoodStore())
            .environmentObject(ReceiptManager.shared)
            .environmentObject(Services.FoodHistoryStore())
    }
}
