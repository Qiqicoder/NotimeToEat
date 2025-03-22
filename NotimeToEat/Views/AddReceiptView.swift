import SwiftUI
import PhotosUI
import Foundation

// The app uses global typealias declarations from Globals.swift
// ReceiptStore and PhotoPicker are already defined in the project

struct AddReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var receiptStore: ReceiptStore
    @State private var receiptImageData: Data? = nil
    @State private var enableOCR: Bool = false
    @State private var isProcessingOCR: Bool = false
    @State private var useAIAnalysis: Bool = false
    @State private var aiAnalysisResult: String = ""
    @State private var isProcessingAI: Bool = false
    @State private var ocrExtractedText: String = ""
    @State private var isReceiptSaved: Bool = false
    @State private var savedReceiptID: UUID? = nil
    
    // 从配置文件加载API密钥
    private let aiService = AIService(apiKey: Services.APIKeys.deepseekAPIKey)
    
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
                        Text(aiAnalysisResult)
                            .font(.body)
                            .padding(.top, 4)
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
            .navigationBarTitleDisplayMode(.inline)
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
        if let imageData = receiptImageData {
            isProcessingOCR = enableOCR || useAIAnalysis
            isReceiptSaved = true
            
            // 保存小票，并根据开关决定是否执行OCR
            // Always perform OCR if AI analysis is enabled
            let performOCR = enableOCR || useAIAnalysis
            let receiptID = receiptStore.addReceiptWithoutFood(imageData: imageData, performOCR: performOCR)
            savedReceiptID = receiptID
            
            // 如果启用AI分析，在OCR完成后再分析
            if useAIAnalysis {
                isProcessingAI = true
                
                // 轮询等待OCR完成并获取文本
                var attempts = 0
                let maxAttempts = 10
                
                func checkForOCRText() {
                    attempts += 1
                    
                    if let receipt = receiptStore.getReceipt(id: receiptID), 
                       let ocrText = receipt.ocrText, 
                       !ocrText.isEmpty {
                        // OCR文本已准备就绪，进行AI分析
                        self.ocrExtractedText = ocrText
                        performAIAnalysis(ocrText: ocrText)
                    } else if attempts < maxAttempts {
                        // 继续等待OCR完成
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            checkForOCRText()
                        }
                    } else {
                        // OCR尝试已达到最大次数
                        DispatchQueue.main.async {
                            self.aiAnalysisResult = "无法获取OCR文本，请稍后重试或检查图像质量"
                            self.isProcessingAI = false
                        }
                    }
                }
                
                // 稍等片刻再开始检查OCR，给OCR处理一些时间
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    checkForOCRText()
                }
            }
            
            // 如果不启用OCR和AI分析，直接关闭视图
            if !enableOCR && !useAIAnalysis {
                dismiss()
            } else {
                // 等待短暂时间后更新处理状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessingOCR = false
                    // 我们不再在这里自动关闭视图，而是让用户点击"完成"按钮
                }
            }
        }
    }
    
    // 执行AI分析
    private func performAIAnalysis(ocrText: String) {
        Task {
            do {
                let prompt = "以下是从购物小票OCR提取的文本，请分析并提取所有商品名称和价格:\n\n\(ocrText)"
                let result = try await aiService.generateCompletion(prompt: prompt)
                
                await MainActor.run {
                    aiAnalysisResult = result
                    isProcessingAI = false
                    
                    // 保存AI分析结果到小票
                    if let receiptID = savedReceiptID {
                        // 使用更可靠的方法更新AI分析结果
                        receiptStore.updateReceiptAIAnalysis(id: receiptID, result: result)
                        print("AI分析结果已保存到小票中，ID: \(receiptID)")
                    } else {
                        print("无法保存AI分析结果：找不到对应的小票ID")
                    }
                }
            } catch {
                print("AI Analysis error: \(error)")
                await MainActor.run {
                    aiAnalysisResult = "错误: \(error.localizedDescription)"
                    isProcessingAI = false
                }
            }
        }
    }
}

#if DEBUG
struct AddReceiptView_Previews: PreviewProvider {
    static var previews: some View {
        AddReceiptView()
            .environmentObject(ReceiptStore())
    }
}
#endif
