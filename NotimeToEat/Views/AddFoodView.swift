import SwiftUI
import PhotosUI
import Foundation

// Fix UIKit import for iOS
#if os(iOS)
import UIKit
#endif

// The app uses these typealias declarations from Globals.swift
// FoodStore, Category, Tag, and Models are globally defined

// 扩展建议项目，包含更多信息
struct FoodSuggestion: Identifiable, Hashable {
    let id = UUID()
    let displayName: String  // 用于显示的名称（可能包含中英文）
    let value: String        // 实际值（将被填入文本框）
    let category: String?    // 分类（如果有）
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
    }
    
    static func == (lhs: FoodSuggestion, rhs: FoodSuggestion) -> Bool {
        return lhs.displayName == rhs.displayName
    }
}

struct FoodNameInputView: View {
    @Binding var text: String
    @Binding var suggestedCategory: Models.Category
    @EnvironmentObject var foodStore: Services.FoodStore
    @EnvironmentObject var foodHistoryStore: Services.FoodHistoryStore
    @State private var showSuggestions = false
    @State private var suggestions: [FoodSuggestion] = []
    @State private var isFocused = false
    @State private var foodCategoryMapping: [String: String] = [:]
    
    // 获取食物数据库
    private let foodDatabase = CoreDataFoodDatabase.shared
    
    // Add public initializer
    init(text: Binding<String>, suggestedCategory: Binding<Models.Category>) {
        self._text = text
        self._suggestedCategory = suggestedCategory
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(NSLocalizedString("food_name", comment: ""), text: $text, onEditingChanged: { editing in
                self.isFocused = editing
                updateSuggestions()
                if editing {
                    showSuggestions = !text.isEmpty && !suggestions.isEmpty
                }
            })
            
            .onChange(of: text) { oldValue, newValue in
                updateSuggestions()
                showSuggestions = isFocused && !newValue.isEmpty && !suggestions.isEmpty
            }
            
            if showSuggestions {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions) { suggestion in
                            Button(action: {
                                // 修改此处，根据显示名称是否包含中文来决定使用哪个值
                                if isChineseInput(suggestion.displayName) {
                                    // 如果是中文显示名称，使用value（中文）
                                    self.text = suggestion.value
                                } else {
                                    // 如果是英文显示名称，直接使用displayName（英文）
                                    self.text = suggestion.displayName
                                }
                                self.showSuggestions = false
                                
                                // 无论选择哪种语言的名称，都尝试推荐分类
                                suggestCategoryForFood(suggestion.value)
                            }) {
                                HStack {
                                    Text(suggestion.displayName)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    if let categoryString = suggestion.category, 
                                       let category = Models.Category.allCases.first(where: { $0.rawValue == categoryString }) {
                                        // 显示分类图标
                                        Image(systemName: category.iconName)
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }
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
    
    // 检查字符串是否包含中文字符
    private func isChineseInput(_ text: String) -> Bool {
        // 简单判断是否包含中文字符的方法
        let pattern = "[\\u4e00-\\u9fa5]"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            return !matches.isEmpty
        }
        return false
    }

    private func updateSuggestions() {
        guard !text.isEmpty else {
            suggestions = []
            return
        }
        
        // 判断用户输入是中文还是英文
        let isChineseMode = isChineseInput(text)
        print("DEBUG: Input mode is \(isChineseMode ? "Chinese" : "English") for input: '\(text)'")
        
        var allSuggestions = [FoodSuggestion]()
        
        if isChineseMode {
            // 中文输入模式 - 搜索中文名称
            // 从数据库获取所有食物
            let databaseFoods = foodDatabase.allFoodNames
            print("DEBUG: Retrieved \(databaseFoods.count) foods from database")
            
            // 处理中文食物名称
            for foodName in databaseFoods {
                // 尝试匹配中文名称
                if isChineseInput(foodName) && foodName.localizedCaseInsensitiveContains(text) {
                    let category = foodDatabase.getCategoryForFood(foodName)
                    
                    let suggestion = FoodSuggestion(
                        displayName: foodName, // 纯中文显示
                        value: foodName,
                        category: category
                    )
                    allSuggestions.append(suggestion)
                    
                    // 记录分类映射
                    if let category = category {
                        foodCategoryMapping[foodName] = category
                    }
                }
            }
            
            // 添加来自当前食物库的中文名称
            foodStore.foodItems.forEach { item in
                if item.name.localizedCaseInsensitiveContains(text) {
                    let suggestion = FoodSuggestion(
                        displayName: item.name,
                        value: item.name,
                        category: item.category.rawValue
                    )
                    allSuggestions.append(suggestion)
                    foodCategoryMapping[item.name] = item.category.rawValue
                }
            }
            
            // 添加来自历史记录的中文名称
            foodHistoryStore.historyEntries.forEach { entry in
                if entry.foodName.localizedCaseInsensitiveContains(text) {
                    let suggestion = FoodSuggestion(
                        displayName: entry.foodName,
                        value: entry.foodName,
                        category: entry.category.rawValue
                    )
                    allSuggestions.append(suggestion)
                    foodCategoryMapping[entry.foodName] = entry.category.rawValue
                }
            }
        } else {
            // 英文输入模式 - 搜索英文名称
            // 获取所有英文食物名称
            let englishFoodNames = foodDatabase.allEnglishFoodNames
            print("DEBUG: Retrieved \(englishFoodNames.count) English food names from database")
            
            // 处理英文食物名称 - 只匹配前缀
            for englishName in englishFoodNames {
                // 只保留以输入文本开头的项目
                if englishName.lowercased().hasPrefix(text.lowercased()) {
                    // 找到对应的中文名和分类
                    let chineseName = foodDatabase.getChineseNameByEnglishName(englishName)
                    let category = chineseName != nil ? 
                                    foodDatabase.getCategoryForFood(chineseName!) : 
                                    nil
                    
                    let suggestion = FoodSuggestion(
                        displayName: englishName, // 纯英文显示
                        value: chineseName ?? englishName,  // 存储中文值或英文值
                        category: category
                    )
                    allSuggestions.append(suggestion)
                    
                    // 记录分类映射 - 同时记录英文名称和中文名称的映射
                    if let category = category {
                        if let chineseName = chineseName {
                            foodCategoryMapping[chineseName] = category
                        }
                        foodCategoryMapping[englishName] = category // 添加英文名称的映射
                    }
                }
            }
        }
        
        // 去重并按显示名称排序
        let uniqueSuggestions = Array(Set(allSuggestions))
        
        // 改进的排序算法，优化字母排序
        suggestions = uniqueSuggestions.sorted { (a, b) -> Bool in
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
        
        // 限制建议数量
        if suggestions.count > 15 {
            suggestions = Array(suggestions.prefix(15))
        }
        
        print("DEBUG: Generated \(suggestions.count) suggestions for input: \(text)")
    }
    
    // 为食物名称获取分类（如果可能）
    private func getCategoryForFood(_ foodName: String) -> String? {
        // 从CoreDataFoodDatabase中查询食物的分类
        let categoryFromDB = foodDatabase.getCategoryForFood(foodName)
        if categoryFromDB != nil {
            return categoryFromDB
        }
        
        // 如果数据库没有，就从映射中获取
        return foodCategoryMapping[foodName]
    }
    
    // 根据食物名称推荐分类
    private func suggestCategoryForFood(_ foodName: String) {
        // 首先尝试直接从映射中获取
        if let categoryString = foodCategoryMapping[foodName] {
            // 将字符串转换为Models.Category
            if let category = Models.Category.allCases.first(where: { $0.rawValue == categoryString }) {
                suggestedCategory = category
                print("DEBUG: Suggesting category \(category) for food \(foodName)")
                return
            }
        }
        
        // 如果是英文名称，尝试查找对应的中文名称以获取分类
        if !isChineseInput(foodName) {
            if let chineseName = foodDatabase.getChineseNameByEnglishName(foodName),
               let categoryString = foodDatabase.getCategoryForFood(chineseName) {
                if let category = Models.Category.allCases.first(where: { $0.rawValue == categoryString }) {
                    suggestedCategory = category
                    print("DEBUG: Suggesting category \(category) for English food \(foodName)")
                    return
                }
            }
        }
        
        // 最后尝试直接从数据库查询
        if let categoryString = foodDatabase.getCategoryForFood(foodName) {
            if let category = Models.Category.allCases.first(where: { $0.rawValue == categoryString }) {
                suggestedCategory = category
                print("DEBUG: Suggesting category \(category) for food \(foodName) from database")
            }
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
                    let _ = print("DEBUG: Current category for food input: \(category.rawValue)")
                    FoodNameInputView(text: $name, suggestedCategory: $category)
                    
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
