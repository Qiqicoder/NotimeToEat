import SwiftUI
import PhotosUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// The app uses global typealias declarations from Globals.swift
// FoodStore, PhotoPicker, AIService are globally defined
// ReceiptManager is now used instead of ReceiptStore

struct AddReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var receiptManager: ReceiptManager
    @EnvironmentObject var foodStore: FoodStore
    @State private var receiptImageData: Data? = nil
    @State private var enableOCR: Bool = true
    @State private var isProcessingOCR: Bool = false
    @State private var useAIAnalysis: Bool = true
    @State private var aiAnalysisResult: String = ""
    @State private var isProcessingAI: Bool = false
    @State private var ocrExtractedText: String = ""
    @State private var isReceiptSaved: Bool = false
    @State private var savedReceiptID: UUID? = nil
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingActionSheet = false
    
    // 导航状态
    @State private var showingFoodSelection: Bool = false
    
    // 从配置文件加载API密钥
    private let aiService = Services.AIService(apiKey: Services.APIKeys.deepseekAPIKey)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("shopping_receipt_image", comment: ""))) {
                    #if os(iOS)
                    VStack {
                        if let imageData = receiptImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                                
                            Button(action: {
                                self.receiptImageData = nil
                            }) {
                                Label(NSLocalizedString("delete_image", comment: ""), systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                            .padding(.top, 8)
                        } else {
                            Button(action: {
                                showingActionSheet = true
                            }) {
                                Label(NSLocalizedString("add_receipt_image", comment: ""), systemImage: "camera")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
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
                        }
                    }
                    .sheet(isPresented: $showingCamera) {
                        ImagePickerView(imageData: $receiptImageData, sourceType: .camera, onDismiss: {
                            showingCamera = false
                        })
                    }
                    .sheet(isPresented: $showingPhotoLibrary) {
                        ImagePickerView(imageData: $receiptImageData, sourceType: .photoLibrary, onDismiss: {
                            showingPhotoLibrary = false
                        })
                    }
                    #elseif os(macOS)
                    Text("照片拍摄功能仅在iOS设备上可用")
                        .foregroundColor(.secondary)
                    #endif
                }
                
                Section(header: Text(NSLocalizedString("processing_options", comment: ""))) {
                    Toggle(NSLocalizedString("ocr_recognition", comment: ""), isOn: $enableOCR)
                    
                    Toggle(NSLocalizedString("ai_analysis", comment: ""), isOn: $useAIAnalysis)
                        .disabled(!enableOCR)
                    
                    if !enableOCR && useAIAnalysis {
                        Text(NSLocalizedString("ai_analysis_requires_ocr", comment: ""))
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if receiptImageData != nil {
                    Section {
                        Button(action: {
                            saveReceipt()
                        }) {
                            HStack {
                                Text(useAIAnalysis ? NSLocalizedString("save_and_analyze_receipt", comment: "") : NSLocalizedString("save_receipt", comment: ""))
                                
                                if isProcessingOCR || isProcessingAI {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .disabled(isProcessingOCR || isProcessingAI)
                    }
                }
                
                if isReceiptSaved && useAIAnalysis && !aiAnalysisResult.isEmpty {
                    Section(header: Text(NSLocalizedString("ai_analysis_results", comment: ""))) {
                        Text(aiAnalysisResult)
                            .font(.body)
                            .padding(.vertical, 4)
                        
                        Button(action: {
                            showingFoodSelection = true
                        }) {
                            Text(NSLocalizedString("select_food_to_add", comment: ""))
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 4)
                        .sheet(isPresented: $showingFoodSelection) {
                            FoodSelectionView(
                                aiAnalysisResult: aiAnalysisResult,
                                receiptID: savedReceiptID,
                                receiptManager: receiptManager
                            )
                            .environmentObject(foodStore)
                        }
                    }
                }
                
                if isReceiptSaved && isProcessingAI {
                    Section {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text(NSLocalizedString("ai_analysis_in_progress", comment: ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                    }
                } else if isReceiptSaved && !isProcessingAI && useAIAnalysis && !aiAnalysisResult.isEmpty {
                    Section {
                        Button(action: {
                            dismiss()
                        }) {
                            Text(NSLocalizedString("done", comment: ""))
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("add_receipt", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveReceipt() {
        guard let imageData = receiptImageData else { return }
        
        // 使用ReceiptManager添加小票
        let receiptID = receiptManager.addReceiptWithoutFood(imageData: imageData, performOCR: enableOCR)
        
        // 记录保存状态和ID
        isReceiptSaved = true
        savedReceiptID = receiptID
        
        // 如果启用了AI分析，则发送OCR文本进行分析
        if useAIAnalysis, enableOCR {
            performAIAnalysis(receiptID: receiptID)
        }
    }
    
    // 执行AI分析
    private func performAIAnalysis(receiptID: UUID) {
        isProcessingAI = true
        
        // 短暂延迟以等待OCR完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // 假设OCR已完成，获取文本
            if let receipt = receiptManager.getReceipt(id: receiptID),
               let ocrText = receipt.ocrText {
                
                // 使用AI服务分析文本
                self.aiService.analyzeReceiptText(ocrText) { result in
                    self.isProcessingAI = false
                    
                    if let analysisResult = result {
                        // 更新AI分析结果
                        self.aiAnalysisResult = analysisResult
                        // 将结果保存到小票
                        receiptManager.updateReceiptAIAnalysis(id: receiptID, result: analysisResult)
                    }
                }
            } else {
                // OCR文本不可用
                self.isProcessingAI = false
            }
        }
    }
}

#if DEBUG
struct AddReceiptView_Previews: PreviewProvider {
    static var previews: some View {
        AddReceiptView()
            .environmentObject(FoodStore())
            .environmentObject(ReceiptManager.shared)
    }
}
#endif
