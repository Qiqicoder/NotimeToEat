import Foundation
import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

class AuthService: ObservableObject {
    // 单例模式
    static let shared = AuthService()
    
    // 用户数据
    @Published var currentUser: User = User.anonymous
    @Published var isAuthenticated: Bool = false
    
    // 记住登录状态的UserDefaults键
    private let userDefaultsKey = "loggedInUser"
    
    private init() {
        // 尝试从UserDefaults恢复用户登录状态
        restoreUserSession()
    }
    
    // 恢复用户会话
    private func restoreUserSession() {
        if let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
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
    
    // Google登录
    func signInWithGoogle(presentingViewController: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        // 确保已经配置了Google登录
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
        guard clientID != nil else {
            let error = NSError(domain: "com.notimetoeat.auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Google登录配置错误：缺少Client ID"])
            print("Google登录失败: Client ID not found in Info.plist")
            completion(false, error)
            return
        }
        
        // 检查是否有现有的登录会话
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            guard let self = self else { return }
            
            if let user = user, error == nil {
                // 用户已经登录，直接使用现有会话
                self.processSignInResult(user: user, completion: completion)
                return
            }
            
            // 禁用当前已经显示的其他任何弹窗或Sheet
            if let topController = self.getTopViewController(from: presentingViewController) {
                for subview in topController.view.subviews {
                    if subview.isKind(of: UIVisualEffectView.self) || subview.isKind(of: UIAlertController.self) {
                        subview.removeFromSuperview()
                    }
                }
                
                // 在GoogleSign-In 8.0.0版本中使用signIn方法
                // 禁用任何现有的正在呈现的内容
                if topController.presentedViewController != nil {
                    topController.dismiss(animated: false) {
                        self.initiateGoogleSignIn(presentingViewController: topController, completion: completion)
                    }
                } else {
                    self.initiateGoogleSignIn(presentingViewController: topController, completion: completion)
                }
            } else {
                self.initiateGoogleSignIn(presentingViewController: presentingViewController, completion: completion)
            }
        }
    }
    
    // 辅助方法来获取顶层视图控制器
    private func getTopViewController(from viewController: UIViewController) -> UIViewController? {
        // 如果当前控制器正在显示其他控制器，获取显示的控制器
        if let presented = viewController.presentedViewController {
            return self.getTopViewController(from: presented)
        }
        
        // 如果是TabBarController，获取选中的控制器
        if let tabBarController = viewController as? UITabBarController {
            if let selected = tabBarController.selectedViewController {
                return self.getTopViewController(from: selected)
            }
        }
        
        // 如果是NavigationController，获取可见的控制器
        if let navigationController = viewController as? UINavigationController {
            if let visibleViewController = navigationController.visibleViewController {
                return self.getTopViewController(from: visibleViewController)
            }
        }
        
        // 返回当前控制器
        return viewController
    }
    
    // 启动Google登录流程
    private func initiateGoogleSignIn(presentingViewController: UIViewController, completion: @escaping (Bool, Error?) -> Void) {
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] signInResult, error in
            guard let self = self else { return }
            
            if let error = error {
                if let authError = error as? NSError {
                    // 区分登录错误类型，但减少日志输出
                    if authError.domain == "com.google.GIDSignIn" && authError.code == -5 {
                        // 用户取消了登录
                        completion(false, NSError(domain: "AuthService", code: 2, userInfo: [NSLocalizedDescriptionKey: "登录过程被中断，请重试"]))
                    } else {
                        // 其他登录错误
                        completion(false, NSError(domain: "AuthService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Google登录失败：\(authError.localizedDescription)"]))
                    }
                } else {
                    // 通用错误
                    completion(false, NSError(domain: "AuthService", code: 4, userInfo: [NSLocalizedDescriptionKey: "登录失败，请重试"]))
                }
                return
            }
            
            guard let signInResult = signInResult else {
                completion(false, NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取用户资料"]))
                return
            }
            
            // 处理登录结果
            self.processSignInResult(user: signInResult.user, completion: completion)
        }
    }
    
    // 处理登录结果
    private func processSignInResult(user: GIDGoogleUser, completion: @escaping (Bool, Error?) -> Void) {
        // 创建用户对象
        let appUser = User(
            id: user.userID ?? "",
            email: user.profile?.email ?? "",
            displayName: user.profile?.name ?? "",
            photoURL: user.profile?.imageURL(withDimension: 100)
        )
        // 更新当前用户并保存会话
        DispatchQueue.main.async {
            self.currentUser = appUser
            self.isAuthenticated = true
            self.saveUserSession()
            completion(true, nil)
        }
    }
    
    // 退出登录
    func signOut(completion: @escaping (Bool) -> Void) {
        GIDSignIn.sharedInstance.signOut()
        
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
