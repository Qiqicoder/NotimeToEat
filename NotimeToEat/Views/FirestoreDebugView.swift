import SwiftUI
import NotimeToEat
import UIKit

struct FirestoreDebugView: View {
    @ObservedObject private var friendsService = FriendsService.shared
    @State private var isRunningTest = false
    @State private var testResults = "点击\"测试Firestore连接\"按钮开始测试"
    @State private var collectionToCheck = "users"
    @State private var collectionCount = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var securityPIN = ""
    @State private var isAuthenticated = false
    @State private var failedAttempts = 0
    @State private var isLocked = false
    @Environment(\.presentationMode) var presentationMode
    
    // 安全PIN - 这应该是一个复杂的哈希或存储在更安全的地方
    private let correctPIN = "0311"
    
    var body: some View {
        Group {
            if isLocked {
                lockedView
            } else if !isAuthenticated {
                securityView
            } else {
                debugContentView
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
    }
    
    // 锁定视图 - 多次错误PIN后显示
    private var lockedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("调试模式已锁定")
                .font(.title)
                .fontWeight(.bold)
            
            Text("由于多次输入错误PIN，调试模式已被锁定。请稍后再试。")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("返回") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .padding()
    }
    
    // 安全验证视图
    private var securityView: some View {
        VStack(spacing: 25) {
            Image(systemName: "flame.shield")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Firebase调试模式")
                .font(.title)
                .fontWeight(.bold)
            
            Text("请输入开发者PIN码以继续")
                .font(.subheadline)
            
            SecureField("PIN码", text: $securityPIN)
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 150)
                .multilineTextAlignment(.center)
                .font(.title2)
            
            Button("验证") {
                verifyPIN()
            }
            .padding()
            .frame(width: 150)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            if failedAttempts > 0 {
                Text("PIN码错误！剩余尝试次数: \(3 - failedAttempts)")
                    .foregroundColor(.red)
            }
            
            Button("取消") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding(.top, 20)
        }
        .padding()
    }
    
    // 主调试内容视图
    private var debugContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Firebase调试中心")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 8)
                
                // 用户信息
                userInfoSection
                
                Divider()
                
                // 连接测试
                connectionTestSection
                
                Divider()
                
                // 集合检查
                collectionCheckSection
                
                Divider()
                
                // 发送测试请求
                sendTestRequestSection
                
                Divider()
                
                // 结果显示
                resultsSection
                
                Text("⚠️ 警告: 此调试工具仅供开发人员使用。请勿在没有指导的情况下使用。")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 20)
            }
            .padding()
        }
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用户信息")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading) {
                    if let user = Services.Auth.auth().currentUser {
                        HStack {
                            Text("用户ID:")
                            Text(user.uid)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                        }
                        
                        if let email = user.email {
                            HStack {
                                Text("邮箱:")
                                Text(email)
                            }
                        }
                        
                        if let name = user.displayName {
                            HStack {
                                Text("名称:")
                                Text(name)
                            }
                        }
                        
                        HStack {
                            Text("状态:")
                            Text("已登录")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    } else {
                        Text("登录状态: 未登录")
                            .foregroundColor(.red)
                        Text("请先登录才能调试Firestore")
                            .italic()
                    }
                }
                
                Spacer()
                
                if let user = Services.Auth.auth().currentUser,
                   let photoURL = user.photoURL {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("连接测试")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button(action: {
                runFirestoreTest()
            }) {
                HStack {
                    Image(systemName: "network")
                        .font(.system(size: 18))
                    
                    Text("测试Firestore连接")
                        .fontWeight(.medium)
                    
                    if isRunningTest {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isRunningTest || Services.Auth.auth().currentUser == nil)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var collectionCheckSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("集合文档计数")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass.circle")
                        .foregroundColor(.blue)
                    
                    TextField("集合名称", text: $collectionToCheck)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        checkCollection()
                    }) {
                        Text("检查")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isRunningTest || Services.Auth.auth().currentUser == nil)
                }
                
                if collectionCount > 0 {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.green)
                        Text("集合 '\(collectionToCheck)' 中有 \(collectionCount) 个文档")
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var sendTestRequestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("发送测试好友请求")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.blue)
                    
                    TextField("测试用户邮箱", text: .constant("test@example.com"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        sendTestFriendRequest()
                    }) {
                        Text("发送")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isRunningTest || Services.Auth.auth().currentUser == nil)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("测试结果")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(friendsService.debugMessage.isEmpty ? testResults : friendsService.debugMessage)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(8)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // 验证PIN码
    private func verifyPIN() {
        if securityPIN == correctPIN {
            withAnimation {
                isAuthenticated = true
                failedAttempts = 0
            }
            
            // 触觉反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } else {
            failedAttempts += 1
            securityPIN = ""
            
            // 触觉反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            // 3次错误尝试后锁定
            if failedAttempts >= 3 {
                withAnimation {
                    isLocked = true
                }
            }
        }
    }
    
    // 执行Firestore连接测试
    private func runFirestoreTest() {
        guard !isRunningTest else { return }
        
        isRunningTest = true
        testResults = "正在测试Firestore连接..."
        
        friendsService.debugFirestore { success, message in
            DispatchQueue.main.async {
                self.isRunningTest = false
                self.testResults = message
                
                // 如果成功但没有数据，显示提示
                if success && (message.contains("好友数: 0") && message.contains("好友请求数: 0")) {
                    self.alertMessage = "连接测试成功，但没有找到任何好友或请求数据。这可能是正常的，如果你还没有添加任何好友。"
                    self.showingAlert = true
                }
            }
        }
    }
    
    // 检查集合文档数量
    private func checkCollection() {
        guard !collectionToCheck.isEmpty else { return }
        
        isRunningTest = true
        friendsService.checkCollectionCount(collection: collectionToCheck) { count, error in
            DispatchQueue.main.async {
                self.isRunningTest = false
                
                if let error = error {
                    self.alertMessage = "检查失败: \(error.localizedDescription)"
                    self.showingAlert = true
                } else {
                    self.collectionCount = count
                    if count == 0 {
                        self.alertMessage = "集合 '\(self.collectionToCheck)' 中没有文档，或者您没有权限访问。"
                        self.showingAlert = true
                    }
                }
            }
        }
    }
    
    // 发送测试好友请求
    private func sendTestFriendRequest() {
        guard let currentUser = Services.Auth.auth().currentUser else {
            alertMessage = "您需要先登录才能发送好友请求"
            showingAlert = true
            return
        }
        
        isRunningTest = true
        testResults = "正在发送测试好友请求..."
        
        // 这里使用硬编码的测试邮箱，在实际应用中应该有一个输入框
        friendsService.sendFriendRequest(to: "test@example.com") { success, message in
            DispatchQueue.main.async {
                self.isRunningTest = false
                
                if success {
                    self.testResults = "成功发送测试好友请求: \(message ?? "")"
                } else {
                    self.testResults = "发送测试好友请求失败: \(message ?? "未知错误")"
                    self.alertMessage = message ?? "发送失败，请检查日志"
                    self.showingAlert = true
                }
            }
        }
    }
}

struct FirestoreDebugView_Previews: PreviewProvider {
    static var previews: some View {
        FirestoreDebugView()
    }
} 
