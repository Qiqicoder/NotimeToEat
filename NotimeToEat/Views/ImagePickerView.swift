import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
/// 一个使用UIImagePickerController的包装器视图
/// 提供相机拍照和相册选择功能
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    var sourceType: UIImagePickerController.SourceType
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        
        // 在相机模式下添加相册访问按钮
        if sourceType == .camera {
            picker.cameraDevice = .rear
            picker.cameraCaptureMode = .photo
            // UIImagePickerController会自动添加相册访问按钮
            picker.showsCameraControls = true
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // 优先使用编辑后的图片，如果没有则使用原图
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            
            // 压缩图片以减少内存使用
            if let image = image, let jpegData = image.jpegData(compressionQuality: 0.8) {
                parent.imageData = jpegData
            }
            
            picker.dismiss(animated: true) {
                // 调用dismiss回调
                self.parent.onDismiss?()
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                // 调用dismiss回调
                self.parent.onDismiss?()
            }
        }
    }
}
#endif

#if DEBUG
struct ImagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        Text("ImagePicker Preview")
            #if os(iOS)
            .sheet(isPresented: .constant(true)) {
                ImagePickerView(imageData: .constant(nil), sourceType: .camera)
            }
            #endif
    }
}
#endif 