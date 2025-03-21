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
                
                Section {
                    Button(action: {
                        saveReceipt()
                    }) {
                        HStack {
                            Text("保存小票")
                            
                            if isProcessingOCR {
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
                    .disabled(receiptImageData == nil || isProcessingOCR)
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
            if enableOCR {
                isProcessingOCR = true
            }
            
            // 添加小票，并根据开关决定是否执行OCR
            receiptStore.addReceiptWithoutFood(imageData: imageData, performOCR: enableOCR)
            
            // 如果不启用OCR，直接关闭视图
            if !enableOCR {
                dismiss()
            } else {
                // 等待短暂时间后关闭视图，给OCR一些时间开始处理
                // OCR将在后台继续处理，即使视图已关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isProcessingOCR = false
                    dismiss()
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
