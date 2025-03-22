import Foundation
import SwiftUI

struct User: Identifiable, Codable {
    var id: String                // 用户唯一标识符
    var email: String?            // 用户电子邮件
    var displayName: String?      // 显示名称
    var photoURL: URL?            // 头像URL
    var isLoggedIn: Bool = false  // 登录状态
    
    // 其他用户数据，可以根据需要扩展
    var createdAt: Date = Date()  // 账户创建时间
    var lastLogin: Date = Date()  // 最后登录时间
    
    init(id: String, email: String? = nil, displayName: String? = nil, photoURL: URL? = nil) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.isLoggedIn = true
        self.lastLogin = Date()
    }
}

extension User {
    // 创建一个匿名用户
    static var anonymous: User {
        User(id: UUID().uuidString, displayName: "游客")
    }
    
    // 获取用户的初始字母作为头像占位符
    var initials: String {
        guard let name = displayName, !name.isEmpty else { return "?" }
        return String(name.prefix(1).uppercased())
    }
} 