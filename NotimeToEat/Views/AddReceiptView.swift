import SwiftUI
import PhotosUI

// The app uses global typealias declarations from Globals.swift
// Make sure these are properly imported

struct AddReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var receiptStore: ReceiptStore
    @State private var receiptImageData: Data? = nil
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("购物小票图片")) {
                    PhotoPicker(imageData: $receiptImageData)
                }
                
                Section {
                    Button(action: {
                        saveReceipt()
                    }) {
                        Text("保存小票")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(receiptImageData != nil ? Color.blue : Color.gray)
                            .cornerRadius(10)
                    }
                    .disabled(receiptImageData == nil)
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
            // 直接添加小票，不关联食品
            receiptStore.addReceiptWithoutFood(imageData: imageData)
            dismiss()
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
