import SwiftUI
import Foundation

struct ReceiptListView: View {
    @EnvironmentObject var receiptManager: ReceiptManager
    @EnvironmentObject var foodStore: FoodStore
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var receiptImageData: Data? = nil
    @State private var showingProcessing = false
    @State private var receiptToDelete: Models.Receipt? = nil
    @State private var showingDeleteConfirmation = false
    @State private var showingActionSheet = false
    
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
                    
                    if receiptManager.receipts.isEmpty {
                        ContentUnavailableView(
                            NSLocalizedString("no_receipts", comment: ""),
                            systemImage: "doc.text.image",
                            description: Text(NSLocalizedString("add_receipt_description", comment: ""))
                        )
                        .padding(.top, 100)
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("receipts", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 显示选择菜单
                        showingActionSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .actionSheet(isPresented: $showingActionSheet) {
                ActionSheet(
                    title: Text(NSLocalizedString("add_receipt", comment: "")),
                    message: Text(NSLocalizedString("select_add_method", comment: "")),
                    buttons: [
                        .default(Text(NSLocalizedString("take_photo", comment: ""))) {
                            showingCamera = true
                        },
                        .default(Text(NSLocalizedString("choose_from_library", comment: ""))) {
                            showingPhotoLibrary = true
                        },
                        .cancel(Text(NSLocalizedString("cancel", comment: "")))
                    ]
                )
            }
            .sheet(isPresented: $showingCamera) {
                #if os(iOS)
                ImagePickerView(imageData: $receiptImageData, sourceType: .camera, onDismiss: {
                    showingCamera = false
                    if receiptImageData != nil {
                        showingProcessing = true
                    }
                })
                #endif
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                #if os(iOS)
                ImagePickerView(imageData: $receiptImageData, sourceType: .photoLibrary, onDismiss: {
                    showingPhotoLibrary = false
                    if receiptImageData != nil {
                        showingProcessing = true
                    }
                })
                #endif
            }
            .sheet(isPresented: $showingProcessing) {
                if let imageData = receiptImageData {
                    ReceiptProcessingView(imageData: imageData)
                        .onDisappear {
                            // 清除图像数据
                            receiptImageData = nil
                        }
                }
            }
            .confirmationDialog(
                NSLocalizedString("delete_receipt_confirmation", comment: ""),
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                    if let receipt = receiptToDelete {
                        receiptManager.deleteReceipt(receipt)
                        receiptToDelete = nil
                    }
                }
                Button(NSLocalizedString("cancel", comment: ""), role: .cancel) {
                    receiptToDelete = nil
                }
            } message: {
                Text(NSLocalizedString("action_cannot_be_undone", comment: ""))
            }
        }
    }
    
    private var sortedReceipts: [Models.Receipt] {
        // 按添加日期降序排列
        return receiptManager.receipts.sorted { $0.addedDate > $1.addedDate }
    }
}

// 单个小票卡片视图
struct ReceiptCard: View {
    let receipt: Models.Receipt
    let onDeleteTapped: () -> Void
    @EnvironmentObject var receiptManager: ReceiptManager
    @EnvironmentObject var foodStore: FoodStore
    @State private var showingFoodPicker = false
    @State private var showingOCRText = false
    @State private var showingAIAnalysis = false
    @State private var isProcessingOCR = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日期和关联食物
            HStack {
                VStack(alignment: .leading) {
                    Text(formatDate(receipt.addedDate))
                        .font(.headline)
                    
                    if let associatedFoods = foodsForReceipt, !associatedFoods.isEmpty {
                        Text(String(format: NSLocalizedString("associated_foods_count", comment: ""), associatedFoods.count))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(NSLocalizedString("no_related_food", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // OCR按钮
                if receipt.ocrText == nil && !isProcessingOCR {
                    Button(action: {
                        performOCR()
                    }) {
                        Label("OCR", systemImage: "text.viewfinder")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                } else if isProcessingOCR {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.horizontal, 8)
                }
                
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
                                receiptManager.dissociateFoodFromReceipt(foodID: food.id, receiptID: receipt.id)
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
            if let image = receiptManager.loadImage(id: receipt.imageID) {
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
            
            // OCR文本显示（如果有）
            if let ocrText = receipt.ocrText, !ocrText.isEmpty {
                DisclosureGroup(
                    isExpanded: $showingOCRText,
                    content: {
                        Text(ocrText)
                            .font(.footnote)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    },
                    label: {
                        HStack {
                            Image(systemName: "text.viewfinder")
                            Text(NSLocalizedString("ocr_recognition", comment: ""))
                                .font(.subheadline)
                                .bold()
                        }
                    }
                )
                .padding(.top, 8)
            }
            
            // AI分析结果显示（如果有）
            if let aiAnalysisResult = receipt.aiAnalysisResult, !aiAnalysisResult.isEmpty {
                DisclosureGroup(
                    isExpanded: $showingAIAnalysis,
                    content: {
                        Text(aiAnalysisResult)
                            .font(.footnote)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                    },
                    label: {
                        HStack {
                            Image(systemName: "brain")
                            Text(NSLocalizedString("ai_analysis", comment: ""))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.blue)
                        }
                    }
                )
                .padding(.top, 8)
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
    
    // 执行OCR识别
    private func performOCR() {
        isProcessingOCR = true
        
        // 调用ReceiptManager的OCR更新方法
        receiptManager.updateReceiptOCR(for: receipt.id)
        
        // 模拟OCR处理完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isProcessingOCR = false
        }
    }
    
    // 获取与小票关联的食品
    private var foodsForReceipt: [FoodItem]? {
        let ids = receipt.foodItemIDs
        if ids.isEmpty { return nil }
        
        // 筛选出存在的食品
        return foodStore.foodItems.filter { ids.contains($0.id) }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// 食品选择器视图
struct FoodPickerView: View {
    let receipt: Models.Receipt
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var receiptManager: ReceiptManager
    
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
                    Text(NSLocalizedString("no_food_to_select", comment: ""))
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .navigationTitle(NSLocalizedString("select_related_food", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func toggleFoodSelection(_ food: Models.FoodItem) {
        // 如果已经关联，则解除关联
        if receipt.foodItemIDs.contains(food.id) {
            receiptManager.dissociateFoodFromReceipt(foodID: food.id, receiptID: receipt.id)
        } else if receipt.foodItemID == food.id {
            // 处理传统的单一关联
            receiptManager.dissociateFoodFromReceipt(foodID: food.id, receiptID: receipt.id)
        } else {
            // 否则添加关联
            receiptManager.associateFoodWithReceipt(foodID: food.id, receiptID: receipt.id)
        }
    }
}

#if DEBUG
struct ReceiptListView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptListView()
            .environmentObject(ReceiptManager.shared)
            .environmentObject(FoodStore())
    }
}
#endif 
