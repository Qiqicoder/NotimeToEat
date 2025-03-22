import SwiftUI

// 导入全局类型定义
// FoodStore, ReceiptStore, Models.FoodItem等全局类型定义在Globals.swift中

struct FoodSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodStore: FoodStore
    
    let aiAnalysisResult: String
    let receiptID: UUID?
    let receiptStore: ReceiptStore
    
    @State private var parsedFoodItems: [String] = []
    @State private var selectedFoodItems: Set<String> = Set()
    @State private var isAddingFood: Bool = false
    @State private var showSuccessMessage: Bool = false
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section(header: Text("从小票中识别到的商品")) {
                        ForEach(parsedFoodItems, id: \.self) { foodItem in
                            FoodItemSelectionRow(
                                foodName: foodItem,
                                isSelected: selectedFoodItems.contains(foodItem),
                                onToggle: {
                                    toggleFoodSelection(foodItem)
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
        
        // 过滤掉空行和可能的标题行
        parsedFoodItems = lines
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.lowercased().contains("food:") && !$0.lowercased().contains("food") }
            // 如果行包含价格信息，只保留商品名称
            .map { line -> String in
                if let priceRange = line.range(of: #"\d+(\.\d+)?(元|￥|¥|$)?"#, options: .regularExpression) {
                    return String(line[..<priceRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return line
            }
    }
    
    // 切换食品选择状态
    private func toggleFoodSelection(_ foodItem: String) {
        if selectedFoodItems.contains(foodItem) {
            selectedFoodItems.remove(foodItem)
        } else {
            selectedFoodItems.insert(foodItem)
        }
    }
    
    // 添加选中的食品项到食品清单
    private func addSelectedFoodItems() {
        isAddingFood = true
        
        // 创建一个延迟，以展示加载状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            for foodItem in selectedFoodItems {
                let newFood = Models.FoodItem(
                    name: foodItem,
                    expirationDate: Date().addingTimeInterval(7 * 24 * 60 * 60), // 默认一周后过期
                    category: Models.Category.other,  // 默认分类为"其他"
                    tags: [],  // 暂无标签
                    addedDate: Date()  // 设置购买日期为当前日期
                )
                
                // 添加食品到食品清单
                foodStore.addFood(newFood)
                
                // 将食品与当前小票关联
                if let receiptID = receiptID {
                    receiptStore.associateFoodWithReceipt(foodID: newFood.id, receiptID: receiptID)
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
            aiAnalysisResult: "香蕉\n苹果\n牛奶",
            receiptID: UUID(),
            receiptStore: ReceiptStore()
        )
        .environmentObject(FoodStore())
    }
}
#endif 