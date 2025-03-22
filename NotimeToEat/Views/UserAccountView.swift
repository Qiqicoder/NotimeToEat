import SwiftUI
import GoogleSignInSwift

struct UserAccountView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingLoginSheet = false
    @State private var loginError: String? = nil
    @State private var showErrorAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 用户信息部分
                if authService.isAuthenticated {
                    userInfoSection
                } else {
                    notLoggedInSection
                }
                
                // 登录/登出按钮
                loginButtons
                
                Spacer()
            }
            .padding()
            .navigationTitle("账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("登录失败"),
                    message: Text(loginError ?? "未知错误"),
                    dismissButton: .default(Text("确定")) {
                        loginError = nil
                    }
                )
            }
            // 使用sheet的onDismiss而不是在回调中手动关闭
            .sheet(isPresented: $showingLoginSheet, onDismiss: {
                // 当sheet关闭后，如果有错误，显示错误警报
                if loginError != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showErrorAlert = true
                    }
                }
            }) {
                LoginView(completion: { success, error in
                    if !success {
                        if let error = error {
                            loginError = error.localizedDescription
                            print("登录失败: \(error.localizedDescription)")
                        } else {
                            loginError = "登录失败，请重试"
                            print("登录失败: 未知错误")
                        }
                    } else {
                        print("登录成功")
                        loginError = nil
                    }
                    // 完全在回调中关闭sheet，而不是在LoginView中
                    DispatchQueue.main.async {
                        showingLoginSheet = false
                    }
                })
            }
        }
    }
    
    // 用户信息显示部分
    private var userInfoSection: some View {
        VStack(spacing: 20) {
            // 用户头像
            if let photoURL = authService.currentUser.photoURL {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                .padding(.top)
            } else {
                // 使用初始字母作为头像
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 100, height: 100)
                    Text(authService.currentUser.initials)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top)
            }
            
            // 用户名称
            Text(authService.currentUser.displayName ?? "未知用户")
                .font(.title)
                .fontWeight(.bold)
            
            // 用户邮箱
            if let email = authService.currentUser.email {
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Divider()
                .padding(.vertical)
        }
    }
    
    // 未登录状态显示
    private var notLoggedInSection: some View {
        VStack(spacing: 15) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.gray)
                .padding(.top, 30)
            
            Text("未登录")
                .font(.title)
                .fontWeight(.medium)
            
            Text("登录以同步您的数据和设置")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Divider()
                .padding(.vertical)
        }
    }
    
    // 登录/登出按钮
    private var loginButtons: some View {
        Group {
            if authService.isAuthenticated {
                // 登出按钮
                Button(action: {
                    authService.signOut { success in
                        if success {
                            // 登出成功
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("退出登录")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                // Google登录按钮
                GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .wide, state: .normal)) {
                    // 显示Google登录
                    loginError = nil  // 重置任何先前的错误
                    showErrorAlert = false
                    showingLoginSheet = true
                }
                .frame(height: 50)
                .padding(.horizontal)
                .cornerRadius(10)
            }
        }
    }
}

// 登录视图 - 处理登录流程的presentation controller
struct LoginView: UIViewControllerRepresentable {
    @EnvironmentObject var authService: AuthService
    var completion: (Bool, Error?) -> Void
    
    class Coordinator: NSObject {
        var parent: LoginView
        var hasTriggeredLogin = false
        
        init(parent: LoginView) {
            self.parent = parent
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // 使用coordinator来跟踪是否已经触发了登录，防止重复调用
        if !context.coordinator.hasTriggeredLogin {
            context.coordinator.hasTriggeredLogin = true
            
            // 延迟一些时间确保视图已经完全显示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                authService.signInWithGoogle(presentingViewController: uiViewController) { success, error in
                    // 完成回调
                    completion(success, error)
                }
            }
        }
    }
}

struct UserAccountView_Previews: PreviewProvider {
    static var previews: some View {
        UserAccountView()
            .environmentObject(AuthService.shared)
    }
} 