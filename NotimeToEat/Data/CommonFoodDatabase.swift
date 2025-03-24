import Foundation
import NotimeToEat  // Import main app module for Models namespace

// 常见食物数据库，用于自动补全
struct CommonFoodDatabase {
    // 按照类别组织的常见食物
    static let commonFoods: [Models.Category: [String]] = [
        .vegetable: [
            "西兰花",
            "胡萝卜",
            "青椒",
            "西红柿",
            "黄瓜"
        ],
        .fruit: [
            "苹果",
            "香蕉",
            "草莓",
            "葡萄",
            "橙子"
        ],
        .meat: [
            "鸡胸肉",
            "牛肉",
            "猪肉",
            "羊肉"
        ],
        .dairy: [
            "牛奶",
            "酸奶",
            "奶酪",
            "黄油"
        ],
        .seafood: [
            "三文鱼",
            "虾",
            "鱿鱼",
            "螃蟹"
        ],
        .grain: [
            "米饭",
            "面包",
            "意大利面",
            "燕麦片"
        ],
        .snack: [
            "薯片",
            "饼干",
            "巧克力",
            "坚果"
        ],
        .beverage: [
            "咖啡",
            "茶",
            "果汁",
            "可乐"
        ],
        .condiment: [
            "盐",
            "糖",
            "酱油",
            "醋",
            "辣椒酱"
        ],
        .other: [
            "豆腐",
            "鸡蛋",
            "蜂蜜"
        ]
    ]
    
    // 返回所有常见食物（不区分类别）
    static var allCommonFoods: [String] {
        return commonFoods.values.flatMap { $0 }
    }
    
    // 根据类别获取食物
    static func foods(for category: Models.Category) -> [String] {
        return commonFoods[category] ?? []
    }
    
    // 搜索匹配的食物
    static func searchFoods(matching searchText: String) -> [String] {
        guard !searchText.isEmpty else {
            return []
        }
        
        return allCommonFoods.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
} 