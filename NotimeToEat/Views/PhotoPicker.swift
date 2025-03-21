import SwiftUI
import PhotosUI

struct PhotoPicker: View {
    @Binding var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        VStack {
            if let imageData = imageData, let image = imageFromData(imageData) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(10)
                
                Button(action: {
                    self.imageData = nil
                    self.selectedItem = nil
                }) {
                    Label("删除图片", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .padding(.top, 8)
            }
            
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(imageData == nil ? "从相册选择小票" : "更换图片", 
                      systemImage: imageData == nil ? "photo.on.rectangle" : "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .onChange(of: selectedItem) {
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
        .padding(.vertical)
    }
    
    private func imageFromData(_ data: Data) -> Image? {
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
    }
}

#if DEBUG
struct PhotoPicker_Previews: PreviewProvider {
    static var previews: some View {
        PhotoPicker(imageData: .constant(nil))
    }
}
#endif 
