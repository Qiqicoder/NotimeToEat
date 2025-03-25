import SwiftUI
import GoogleSignIn

struct UserAccountView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    @State private var showingEmailLoginSheet = false
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
            // 邮箱登录Sheet
            .sheet(isPresented: $showingEmailLoginSheet, onDismiss: {
                if loginError != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showErrorAlert = true
                    }
                }
            }) {
                EmailLoginView(completion: { success, error in
                    if !success {
                        if let error = error {
                            loginError = error.localizedDescription
                            print("邮箱登录失败: \(error.localizedDescription)")
                        } else {
                            loginError = "登录失败，请重试"
                            print("邮箱登录失败: 未知错误")
                        }
                    } else {
                        print("邮箱登录成功")
                        loginError = nil
                    }
                    DispatchQueue.main.async {
                        showingEmailLoginSheet = false
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
                VStack(spacing: 15) {
                    // Gmail登录按钮
                    Button(action: {
                        loginWithGmail()
                    }) {
                        HStack {
                            Image("google_icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing, 2)
                            Text("使用Gmail账号登录")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // 邮箱登录按钮
                    Button(action: {
                        loginError = nil
                        showErrorAlert = false
                        showingEmailLoginSheet = true
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("邮箱登录/注册")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // Gmail登录方法
    private func loginWithGmail() {
        // 获取当前视图的UIViewController
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("无法获取根视图控制器")
            return
        }
        
        // 获取当前呈现的控制器
        var currentController = rootViewController
        while let presentedController = currentController.presentedViewController {
            currentController = presentedController
        }
        
        loginError = nil
        showErrorAlert = false
        
        // 调用AuthService的Gmail登录方法
        authService.signInWithGmail(presentingViewController: currentController) { success, error in
            if !success {
                if let error = error {
                    self.loginError = error.localizedDescription
                    print("Gmail登录失败: \(error.localizedDescription)")
                } else {
                    self.loginError = "登录失败，请重试"
                    print("Gmail登录失败: 未知错误")
                }
                self.showErrorAlert = true
            } else {
                print("Gmail登录成功")
            }
        }
    }
}

// EmailLoginView - 电子邮件登录/注册视图
struct EmailLoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoginMode = true
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var completion: (Bool, Error?) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(isLoginMode ? "登录" : "注册")) {
                    TextField("电子邮箱", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("密码", text: $password)
                    
                    if !isLoginMode {
                        SecureField("确认密码", text: $confirmPassword)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(action: handleAuthentication) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(isLoginMode ? "登录" : "注册")
                        }
                    }
                    .disabled(!isValidForm || isLoading)
                    
                    Button(action: {
                        isLoginMode.toggle()
                        errorMessage = nil
                    }) {
                        Text(isLoginMode ? "没有账号？点击注册" : "已有账号？点击登录")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle(isLoginMode ? "账号登录" : "账号注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        completion(false, nil)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var isValidForm: Bool {
        if email.isEmpty || password.isEmpty {
            return false
        }
        
        if !isLoginMode && (password != confirmPassword || password.count < 6) {
            return false
        }
        
        return true
    }
    
    private func handleAuthentication() {
        errorMessage = nil
        isLoading = true
        
        // 验证输入
        if !isValidForm {
            if password.count < 6 {
                errorMessage = "密码长度不能少于6位"
            } else if !isLoginMode && password != confirmPassword {
                errorMessage = "两次输入的密码不一致"
            } else {
                errorMessage = "请填写所有必填项"
            }
            isLoading = false
            return
        }
        
        if isLoginMode {
            // 登录
            authService.signInWithEmail(email: email, password: password) { success, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        completion(false, error)
                    } else if success {
                        completion(true, nil)
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        errorMessage = "登录失败，请稍后重试"
                        completion(false, NSError(domain: "EmailAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "未知错误"]))
                    }
                }
            }
        } else {
            // 注册
            authService.createUserWithEmail(email: email, password: password) { success, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        completion(false, error)
                    } else if success {
                        completion(true, nil)
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        errorMessage = "注册失败，请稍后重试"
                        completion(false, NSError(domain: "EmailAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "未知错误"]))
                    }
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