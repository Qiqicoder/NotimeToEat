import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

class FriendsService: ObservableObject {
    // 单例模式
    static let shared = FriendsService()
    
    // 存储用户的好友列表
    @Published var friends: [FriendItem] = []
    
    // 存储待处理的好友请求
    @Published var pendingRequests: [FriendRequest] = []
    
    // Firestore引用
    private let db = Firestore.firestore()
    
    // 调试信息
    @Published var debugMessage: String = ""
    
    private init() {
        // 当用户登录状态改变时，重新加载好友数据
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            if let user = user {
                self?.loadFriends()
                self?.loadPendingRequests()
            } else {
                self?.friends = []
                self?.pendingRequests = []
            }
        }
    }
    
    // 调试Firestore连接和权限
    func debugFirestore(completion: @escaping (Bool, String) -> Void) {
        self.debugMessage = "开始Firestore调试..."
        print("=== Firestore调试开始 ===")
        
        // 检查当前用户登录状态
        guard let currentUser = Auth.auth().currentUser else {
            let message = "错误：用户未登录，无法访问Firestore"
            self.debugMessage = message
            print(message)
            completion(false, message)
            return
        }
        
        print("当前用户ID: \(currentUser.uid)")
        print("当前用户Email: \(currentUser.email ?? "无")")
        
        // 创建一个唯一的测试文档ID
        let testDocId = "debug_\(Date().timeIntervalSince1970)"
        let testCollection = "debug_collection"
        
        // 测试数据
        let testData: [String: Any] = [
            "timestamp": FieldValue.serverTimestamp(),
            "userId": currentUser.uid,
            "test_value": "测试数据",
            "deviceInfo": UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        ]
        
        self.debugMessage = "正在测试写入权限..."
        
        // 尝试写入测试文档
        db.collection(testCollection).document(testDocId).setData(testData) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                let message = "写入测试失败: \(error.localizedDescription)"
                self.debugMessage = message
                print(message)
                completion(false, message)
                return
            }
            
            print("测试文档写入成功！")
            self.debugMessage = "写入测试成功，正在测试读取权限..."
            
            // 尝试读取刚刚写入的文档
            self.db.collection(testCollection).document(testDocId).getDocument { [weak self] (document, error) in
                guard let self = self else { return }
                
                if let error = error {
                    let message = "读取测试失败: \(error.localizedDescription)"
                    self.debugMessage = message
                    print(message)
                    completion(false, message)
                    return
                }
                
                guard let document = document, document.exists else {
                    let message = "无法找到刚刚创建的测试文档"
                    self.debugMessage = message
                    print(message)
                    completion(false, message)
                    return
                }
                
                print("测试文档读取成功！")
                print("文档数据: \(document.data() ?? [:])")
                
                // 删除测试文档
                self.db.collection(testCollection).document(testDocId).delete { [weak self] error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        let message = "清理测试文档失败: \(error.localizedDescription)，但测试已完成"
                        self.debugMessage = message
                        print(message)
                    } else {
                        print("测试文档已清理")
                    }
                    
                    // 读取当前用户的好友数量
                    self.debugMessage = "测试成功，正在检查用户数据..."
                    
                    self.db.collection("friends")
                        .document(currentUser.uid)
                        .collection("userFriends")
                        .getDocuments { [weak self] (snapshot, error) in
                            guard let self = self else { return }
                            
                            if let error = error {
                                let message = "检查好友列表失败: \(error.localizedDescription)"
                                self.debugMessage = message
                                print(message)
                                completion(true, "基本测试通过，但查询好友列表时出错: \(error.localizedDescription)")
                                return
                            }
                            
                            let friendsCount = snapshot?.documents.count ?? 0
                            let message = "Firestore连接正常！当前有 \(friendsCount) 个好友记录。"
                            self.debugMessage = message
                            print(message)
                            
                            // 检查好友请求
                            self.db.collection("friendRequests")
                                .whereField("recipientId", isEqualTo: currentUser.uid)
                                .getDocuments { [weak self] (snapshot, error) in
                                    guard let self = self else { return }
                                    
                                    if let error = error {
                                        let finalMessage = "基本测试通过，但查询好友请求时出错: \(error.localizedDescription)"
                                        self.debugMessage = finalMessage
                                        print(finalMessage)
                                        completion(true, finalMessage)
                                        return
                                    }
                                    
                                    let requestsCount = snapshot?.documents.count ?? 0
                                    let finalMessage = "Firestore测试完全通过！连接正常，权限正常。\n好友数: \(friendsCount)\n好友请求数: \(requestsCount)"
                                    self.debugMessage = finalMessage
                                    print("=== Firestore调试结束 ===")
                                    completion(true, finalMessage)
                                }
                        }
                }
            }
        }
    }
    
    // 检查Firestore集合的文档数量
    func checkCollectionCount(collection: String, completion: @escaping (Int, Error?) -> Void) {
        db.collection(collection).getDocuments { (snapshot, error) in
            if let error = error {
                print("检查集合 \(collection) 时出错: \(error.localizedDescription)")
                completion(0, error)
                return
            }
            
            let count = snapshot?.documents.count ?? 0
            print("集合 \(collection) 中有 \(count) 个文档")
            completion(count, nil)
        }
    }
    
    // 加载当前用户的好友列表
    func loadFriends() {
        guard let currentUser = Auth.auth().currentUser else {
            self.friends = []
            return
        }
        
        db.collection("friends")
            .document(currentUser.uid)
            .collection("userFriends")
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("加载好友列表错误: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.friends = []
                    return
                }
                
                self.friends = documents.compactMap { document in
                    let data = document.data()
                    guard let id = data["id"] as? String,
                          let name = data["name"] as? String else {
                        return nil
                    }
                    
                    let email = data["email"] as? String
                    let photoURLString = data["photoURL"] as? String
                    let photoURL = photoURLString != nil ? URL(string: photoURLString!) : nil
                    
                    return FriendItem(id: id, name: name, email: email, photoURL: photoURL)
                }
            }
    }
    
    // 加载当前用户的待处理好友请求
    func loadPendingRequests() {
        guard let currentUser = Auth.auth().currentUser else {
            self.pendingRequests = []
            return
        }
        
        db.collection("friendRequests")
            .whereField("recipientId", isEqualTo: currentUser.uid)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("加载好友请求错误: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.pendingRequests = []
                    return
                }
                
                self.pendingRequests = documents.compactMap { document in
                    let data = document.data()
                    guard let senderName = data["senderName"] as? String,
                          let senderEmail = data["senderEmail"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    
                    let id = document.documentID
                    
                    return FriendRequest(
                        id: id,
                        senderName: senderName,
                        senderEmail: senderEmail,
                        timestamp: timestamp.dateValue()
                    )
                }
            }
    }
    
    // 发送好友请求
    func sendFriendRequest(to email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let currentUser = Auth.auth().currentUser,
              let currentUserEmail = currentUser.email else {
            completion(false, "您需要登录才能发送好友请求")
            return
        }
        
        // 查找要邀请的用户
        db.collection("users")
            .whereField("email", isEqualTo: email)
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("查找用户错误: \(error.localizedDescription)")
                    completion(false, "查找用户失败，请稍后重试")
                    return
                }
                
                // 检查用户是否存在
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    completion(false, "找不到使用此邮箱的用户")
                    return
                }
                
                let recipientData = documents[0].data()
                let recipientId = documents[0].documentID
                
                // 检查是否已经是好友
                self.checkIfAlreadyFriends(currentUserId: currentUser.uid, recipientId: recipientId) { isAlreadyFriend in
                    if isAlreadyFriend {
                        completion(false, "该用户已经是您的好友")
                        return
                    }
                    
                    // 检查是否已经发送过请求
                    self.checkIfRequestAlreadySent(senderId: currentUser.uid, recipientId: recipientId) { isAlreadySent in
                        if isAlreadySent {
                            completion(false, "您已经向该用户发送过好友请求")
                            return
                        }
                        
                        // 创建好友请求记录
                        let requestData: [String: Any] = [
                            "senderId": currentUser.uid,
                            "senderName": currentUser.displayName ?? "用户",
                            "senderEmail": currentUserEmail,
                            "recipientId": recipientId,
                            "recipientName": recipientData["displayName"] as? String ?? "用户",
                            "recipientEmail": email,
                            "status": "pending",
                            "timestamp": FieldValue.serverTimestamp()
                        ]
                        
                        // 保存请求到Firestore
                        self.db.collection("friendRequests").addDocument(data: requestData) { error in
                            if let error = error {
                                print("保存好友请求错误: \(error.localizedDescription)")
                                completion(false, "发送请求失败，请稍后重试")
                                return
                            }
                            
                            completion(true, "已成功向\(email)发送好友请求")
                        }
                    }
                }
            }
    }
    
    // 检查是否已经是好友
    private func checkIfAlreadyFriends(currentUserId: String, recipientId: String, completion: @escaping (Bool) -> Void) {
        db.collection("friends")
            .document(currentUserId)
            .collection("userFriends")
            .document(recipientId)
            .getDocument { (snapshot, error) in
                if let error = error {
                    print("检查好友状态错误: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                completion(snapshot?.exists ?? false)
            }
    }
    
    // 检查是否已经发送过请求
    private func checkIfRequestAlreadySent(senderId: String, recipientId: String, completion: @escaping (Bool) -> Void) {
        db.collection("friendRequests")
            .whereField("senderId", isEqualTo: senderId)
            .whereField("recipientId", isEqualTo: recipientId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("检查请求状态错误: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                completion(!(snapshot?.documents.isEmpty ?? true))
            }
    }
    
    // 接受好友请求
    func acceptFriendRequest(_ request: FriendRequest, completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        // 先更新请求状态
        db.collection("friendRequests").document(request.id)
            .updateData(["status": "accepted"]) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("更新请求状态错误: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                // 获取发送请求的用户ID
                self.db.collection("friendRequests").document(request.id)
                    .getDocument { (snapshot, error) in
                        if let error = error {
                            print("获取请求详情错误: \(error.localizedDescription)")
                            completion(false)
                            return
                        }
                        
                        guard let data = snapshot?.data(),
                              let senderId = data["senderId"] as? String,
                              let senderName = data["senderName"] as? String,
                              let senderEmail = data["senderEmail"] as? String else {
                            completion(false)
                            return
                        }
                        
                        // 创建好友关系（双向）
                        let batch = self.db.batch()
                        
                        // 当前用户的好友列表添加发送者
                        let currentUserFriendRef = self.db.collection("friends")
                            .document(currentUser.uid)
                            .collection("userFriends")
                            .document(senderId)
                        
                        batch.setData([
                            "id": senderId,
                            "name": senderName,
                            "email": senderEmail,
                            "timestamp": FieldValue.serverTimestamp()
                        ], forDocument: currentUserFriendRef)
                        
                        // 发送者的好友列表添加当前用户
                        let senderFriendRef = self.db.collection("friends")
                            .document(senderId)
                            .collection("userFriends")
                            .document(currentUser.uid)
                        
                        batch.setData([
                            "id": currentUser.uid,
                            "name": currentUser.displayName ?? "用户",
                            "email": currentUser.email ?? "",
                            "timestamp": FieldValue.serverTimestamp()
                        ], forDocument: senderFriendRef)
                        
                        // 提交批处理
                        batch.commit { error in
                            if let error = error {
                                print("创建好友关系错误: \(error.localizedDescription)")
                                completion(false)
                                return
                            }
                            
                            // 从待处理列表中移除并添加到好友列表
                            if let index = self.pendingRequests.firstIndex(where: { $0.id == request.id }) {
                                let newFriend = FriendItem(
                                    id: senderId,
                                    name: senderName,
                                    email: senderEmail,
                                    photoURL: nil
                                )
                                self.friends.append(newFriend)
                                self.pendingRequests.remove(at: index)
                            }
                            
                            completion(true)
                        }
                    }
            }
    }
    
    // 拒绝好友请求
    func rejectFriendRequest(_ request: FriendRequest, completion: @escaping (Bool) -> Void) {
        db.collection("friendRequests").document(request.id)
            .updateData(["status": "rejected"]) { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    print("拒绝请求错误: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                // 从待处理列表中移除
                if let index = self.pendingRequests.firstIndex(where: { $0.id == request.id }) {
                    self.pendingRequests.remove(at: index)
                }
                
                completion(true)
            }
    }
    
    // 删除好友
    func removeFriend(id: String, completion: @escaping (Bool) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(false)
            return
        }
        
        let batch = db.batch()
        
        // 从当前用户的好友列表中移除
        let currentUserFriendRef = db.collection("friends")
            .document(currentUser.uid)
            .collection("userFriends")
            .document(id)
        
        batch.deleteDocument(currentUserFriendRef)
        
        // 从另一方的好友列表中移除
        let otherUserFriendRef = db.collection("friends")
            .document(id)
            .collection("userFriends")
            .document(currentUser.uid)
        
        batch.deleteDocument(otherUserFriendRef)
        
        // 提交批处理
        batch.commit { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("删除好友错误: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            // 从列表中移除
            if let index = self.friends.firstIndex(where: { $0.id == id }) {
                self.friends.remove(at: index)
            }
            
            completion(true)
        }
    }
}

// 使Services能够访问FriendsService
extension Services {
    typealias FriendsService = NotimeToEat.FriendsService
    typealias Auth = FirebaseAuth.Auth
} 