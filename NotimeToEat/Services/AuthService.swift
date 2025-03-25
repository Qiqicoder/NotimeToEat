import Foundation
import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore
import FirebaseFirestore

class AuthService: ObservableObject {
    // 单例模式
    static let shared = AuthService()
    
    // 用户数据
    @Published var currentUser: User = User.anonymous
    @Published var isAuthenticated: Bool = false
    
    // 记住登录状态的UserDefaults键
    private let userDefaultsKey = "loggedInUser"
    
    // Firestore引用
    private let db = Firestore.firestore()
    
    private init() {
        // 尝试从UserDefaults恢复用户登录状态
        restoreUserSession()
        
        // 监听Firebase认证状态变化
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            if let firebaseUser = user {
                // 用户已登录
                let appUser = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    displayName: firebaseUser.displayName ?? firebaseUser.email?.components(separatedBy: "@").first ?? "用户",
                    photoURL: firebaseUser.photoURL
                )
                
                DispatchQueue.main.async {
                    self.currentUser = appUser
                    self.isAuthenticated = true
                    self.saveUserSession()
                    
                    // 保存/更新用户信息到Firestore
                    self.saveUserToFirestore(user: appUser)
                }
            } else {
                // 用户已登出
                DispatchQueue.main.async {
                    self.currentUser = User.anonymous
                    self.isAuthenticated = false
                    self.saveUserSession()
                }
            }
        }
    }
    
    // 恢复用户会话
    private func restoreUserSession() {
        if var userData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = user.isLoggedIn
        }
    }
    
    // 保存用户会话
    private func saveUserSession() {
        if let encodedData = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsKey)
        }
    }
    
    // 将用户信息保存到Firestore
    private func saveUserToFirestore(user: User) {
        var userData: [String: Any] = [
            "email": user.email,
            "displayName": user.displayName ?? "用户",
            "lastActive": FieldValue.serverTimestamp()
        ]
        
        // 如果有头像URL，也保存
        if let photoURL = user.photoURL?.absoluteString {
            userData["photoURL"] = photoURL
        }
        
        // 使用用户ID作为文档ID
        db.collection("users").document(user.id).setData(userData, merge: true) { error in
            if let error = error {
                print("保存用户信息到Firestore失败: \(error.localizedDescription)")
            } else {
                print("成功保存用户信息到Firestore")
            }
        }
    }
    
    // Gmail登录
    func signInWithGmail(presentingViewController: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            let error = NSError(domain: "com.notimetoeat.auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Firebase配置错误：无法获取ClientID"])
            print("Gmail登录失败: Client ID not found")
            completion(false, error)
            return
        }
        
        // 创建Google登录配置
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // 开始登录流程
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Gmail登录错误: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                let error = NSError(domain: "com.notimetoeat.auth", code: 501, userInfo: [NSLocalizedDescriptionKey: "无法获取用户令牌"])
                print("Gmail登录失败: 无法获取用户令牌")
                completion(false, error)
                return
            }
            
            // 使用Google的idToken和accessToken创建Firebase凭证
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
            
            // 使用凭证登录Firebase
            Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firebase使用Gmail凭证登录失败: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    completion(false, NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取用户资料"]))
                    return
                }
                
                // 创建应用用户
                let appUser = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    displayName: firebaseUser.displayName ?? "用户",
                    photoURL: firebaseUser.photoURL
                )
                
                // 更新当前用户并保存会话
                DispatchQueue.main.async {
                    self.currentUser = appUser
                    self.isAuthenticated = true
                    self.saveUserSession()
                    
                    // 保存用户信息到Firestore
                    self.saveUserToFirestore(user: appUser)
                    
                    completion(true, nil)
                }
            }
        }
    }
    
    // 使用电子邮件注册用户
    func createUserWithEmail(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("创建用户失败: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                completion(false, NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取用户资料"]))
                return
            }
            
            // 创建应用用户
            let appUser = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? "",
                displayName: firebaseUser.displayName ?? email.components(separatedBy: "@").first ?? "用户",
                photoURL: firebaseUser.photoURL
            )
            
            // 更新当前用户并保存会话
            DispatchQueue.main.async {
                self.currentUser = appUser
                self.isAuthenticated = true
                self.saveUserSession()
                
                // 保存用户信息到Firestore
                self.saveUserToFirestore(user: appUser)
                
                completion(true, nil)
            }
        }
    }
    
    // 使用电子邮件登录
    func signInWithEmail(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("邮箱登录失败: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let firebaseUser = authResult?.user else {
                completion(false, NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取用户资料"]))
                return
            }
            
            // 创建应用用户
            let appUser = User(
                id: firebaseUser.uid,
                email: firebaseUser.email ?? "",
                displayName: firebaseUser.displayName ?? email.components(separatedBy: "@").first ?? "用户",
                photoURL: firebaseUser.photoURL
            )
            
            // 更新当前用户并保存会话
            DispatchQueue.main.async {
                self.currentUser = appUser
                self.isAuthenticated = true
                self.saveUserSession()
                
                // 保存/更新用户信息到Firestore
                self.saveUserToFirestore(user: appUser)
                
                completion(true, nil)
            }
        }
    }
    
    // 退出登录
    func signOut(completion: @escaping (Bool) -> Void) {
        do {
            try Auth.auth().signOut()
            // 同时退出Google账号
            GIDSignIn.sharedInstance.signOut()
        } catch {
            print("Firebase登出错误: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentUser = User.anonymous
            self.isAuthenticated = false
            self.saveUserSession()
            completion(true)
        }
    }
}

// 使Services能够访问AuthService
extension Services {
    typealias AuthService = NotimeToEat.AuthService
} 
