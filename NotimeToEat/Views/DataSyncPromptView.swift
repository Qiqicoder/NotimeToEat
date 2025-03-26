import SwiftUI

// Import required modules and global definitions
#if os(iOS)
import UIKit
#endif

// Import DataSyncPromptType from DataSyncCoordinator
// We need to use the same enum defined there
// Remove the local definition and use the one from DataSyncCoordinator
// import NotimeToEat - commenting out as this reference doesn't exist

/// 数据同步提示类型
//enum DataSyncPromptType {
//    case uploadLocal     // 上传本地数据到云端
//    case deleteLocal     // 删除本地数据
//    case switchUser      // 切换用户前上传数据
//}

/// 数据同步提示视图
struct DataSyncPromptView: View {
    let promptType: DataSyncPromptType
    let foodItems: [FoodItem]
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部图标
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(iconColor)
                .padding(.top)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
            
            // 标题
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            // 消息内容
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            

            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(cardBackgroundColor.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // 按钮
            HStack(spacing: 15) {
                // 取消按钮
                Button(action: onCancel) {
                    Text("取消")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(buttonCancelBackgroundColor)
                        .foregroundColor(buttonCancelTextColor)
                        .cornerRadius(10)
                }
                
                // 确认按钮
                Button(action: onConfirm) {
                    Text(confirmButtonText)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(confirmButtonColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(maxWidth: 350)
        .background(promptBackgroundColor)
        .foregroundColor(promptTextColor)
        .cornerRadius(20)
        .shadow(radius: 20)
    }
    
    // MARK: - 辅助计算属性
    
    private var title: String {
        switch promptType {
        case .uploadLocal:
            return "上传本地数据"
        case .deleteLocal:
            return "删除本地数据"
        }
    }
    
    private var message: String {
        switch promptType {
        case .uploadLocal:
            return "检测到本地有数据，是否要上传到云端？这样可以在其他设备上访问您的数据。"
        case .deleteLocal:
            return "是否删除保存在本地的数据？此操作不可撤销。"
        }
    }
    
    private var iconName: String {
        switch promptType {
        case .uploadLocal:
            return "arrow.up.doc.fill"
        case .deleteLocal:
            return "trash.fill"
        }
    }
    
    private var iconColor: Color {
        switch promptType {
        case .uploadLocal:
            return .blue
        case .deleteLocal:
            return .red
        }
    }
    
    private var confirmButtonText: String {
        switch promptType {
        case .uploadLocal:
            return "上传数据"
        case .deleteLocal:
            return "删除数据"
        }
    }
    
    private var confirmButtonColor: Color {
        switch promptType {
        case .uploadLocal:
            return .blue
        case .deleteLocal:
            return .red
        }
    }
    
    // 主题相关属性
    private var promptBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white
    }
    
    private var promptTextColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.gray : Color.gray
    }
    
    private var buttonCancelBackgroundColor: Color {
        colorScheme == .dark ? Color(UIColor.tertiarySystemFill) : Color.gray.opacity(0.2)
    }
    
    private var buttonCancelTextColor: Color {
        colorScheme == .dark ? Color.white : Color.primary
    }
    

}
