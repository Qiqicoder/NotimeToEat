import SwiftUI
import FirebaseAuth

extension Services {
    // 添加对FirebaseAuth的访问
    typealias Auth = FirebaseAuth.Auth
}

struct FirestoreDebugView: View {
    @ObservedObject private var friendsService = FriendsService.shared
    @State private var isRunningTest = false
    @State private var testResults = "点击\"测试Firestore连接\"按钮开始测试"
    @State private var collectionToCheck = "users"
    @State private var collectionCount = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Firestore数据库调试")
                    .font(.largeTitle)
                    .fontWeight(.bold)
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
                
                // 结果显示
                resultsSection
            }
            .padding()
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("提示"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
        }
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用户信息")
                .font(.headline)
            
            if let user = Services.Auth.auth().currentUser {
                Text("用户ID: \(user.uid)")
                if let email = user.email {
                    Text("邮箱: \(email)")
                }
                if let name = user.displayName {
                    Text("名称: \(name)")
                }
                Text("登录状态: 已登录")
                    .foregroundColor(.green)
            } else {
                Text("登录状态: 未登录")
                    .foregroundColor(.red)
                Text("请先登录才能调试Firestore")
                    .italic()
            }
        }
    }
    
    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("连接测试")
                .font(.headline)
            
            Button(action: {
                runFirestoreTest()
            }) {
                HStack {
                    Text("测试Firestore连接")
                    if isRunningTest {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(isRunningTest || Services.Auth.auth().currentUser == nil)
        }
    }
    
    private var collectionCheckSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("集合文档计数")
                .font(.headline)
            
            HStack {
                TextField("集合名称", text: $collectionToCheck)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: {
                    checkCollection()
                }) {
                    Text("检查")
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isRunningTest || Services.Auth.auth().currentUser == nil)
            }
            
            if collectionCount > 0 {
                Text("集合 '\(collectionToCheck)' 中有 \(collectionCount) 个文档")
                    .foregroundColor(.green)
            }
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("测试结果")
                .font(.headline)
            
            Text(friendsService.debugMessage.isEmpty ? testResults : friendsService.debugMessage)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .multilineTextAlignment(.leading)
        }
    }
    
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
}

struct FirestoreDebugView_Previews: PreviewProvider {
    static var previews: some View {
        FirestoreDebugView()
    }
} 
