import SwiftUI
import PhotosUI
import Foundation

// The app uses global typealias declarations from Globals.swift
// FoodStore, PhotoPicker, AIService are globally defined
// ReceiptManager is now used instead of ReceiptStore

struct AddReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var receiptManager: ReceiptManager
    @EnvironmentObject var foodStore: FoodStore
    @State private var receiptImageData: Data? = nil
    @State private var enableOCR: Bool = false
    @State private var isProcessingOCR: Bool = false
    @State private var useAIAnalysis: Bool = false
    @State private var aiAnalysisResult: String = ""
    @State private var isProcessingAI: Bool = false
    @State private var ocrExtractedText: String = ""
    @State private var isReceiptSaved: Bool = false
    @State private var savedReceiptID: UUID? = nil
    
    // 导航状态
    @State private var showingFoodSelection: Bool = false
    
    // 从配置文件加载API密钥
    private let aiService = Services.AIService(apiKey: Services.APIKeys.deepseekAPIKey)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("购物小票图片")) {
                    PhotoPicker(imageData: $receiptImageData)
                }
                
                Section(header: Text("OCR文本识别")) {
                    Toggle("启用OCR文本识别", isOn: $enableOCR)
                    
                    if enableOCR {
                        Text("系统将自动识别小票上的文字")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("AI分析")) {
                    Toggle("使用AI分析小票", isOn: $useAIAnalysis)
                    
                    if useAIAnalysis && !aiAnalysisResult.isEmpty {
                        // 显示AI分析结果
                        Text(aiAnalysisResult)
                            .font(.body)
                            .padding(.top, 4)
                        
                        Button(action: {
                            showingFoodSelection = true
                        }) {
                            Text("选择要添加的食品")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top, 8)
                        .sheet(isPresented: $showingFoodSelection) {
                            // 使用新的独立视图
                            FoodSelectionView(
                                aiAnalysisResult: aiAnalysisResult,
                                receiptID: savedReceiptID,
                                receiptManager: receiptManager
                            )
                            .environmentObject(foodStore)
                        }
                    }
                    
                    if isProcessingAI {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                }
                
                Section {
                    if isReceiptSaved && !isProcessingAI && useAIAnalysis && !aiAnalysisResult.isEmpty {
                        // Show Done button when AI analysis is complete
                        Button(action: {
                            dismiss()
                        }) {
                            Text("完成")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    } else {
                        // Show Save button
                        Button(action: {
                            saveReceipt()
                        }) {
                            HStack {
                                // Change text based on whether we're doing AI analysis
                                Text(useAIAnalysis ? "保存并分析小票" : "保存小票")
                                
                                if isProcessingOCR || isProcessingAI {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(receiptImageData != nil ? Color.blue : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(receiptImageData == nil || isProcessingOCR || isProcessingAI)
                    }
                }
            }
            .navigationTitle("添加小票")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
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
        
        // 如果启用了OCR但未启用AI，则监听OCR完成事件
        if enableOCR && !useAIAnalysis {
            // 等待OCR结果（可选）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let receipt = receiptManager.getReceipt(id: receiptID),
                   let ocrText = receipt.ocrText {
                    self.ocrExtractedText = ocrText
                }
            }
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
