import SwiftUI

// We need to use the global type definitions
// No additional imports needed since all required types are exposed through Globals.swift

struct FoodSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodStore: FoodStore
    
    let aiAnalysisResult: String
    let receiptID: UUID?
    let receiptManager: ReceiptManager
    
    // 更新后的数据结构，包含解析后的食品名称、类别和保质期
    struct ParsedFood {
        let name: String
        let category: String
        let expirationDays: Int
        
        // 将类别字符串转换为Models.Category枚举
        var categoryEnum: Models.Category {
            switch category {
            case "肉类": return .meat
            case "蔬菜": return .vegetable
            case "水果": return .fruit
            case "海鲜": return .seafood
            case "乳制品": return .dairy
            case "零食": return .snack
            case "饮料": return .beverage
            case "调味品": return .condiment
            case "主食", "谷物": return .grain
            default: return .other
            }
        }
    }
    
    @State private var parsedFoodItems: [ParsedFood] = []
    @State private var selectedFoodItems: Set<String> = Set()
    @State private var isAddingFood: Bool = false
    @State private var showSuccessMessage: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("从小票中识别到的商品")) {
                        ForEach(parsedFoodItems, id: \.name) { foodItem in
                            FoodItemSelectionRow(
                                foodName: "\(foodItem.name) (\(foodItem.category), \(foodItem.expirationDays)天)",
                                isSelected: selectedFoodItems.contains(foodItem.name),
                                onToggle: {
                                    toggleFoodSelection(foodItem.name)
                                }
                            )
                        }
                    }
                }
                
                VStack(spacing: 12) {
                    if showSuccessMessage {
                        Text("已成功添加\(selectedFoodItems.count)个商品")
                            .foregroundColor(.green)
                            .padding()
                    }
                    
                    Button(action: {
                        addSelectedFoodItems()
                    }) {
                        HStack {
                            Text("添加\(selectedFoodItems.count)个选中商品")
                            
                            if isAddingFood {
                                Spacer()
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                        .padding()
                        .background(selectedFoodItems.isEmpty ? Color.gray : Color.green)
                        .cornerRadius(10)
                    }
                    .disabled(selectedFoodItems.isEmpty || isAddingFood)
                    .padding(.horizontal)
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("返回")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("选择食品")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                parseFoodItemsFromAIResult()
            }
        }
    }
    
    // 从AI分析结果中解析食品项
    private func parseFoodItemsFromAIResult() {
        // 将AI分析结果按行分割
        let lines = aiAnalysisResult.split(separator: "\n")
        
        // 过滤掉空行和可能的标题行，解析格式化数据
        var parsedItems: [ParsedFood] = []
        
        for line in lines {
            let trimmedLine = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 忽略空行和可能的标题行
            if trimmedLine.isEmpty || 
               trimmedLine.lowercased().contains("食品名称") ||
               trimmedLine.lowercased().contains("格式") {
                continue
            }
            
            // 按"|"分割字段
            let components = trimmedLine.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            
            if components.count >= 3 {
                let name = components[0]
                let category = components[1]
                let expirationDays = Int(components[2]) ?? 7 // 默认7天，如果无法解析
                
                parsedItems.append(ParsedFood(
                    name: name,
                    category: category,
                    expirationDays: expirationDays
                ))
            } else if !trimmedLine.isEmpty {
                // 如果格式不匹配但不为空，添加基本信息
                parsedItems.append(ParsedFood(
                    name: trimmedLine,
                    category: "其他",
                    expirationDays: 7
                ))
            }
        }
        
        self.parsedFoodItems = parsedItems
    }
    
    // 切换食品选择状态
    private func toggleFoodSelection(_ foodName: String) {
        if selectedFoodItems.contains(foodName) {
            selectedFoodItems.remove(foodName)
        } else {
            selectedFoodItems.insert(foodName)
        }
    }
    
    // 添加选中的食品项到食品清单
    private func addSelectedFoodItems() {
        isAddingFood = true
        
        // 创建一个延迟，以展示加载状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for foodName in selectedFoodItems {
                // 查找匹配的解析食品项
                if let parsedFood = parsedFoodItems.first(where: { $0.name == foodName }) {
                    // 根据保质期天数计算过期日期
                    let expirationDate = Calendar.current.date(byAdding: .day, value: parsedFood.expirationDays, to: Date()) ?? Date().addingTimeInterval(7 * 24 * 60 * 60)
                    
                    let newFood = Models.FoodItem(
                        name: parsedFood.name,
                        expirationDate: expirationDate,
                        category: parsedFood.categoryEnum,  // 使用转换后的枚举类型
                        tags: [],  // 暂无标签
                        addedDate: Date()  // 设置购买日期为当前日期
                    )
                    
                    // 添加食品到食品清单
                    foodStore.addFood(newFood)
                    
                    // 将食品与当前小票关联
                    if let receiptID = receiptID {
                        receiptManager.associateFoodWithReceipt(foodID: newFood.id, receiptID: receiptID)
                    }
                }
            }
            
            // 显示成功消息
            isAddingFood = false
            showSuccessMessage = true
            
            // 短暂延迟后自动关闭视图
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }
}

// 食品选择行视图
struct FoodItemSelectionRow: View {
    let foodName: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Text(foodName)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
        }
    }
}

#if DEBUG
struct FoodSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        FoodSelectionView(
            aiAnalysisResult: "香蕉|水果|7\n苹果|水果|14\n牛奶|乳制品|10",
            receiptID: UUID(),
            receiptManager: ReceiptManager.shared
        )
        .environmentObject(FoodStore())
    }
}
#endif 