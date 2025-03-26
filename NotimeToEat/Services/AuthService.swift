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
    
    // 登录状态变更通知
    var onLoginStateChanged: ((LoginStateChange) -> Void)? = { _ in 
        print("登录状态变更处理器未设置") 
    }
    
    // 登录状态变更类型
    enum LoginStateChange {
        case loggedIn(User)       // 新登录
        case loggedOut(User)      // 登出
        case switchedUser(oldUser: User, newUser: User)  // 切换用户
    }
    
    init() {
        print("AuthService 初始化中...")
        // 尝试从UserDefaults恢复用户登录状态
        restoreUserSession()
        
        // 监听Firebase认证状态变化
        Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            // 保存旧用户以便检测用户切换
            let oldUser = self.currentUser
            
            if let firebaseUser = user {
                // 用户已登录
                let appUser = User(
                    id: firebaseUser.uid,
                    email: firebaseUser.email ?? "",
                    displayName: firebaseUser.displayName ?? firebaseUser.email?.components(separatedBy: "@").first ?? "用户",
                    photoURL: firebaseUser.photoURL
                )
                
                DispatchQueue.main.async {
                    // 检查用户是否变更
                    let isUserSwitched = self.isAuthenticated && oldUser.id != appUser.id
                    let isNewLogin = !self.isAuthenticated
                    
                    // 更新当前用户
                    self.currentUser = appUser
                    self.isAuthenticated = true
                    self.saveUserSession()
                    
                    // 保存/更新用户信息到Firestore
                    self.saveUserToFirestore(user: appUser)
                    
                    // 通知登录状态变更
                    if isNewLogin {
                        // 新登录
                        print("触发新登录事件: \(appUser.email ?? "unknown")")
                        self.onLoginStateChanged?(.loggedIn(appUser))
                    } else if isUserSwitched {
                        // 切换用户
                        print("触发用户切换事件: \(oldUser.email ?? "unknown") -> \(appUser.email ?? "unknown")")
                        self.onLoginStateChanged?(.switchedUser(oldUser: oldUser, newUser: appUser))
                    }
                }
            } else {
                // 用户已登出
                DispatchQueue.main.async {
                    let wasLoggedIn = self.isAuthenticated
                    let previousUser = self.currentUser
                    
                    self.currentUser = User.anonymous
                    self.isAuthenticated = false
                    self.saveUserSession()
                    
                    // 通知登出状态变更
                    if wasLoggedIn {
                        print("触发用户登出事件: \(previousUser.email ?? "unknown")")
                        self.onLoginStateChanged?(.loggedOut(previousUser))
                    }
                }
            }
        }
        
        print("AuthService 初始化完成，认证状态: \(isAuthenticated ? "已登录" : "未登录")")
        
        // 确保onLoginStateChanged在初始化结束时不是nil
        if onLoginStateChanged == nil {
            print("警告: onLoginStateChanged 在初始化结束时仍为 nil，设置默认空实现")
            onLoginStateChanged = { _ in print("默认的登录状态处理器") }
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
        let previousUser = currentUser
        print("开始登出用户: \(previousUser.email ?? "unknown")")
        
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
            
            // 通知登出状态
            print("手动触发用户登出事件: \(previousUser.email ?? "unknown")")
            self.onLoginStateChanged?(.loggedOut(previousUser))
            
            completion(true)
        }
    }
    
    // MARK: - 数据同步处理
    
    /// 询问用户是否要上传本地数据到云端
    /// - Parameters:
    ///   - localFoodItems: 本地食物列表
    ///   - uploadConfirmed: 用户确认上传回调
    ///   - cancelAction: 用户取消操作回调
    func promptForDataUpload(localFoodItems: [FoodItem], uploadConfirmed: @escaping ([FoodItem]) -> Void, cancelAction: @escaping () -> Void) {
        // 这个方法不实际显示UI，它只是提供数据并回调。
        // UI部分将由调用代码处理
        
        // 如果本地没有数据，直接跳过询问
        if localFoodItems.isEmpty {
            cancelAction()
            return
        }
        
        // 返回本地食物列表，让UI层询问用户
        uploadConfirmed(localFoodItems)
    }
    
    /// 询问用户是否要删除本地数据
    /// - Parameters:
    ///   - localFoodItems: 本地食物列表
    ///   - deleteConfirmed: 用户确认删除回调
    ///   - cancelAction: 用户取消操作回调
    func promptForDataDeletion(localFoodItems: [FoodItem], deleteConfirmed: @escaping ([FoodItem]) -> Void, cancelAction: @escaping () -> Void) {
        // 这个方法不实际显示UI，它只是提供数据并回调。
        // UI部分将由调用代码处理
        
        // 如果本地没有数据，直接跳过询问
        if localFoodItems.isEmpty {
            cancelAction()
            return
        }
        
        // 返回本地食物列表，让UI层询问用户
        deleteConfirmed(localFoodItems)
    }
    
    /// 在登录后从Firestore拉取并合并数据
    /// - Parameters:
    ///   - localItems: 本地食物列表
    ///   - completion: 合并完成回调，返回合并后的食物列表
    func fetchAndMergeCloudData(localItems: [FoodItem], completion: @escaping ([FoodItem]) -> Void) {
        // 使用FirestoreService获取云端数据
        FirestoreService.shared.fetchFoodItems { cloudItems, error in
            if let error = error {
                print("从云端获取数据失败: \(error.localizedDescription)")
                completion(localItems) // 如果失败，保持本地数据不变
                return
            }
            
            guard let cloudItems = cloudItems else {
                completion(localItems) // 如果没有云端数据，保持本地数据不变
                return
            }
            
            // 合并本地和云端数据
            let mergedItems = FirestoreService.shared.mergeFoodItems(localItems: localItems, cloudItems: cloudItems)
            completion(mergedItems)
        }
    }
}

// 使Services能够访问AuthService
//extension Services {
//    typealias AuthService = AuthService
//} 
