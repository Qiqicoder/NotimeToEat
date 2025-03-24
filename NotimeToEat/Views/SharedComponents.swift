import SwiftUI

// 该文件包含多个视图共享的UI组件

// 垂直波浪形状组件
struct VerticalWaveShape: Shape {
    var amplitude: CGFloat = 5 // 波浪振幅
    var frequency: CGFloat = 1.0 // 波浪频率
    var phase: CGFloat // 相位 - 用于动画

    // 形状随相位变化而变化
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let midWidth = rect.midX
        
        var path = Path()
        path.move(to: CGPoint(x: midWidth, y: 0)) // 从顶部中点开始

        // 绘制垂直方向的波浪
        for y in stride(from: 0, to: height, by: 1) {
            let relativeY = y / height
            let sine = sin(relativeY * frequency * 2 * .pi + phase)
            let x = midWidth + amplitude * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // 完成波浪形状 - 右边缘包围
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        
        return path
    }
}

// 带波浪边缘的进度形状
struct WaveEdgeProgressShape: Shape {
    var progress: CGFloat // 0.0 - 1.0 之间的进度
    var waveWidth: CGFloat = 10 // 波浪宽度
    var amplitude: CGFloat = 5 // 波浪振幅
    var frequency: CGFloat = 1.0 // 波浪频率
    var phase: CGFloat // 波浪相位，用于动画
    
    // 用于动画
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        
        // 计算进度条的宽度
        let progressWidth = width * progress
        
        // 如果进度为0，返回空路径
        if progress <= 0 {
            return Path()
        }
        
        var path = Path()
        
        // 从左上角开始
        path.move(to: CGPoint(x: 0, y: 0))
        
        // 如果进度不足以显示波浪，就只画一个矩形
        if progressWidth <= waveWidth {
            path.addLine(to: CGPoint(x: progressWidth, y: 0))
            path.addLine(to: CGPoint(x: progressWidth, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.closeSubpath()
            return path
        }
        
        // 画到波浪开始的位置
        path.addLine(to: CGPoint(x: progressWidth - waveWidth, y: 0))
        
        // 画波浪的右边缘
        let waveStart = progressWidth - waveWidth
        
        // 从顶部到底部遍历高度，画出波浪边缘
        for y in stride(from: 0, to: height, by: 1) {
            let relativeY = y / height
            let sine = sin(relativeY * frequency * 2 * .pi + phase)
            let x = progressWidth - waveWidth / 2 + amplitude * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        // 完成路径
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

// FoodItemRow - 用于在列表中显示食品项目的共享组件
// 同时被CategoryView和FoodListView使用
struct FoodItemRow: View {
    let item: FoodItem
    @EnvironmentObject var foodStore: FoodStore
    
    // 可配置选项
    var showEditButton: Bool = true
    var tagDisplayStyle: TagDisplayStyle = .circle
    
    @State private var showingEditSheet = false
    @State private var wavePhase: CGFloat = 0 // 波浪相位，用于动画
    
    // 标签显示样式
    enum TagDisplayStyle {
        case simple  // 简单图标 (CategoryView中使用)
        case circle  // 带背景圆圈 (FoodListView中使用)
    }
    
    // 计算经过的时间百分比 (0-1)
    private var expirationProgress: Double {
        let totalTimeInterval = item.expirationDate.timeIntervalSince(item.addedDate)
        let elapsedTimeInterval = Date().timeIntervalSince(item.addedDate)
        
        // 确保不超过1
        let progress = min(elapsedTimeInterval / totalTimeInterval, 1.0)
        // 确保不小于0
        return max(progress, 0.0)
    }
    
    // 基于进度返回颜色（从蓝色过渡到红色）
    private var progressColor: Color {
        // 蓝色为起始，红色为结束
        return Color(
            red: min(1.0, expirationProgress * 2), // 红色分量随进度增加
            green: max(0.0, 0.5 - expirationProgress * 0.5), // 绿色分量随进度减少
            blue: max(0.0, 1.0 - expirationProgress * 2) // 蓝色分量随进度减少
        ).opacity(0.3) // 降低不透明度，使颜色不那么刺眼
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
        .onAppear {
            // 开始波浪动画，让波浪从上到下流动
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                wavePhase = 2 * .pi
            }
        }
    }
    
    @ViewBuilder
    private func FoodItemContent() -> some View {
        // 使用ZStack来叠加进度背景和内容
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 新的带波浪边缘的进度条
                WaveEdgeProgressShape(
                    progress: CGFloat(expirationProgress),
                    waveWidth: 10,
                    amplitude: 5,
                    frequency: 1.0,
                    phase: wavePhase
                )
                .fill(progressColor)
                
                // 内容部分保持不变
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
                            Text(String(format: NSLocalizedString("expires_in_days", comment: ""), item.daysRemaining))
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
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .frame(height: 70) // 确保行有足够的高度
        .cornerRadius(8) // 为整个行添加圆角
        .contentShape(Rectangle()) // 确保整个区域可点击
    }
}

#Preview {
    FoodItemRow(item: FoodItem.sampleItems[0], showEditButton: true)
        .environmentObject(FoodStore())
} 