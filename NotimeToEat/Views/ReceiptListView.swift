import SwiftUI
import Foundation

struct ReceiptListView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var foodStore: FoodStore
    @State private var showingAddReceipt = false
    @State private var receiptToDelete: Models.Receipt? = nil
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 按时间降序显示所有小票
                    ForEach(sortedReceipts) { receipt in
                        ReceiptCard(receipt: receipt, onDeleteTapped: {
                            receiptToDelete = receipt
                            showingDeleteConfirmation = true
                        })
                    }
                    
                    if receiptStore.receipts.isEmpty {
                        ContentUnavailableView(
                            "暂无购物小票",
                            systemImage: "doc.text.image",
                            description: Text("点击右上角添加按钮上传小票")
                        )
                        .padding(.top, 100)
                    }
                }
                .padding()
            }
            .navigationTitle("购物小票")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddReceipt = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddReceipt) {
                AddReceiptView()
            }
            .confirmationDialog(
                "确定要删除这张小票吗？",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    if let receipt = receiptToDelete {
                        receiptStore.deleteReceipt(receipt)
                        receiptToDelete = nil
                    }
                }
                Button("取消", role: .cancel) {
                    receiptToDelete = nil
                }
            } message: {
                Text("此操作不可撤销")
            }
        }
    }
    
    private var sortedReceipts: [Models.Receipt] {
        // 按添加日期降序排列
        return receiptStore.receipts.sorted { $0.addedDate > $1.addedDate }
    }
}

// 单个小票卡片视图
struct ReceiptCard: View {
    let receipt: Models.Receipt
    let onDeleteTapped: () -> Void
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var foodStore: FoodStore
    @State private var showingFoodPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日期和关联食物
            HStack {
                VStack(alignment: .leading) {
                    Text(formatDate(receipt.addedDate))
                        .font(.headline)
                    
                    if let associatedFoods = foodsForReceipt, !associatedFoods.isEmpty {
                        Text("关联食品：\(associatedFoods.count)项")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("暂无关联食品")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 添加关联食品按钮
                Button(action: {
                    showingFoodPicker = true
                }) {
                    Image(systemName: "link.badge.plus")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 4)
                
                // 删除按钮
                Button(action: onDeleteTapped) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // 关联的食品列表（如果有）
            if let foods = foodsForReceipt, !foods.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(foods) { food in
                        HStack {
                            Text(food.name)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // 移除关联按钮
                            Button(action: {
                                receiptStore.dissociateFoodFromReceipt(foodID: food.id, receiptID: receipt.id)
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
            
            // 小票图片
            if let image = receiptStore.loadImage(id: receipt.imageID) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(10)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .sheet(isPresented: $showingFoodPicker) {
            FoodPickerView(receipt: receipt)
        }
    }
    
    // 获取与小票关联的食物
    private var foodsForReceipt: [Models.FoodItem]? {
        var foods: [Models.FoodItem] = []
        
        // 添加传统的单一关联（向后兼容）
        if let foodItemID = receipt.foodItemID,
           let food = foodStore.foodItems.first(where: { $0.id == foodItemID }) {
            foods.append(food)
        }
        
        // 添加新的多重关联
        for foodID in receipt.foodItemIDs {
            if let food = foodStore.foodItems.first(where: { $0.id == foodID }),
               !foods.contains(where: { $0.id == food.id }) {
                foods.append(food)
            }
        }
        
        return foods.isEmpty ? nil : foods
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// 食品选择器视图
struct FoodPickerView: View {
    let receipt: Models.Receipt
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var receiptStore: ReceiptStore
    
    var body: some View {
        NavigationView {
            List {
                ForEach(foodStore.foodItems) { food in
                    HStack {
                        Text(food.name)
                        Spacer()
                        if receipt.foodItemIDs.contains(food.id) || receipt.foodItemID == food.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleFoodSelection(food)
                    }
                }
                
                if foodStore.foodItems.isEmpty {
                    Text("暂无食品，请先添加食品")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .navigationTitle("选择关联食品")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleFoodSelection(_ food: Models.FoodItem) {
        // 如果已经关联，则解除关联
        if receipt.foodItemIDs.contains(food.id) {
            receiptStore.dissociateFoodFromReceipt(foodID: food.id, receiptID: receipt.id)
        } else if receipt.foodItemID == food.id {
            // 处理传统的单一关联
            receiptStore.dissociateFoodFromReceipt(foodID: food.id, receiptID: receipt.id)
        } else {
            // 否则添加关联
            receiptStore.associateFoodWithReceipt(foodID: food.id, receiptID: receipt.id)
        }
    }
}

#if DEBUG
struct ReceiptListView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptListView()
            .environmentObject(ReceiptStore())
            .environmentObject(FoodStore())
    }
}
#endif 
