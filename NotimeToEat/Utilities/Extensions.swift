import SwiftUI

// 日期格式化扩展
extension Date {
    func formatted() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
    
    func formattedWithTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func remainingDaysDescription() -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: self).day ?? 0
        
        if days < 0 {
            return "已过期 \(abs(days)) 天"
        } else if days == 0 {
            return "今天过期"
        } else if days == 1 {
            return "明天过期"
        } else {
            return "还有 \(days) 天过期"
        }
    }
}

// 颜色扩展，根据天数返回不同颜色
extension Color {
    static func forRemainingDays(_ days: Int) -> Color {
        if days < 0 {
            return .red
        } else if days <= 3 {
            return .orange
        } else if days <= 7 {
            return .yellow
        } else {
            return .green
        }
    }
} 