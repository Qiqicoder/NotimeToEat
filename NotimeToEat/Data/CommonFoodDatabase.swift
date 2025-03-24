import Foundation
import CoreData

// 常见食物数据库，用于自动补全
struct CommonFoodDatabase {
    // 返回所有常见食物（不区分类别）
    static var allCommonFoods: [String] {
        // 临时实现 - 提供基本常见食物列表
        return [
            "西兰花", "胡萝卜", "青椒", "西红柿", "黄瓜",
            "苹果", "香蕉", "草莓", "葡萄", "橙子",
            "鸡胸肉", "牛肉", "猪肉", "羊肉",
            "牛奶", "酸奶", "奶酪", "黄油",
            "三文鱼", "虾", "鱿鱼", "螃蟹"
        ]
    }
    
    // 根据类别获取食物
    static func foods(for category: String) -> [String] {
        // 临时实现 - 根据类别过滤食物
        switch category {
        case "vegetable":
            return ["西兰花", "胡萝卜", "青椒", "西红柿", "黄瓜"]
        case "fruit":
            return ["苹果", "香蕉", "草莓", "葡萄", "橙子"]
        case "meat":
            return ["鸡胸肉", "牛肉", "猪肉", "羊肉"]
        case "dairy":
            return ["牛奶", "酸奶", "奶酪", "黄油"]
        case "seafood":
            return ["三文鱼", "虾", "鱿鱼", "螃蟹"]
        default:
            return []
        }
    }
    
    // 搜索匹配的食物
    static func searchFoods(matching searchText: String) -> [String] {
        guard !searchText.isEmpty else { return [] }
        return allCommonFoods.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
} 