import SwiftUI
import AppKit

// 图片存储服务
class ImageManager: ObservableObject {
    @Published var receipts: [Receipt] = []
    
    init() {
        load()
    }
    
    // 保存图像到文件系统并返回唯一ID
    func saveImage(_ image: NSImage) -> String {
        let id = UUID().uuidString
        if let data = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: data),
           let jpegData = bitmap.representation(using: .jpeg, properties: [:]) {
            let filename = getDocumentsDirectory().appendingPathComponent("\(id).jpg")
            try? jpegData.write(to: filename)
            return id
        }
        return ""
    }
    
    // More implementation...
} 