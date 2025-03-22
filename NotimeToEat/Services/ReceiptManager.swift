import SwiftUI
import Foundation
import Vision
import PhotosUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@available(iOS 13.0, macOS 10.15, *)
class ReceiptManager: ObservableObject {
    @Published var receipts: [Models.Receipt] = []
    static let shared = ReceiptManager()
    
    private init() {}
    
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: false)
            .appendingPathComponent("receipts.data")
    }
    
    // 获取文档目录
    static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    // 从磁盘加载数据
    func load() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let fileURL = try Self.fileURL()
                guard let data = try? Data(contentsOf: fileURL) else {
                    return
                }
                
                let decoder = JSONDecoder()
                let receipts = try decoder.decode([Models.Receipt].self, from: data)
                
                DispatchQueue.main.async {
                    self.receipts = receipts
                }
            } catch {
                print("ERROR: 无法加载小票列表: \(error.localizedDescription)")
            }
        }
    }
    
    // 保存数据到磁盘
    func save() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try JSONEncoder().encode(self.receipts)
                let outfile = try Self.fileURL()
                try data.write(to: outfile)
            } catch {
                print("ERROR: 无法保存小票列表: \(error.localizedDescription)")
            }
        }
    }
    
    // 保存图像到文件系统并返回唯一ID
    func saveImage(_ imageData: Data) -> String {
        let id = UUID().uuidString
        let filename = Self.getDocumentsDirectory().appendingPathComponent("\(id).jpg")
        
        do {
            try imageData.write(to: filename)
            return id
        } catch {
            print("ERROR: 无法保存图片: \(error.localizedDescription)")
            return ""
        }
    }
    
    // 获取图像
    func loadImage(id: String) -> Image? {
        let filename = Self.getDocumentsDirectory().appendingPathComponent("\(id).jpg")
        do {
            let data = try Data(contentsOf: filename)
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
            #elseif os(macOS)
            if let nsImage = NSImage(data: data) {
                return Image(nsImage: nsImage)
            }
            #endif
            return nil
        } catch {
            print("ERROR: 无法加载图片: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 添加带有OCR识别的小票
    func addReceiptWithOCR(imageData: Data, foodItemID: UUID? = nil, performOCR: Bool = false) {
        let imageID = saveImage(imageData)
        guard !imageID.isEmpty else { return }
        
        var foodItemIDs: [UUID] = []
        if let id = foodItemID {
            foodItemIDs.append(id)
        }
        
        var ocrText: String? = nil
        
        // 创建接收
        let receipt = Models.Receipt(imageID: imageID, foodItemID: foodItemID, foodItemIDs: foodItemIDs, ocrText: ocrText)
        receipts.append(receipt)
        save()
        
        // 如果需要执行OCR，则在后台进行
        if performOCR {
            // 在后台线程中执行OCR
            DispatchQueue.global().async {
                self.performOCR(for: imageData) { recognizedText in
                    if let text = recognizedText, !text.isEmpty {
                        // 更新接收
                        DispatchQueue.main.async {
                            if let index = self.receipts.firstIndex(where: { $0.id == receipt.id }) {
                                self.receipts[index].ocrText = text
                                self.save()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 添加没有关联食品的小票，可选OCR
    @discardableResult
    func addReceiptWithoutFood(imageData: Data, performOCR: Bool = false) -> UUID {
        let imageID = saveImage(imageData)
        guard !imageID.isEmpty else { return UUID() } // Return a new UUID if save failed
        
        // 创建接收
        let receipt = Models.Receipt(imageID: imageID, foodItemID: nil, foodItemIDs: [], ocrText: nil)
        receipts.append(receipt)
        save()
        
        // 如果需要执行OCR，则在后台进行
        if performOCR {
            // 在后台线程中执行OCR
            DispatchQueue.global().async {
                self.performOCR(for: imageData) { recognizedText in
                    if let text = recognizedText, !text.isEmpty {
                        // 更新接收
                        DispatchQueue.main.async {
                            if let index = self.receipts.firstIndex(where: { $0.id == receipt.id }) {
                                self.receipts[index].ocrText = text
                                self.save()
                            }
                        }
                    }
                }
            }
        }
        
        return receipt.id
    }
    
    // 获取特定ID的小票
    func getReceipt(id: UUID) -> Models.Receipt? {
        return receipts.first(where: { $0.id == id })
    }
    
    // 更新特定收据的OCR文本（用于手动触发OCR）
    func updateReceiptOCR(for receiptID: UUID) {
        guard let receiptIndex = receipts.firstIndex(where: { $0.id == receiptID }) else {
            return
        }
        
        let receipt = receipts[receiptIndex]
        
        updateOCRText(for: receipt) { success in
            if success {
                print("OCR识别成功完成")
            } else {
                print("OCR识别失败或无文本")
            }
        }
    }
    
    // 更新小票的AI分析结果
    func updateReceiptAIAnalysis(id: UUID, result: String) {
        if let index = receipts.firstIndex(where: { $0.id == id }) {
            receipts[index].aiAnalysisResult = result
            save()
        }
    }
    
    // 将食品关联到小票
    func associateFoodWithReceipt(foodID: UUID, receiptID: UUID) {
        if let index = receipts.firstIndex(where: { $0.id == receiptID }) {
            if !receipts[index].foodItemIDs.contains(foodID) {
                receipts[index].foodItemIDs.append(foodID)
                save()
            }
        }
    }
    
    // 解除食品与小票的关联
    func dissociateFoodFromReceipt(foodID: UUID, receiptID: UUID) {
        if let index = receipts.firstIndex(where: { $0.id == receiptID }) {
            receipts[index].foodItemIDs.removeAll { $0 == foodID }
            save()
        }
    }
    
    // 获取与食品关联的小票
    func receiptsForFood(with id: UUID) -> [Models.Receipt] {
        return receipts.filter { $0.foodItemID == id || $0.foodItemIDs.contains(id) }
    }
    
    // 删除小票
    func deleteReceipt(_ receipt: Models.Receipt) {
        // 从文件系统删除图像
        let filename = Self.getDocumentsDirectory().appendingPathComponent("\(receipt.imageID).jpg")
        try? FileManager.default.removeItem(at: filename)
        
        // 从列表中删除
        receipts.removeAll { $0.id == receipt.id }
        save()
    }
    
    // 删除与食品关联的所有小票
    func deleteReceiptsForFood(with id: UUID) {
        let foodReceipts = receiptsForFood(with: id)
        for receipt in foodReceipts {
            // 如果是主要关联，则删除整个小票
            if receipt.foodItemID == id {
                deleteReceipt(receipt)
            } else {
                // 否则只是解除关联
                dissociateFoodFromReceipt(foodID: id, receiptID: receipt.id)
            }
        }
    }
    
    // 在Receipt视图中显示OCR文本
    func addOCRTextDisplay(for receipt: Models.Receipt, to view: some View) -> some View {
        if let ocrText = receipt.ocrText, !ocrText.isEmpty {
            return AnyView(
                VStack {
                    view
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OCR识别文本:")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
                        Text(ocrText)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.1))
                            )
                    }
                    .padding(.top, 8)
                    .transition(.opacity)
                }
            )
        } else {
            return AnyView(view)
        }
    }
    
    // 执行OCR识别并返回结果
    func performOCR(for imageData: Data, completion: @escaping (String?) -> Void) {
        #if os(iOS)
        guard let image = UIImage(data: imageData) else {
            completion(nil)
            return
        }
        
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        #elseif os(macOS)
        guard let nsImage = NSImage(data: imageData) else {
            completion(nil)
            return
        }
        
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }
        #endif
        
        // 创建Vision请求
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                print("OCR识别错误: \(error!.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            // 提取识别的文本
            let recognizedText = observations.compactMap { observation in
                // 获取置信度最高的候选文本
                return observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(recognizedText)
        }
        
        // 配置请求
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // 执行请求
        do {
            try requestHandler.perform([request])
        } catch {
            print("OCR识别失败: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // 为特定Receipt更新OCR文本
    func updateOCRText(for receipt: Models.Receipt, completion: @escaping (Bool) -> Void) {
        guard let receiptIndex = receipts.firstIndex(where: { $0.id == receipt.id }) else {
            completion(false)
            return
        }
        
        let imageID = receipt.imageID
        let imagePath = Self.getDocumentsDirectory().appendingPathComponent("\(imageID).jpg")
        
        guard let imageData = try? Data(contentsOf: imagePath) else {
            completion(false)
            return
        }
        
        performOCR(for: imageData) { recognizedText in
            if let text = recognizedText, !text.isEmpty {
                DispatchQueue.main.async {
                    self.receipts[receiptIndex].ocrText = text
                    self.save()
                    completion(true)
                }
            } else {
                completion(false)
            }
        }
    }
}
