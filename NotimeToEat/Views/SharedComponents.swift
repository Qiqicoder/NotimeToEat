import SwiftUI

// 该文件包含多个视图共享的UI组件

// FoodItemRow - 用于在列表中显示食品项目的共享组件
// 同时被CategoryView和FoodListView使用
struct FoodItemRow: View {
    let item: FoodItem
    @EnvironmentObject var foodStore: FoodStore
    
    // 可配置选项
    var showEditButton: Bool = true
    var tagDisplayStyle: TagDisplayStyle = .circle
    
    @State private var showingEditSheet = false
    
    // 标签显示样式
    enum TagDisplayStyle {
        case simple  // 简单图标 (CategoryView中使用)
        case circle  // 带背景圆圈 (FoodListView中使用)
    }
    
    var body: some View {
        Group {
            if showEditButton {
                Button(action: {
                    showingEditSheet = true
                }) {
                    FoodItemContent()
                }
            } else {
                FoodItemContent()
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditFoodView(item: item)
        }
    }
    
    @ViewBuilder
    private func FoodItemContent() -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: item.category.iconName)
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString(item.category.displayName, comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 显示到期时间
                if item.daysRemaining < 0 {
                    Text(NSLocalizedString("expired_days_ago", comment: "") + " \(abs(item.daysRemaining))")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if item.daysRemaining == 0 {
                    Text(NSLocalizedString("expires_today", comment: ""))
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(NSLocalizedString("expires_in_days", comment: "") + " \(item.daysRemaining)")
                        .font(.caption)
                        .foregroundColor(item.daysRemaining <= 3 ? .orange : .green)
                }
            }
            
            Spacer()
            
            // 根据选择的样式显示标签
            HStack(spacing: 2) {
                ForEach(item.tags, id: \.self) { tag in
                    switch tagDisplayStyle {
                    case .simple:
                        Image(systemName: tag.iconName)
                            .foregroundColor(.blue)
                            .font(.caption)
                    
                    case .circle:
                        Image(systemName: tag.iconName)
                            .foregroundColor(tag.color)
                            .font(.caption)
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(tag.color.opacity(0.2))
                            )
                    }
                }
            }
        }
    }
}

#Preview {
    FoodItemRow(item: FoodItem.sampleItems[0], showEditButton: true)
        .environmentObject(FoodStore())
} 