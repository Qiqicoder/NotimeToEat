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
            
            // 数据概要
            VStack(alignment: .leading, spacing: 8) {
                Text("数据概要：")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("• 食物项：")
                    Text("\(foodItems.count)个")
                        .fontWeight(.medium)
                }
                
                // 按分类显示统计信息
                let categories = Dictionary(grouping: foodItems, by: { $0.category })
                ForEach(Array(categories.keys).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                    if let count = categories[category]?.count, count > 0 {
                        HStack {
                            Text("• \(categoryName(category))：")
                            Text("\(count)个")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
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
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
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
        .background(Color.white)
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
        case .switchUser:
            return "切换用户警告"
        }
    }
    
    private var message: String {
        switch promptType {
        case .uploadLocal:
            return "检测到本地有数据，是否要上传到云端？这样可以在其他设备上访问您的数据。"
        case .deleteLocal:
            return "您确定要删除本地数据吗？此操作不可撤销。"
        case .switchUser:
            return "您正在切换到另一个账号。是否要先上传当前账号的数据以避免丢失？"
        }
    }
    
    private var iconName: String {
        switch promptType {
        case .uploadLocal:
            return "arrow.up.doc.fill"
        case .deleteLocal:
            return "trash.fill"
        case .switchUser:
            return "person.2.fill"
        }
    }
    
    private var iconColor: Color {
        switch promptType {
        case .uploadLocal:
            return .blue
        case .deleteLocal:
            return .red
        case .switchUser:
            return .orange
        }
    }
    
    private var confirmButtonText: String {
        switch promptType {
        case .uploadLocal:
            return "上传数据"
        case .deleteLocal:
            return "删除数据"
        case .switchUser:
            return "上传并切换"
        }
    }
    
    private var confirmButtonColor: Color {
        switch promptType {
        case .uploadLocal:
            return .blue
        case .deleteLocal:
            return .red
        case .switchUser:
            return .orange
        }
    }
    
    // 获取分类的中文名称
    private func categoryName(_ category: Category) -> String {
        switch category {
        case .vegetable: return "蔬菜"
        case .fruit: return "水果"
        case .meat: return "肉类"
        case .seafood: return "海鲜"
        case .dairy: return "乳制品"
        case .grain: return "主食/谷物"
        case .beverage: return "饮料"
        case .snack: return "零食"
        case .condiment: return "调味品"
        case .other: return "其他"
        }
    }
}

#if DEBUG
struct DataSyncPromptView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            DataSyncPromptView(
                promptType: .uploadLocal,
                foodItems: FoodItem.sampleItems,
                onConfirm: {},
                onCancel: {}
            )
        }
        .previewDisplayName("上传数据")
        
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            DataSyncPromptView(
                promptType: .deleteLocal,
                foodItems: FoodItem.sampleItems,
                onConfirm: {},
                onCancel: {}
            )
        }
        .previewDisplayName("删除数据")
        
        ZStack {
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            DataSyncPromptView(
                promptType: .switchUser,
                foodItems: FoodItem.sampleItems,
                onConfirm: {},
                onCancel: {}
            )
        }
        .previewDisplayName("切换用户")
    }
}
#endif 
