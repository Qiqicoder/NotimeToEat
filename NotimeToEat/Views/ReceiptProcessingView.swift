import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct ReceiptProcessingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var receiptManager: ReceiptManager
    @EnvironmentObject var foodStore: FoodStore
    
    let imageData: Data
    
    @State private var enableOCR: Bool = true
    @State private var useAIAnalysis: Bool = true
    @State private var isProcessingOCR: Bool = false
    @State private var isProcessingAI: Bool = false
    @State private var aiAnalysisResult: String = ""
    @State private var ocrExtractedText: String = ""
    @State private var isReceiptSaved: Bool = false
    @State private var savedReceiptID: UUID? = nil
    @State private var showingFoodSelection: Bool = false
    
    // 从配置文件加载API密钥
    private let aiService = Services.AIService(apiKey: Services.APIKeys.deepseekAPIKey)
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("小票图片")) {
                    #if os(iOS)
                    if let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(10)
                    }
                    #elseif os(macOS)
                    if let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(10)
                    }
                    #endif
                }
                
                Section(header: Text("处理选项")) {
                    Toggle("OCR文本识别", isOn: $enableOCR)
                    
                    Toggle("AI智能分析", isOn: $useAIAnalysis)
                        .disabled(!enableOCR)
                    
                    if !enableOCR && useAIAnalysis {
                        Text("AI分析需要先启用OCR")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                if isReceiptSaved && useAIAnalysis && !aiAnalysisResult.isEmpty {
                    Section(header: Text("AI分析结果")) {
                        Text(aiAnalysisResult)
                            .font(.body)
                            .padding(.vertical, 4)
                        
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
                        .padding(.top, 4)
                    }
                }
                
                Section {
                    if isReceiptSaved && isProcessingAI {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("AI分析中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                    } else if isReceiptSaved && !isProcessingAI && useAIAnalysis && !aiAnalysisResult.isEmpty {
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
                        Button(action: {
                            saveReceipt()
                        }) {
                            HStack {
                                Text(useAIAnalysis ? "保存并分析小票" : "保存小票")
                                
                                if isProcessingOCR {
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
            }
            .navigationTitle("处理小票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
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
    
    private func saveReceipt() {
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
struct ReceiptProcessingView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptProcessingView(imageData: Data())
            .environmentObject(FoodStore())
            .environmentObject(ReceiptManager.shared)
    }
}
#endif 