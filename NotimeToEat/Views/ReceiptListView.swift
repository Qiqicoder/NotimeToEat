import SwiftUI

struct ReceiptListView: View {
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var foodStore: FoodStore
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 按时间降序显示所有小票
                    ForEach(sortedReceipts) { receipt in
                        ReceiptCard(receipt: receipt)
                    }
                    
                    if receiptStore.receipts.isEmpty {
                        ContentUnavailableView(
                            "暂无购物小票",
                            systemImage: "doc.text.image",
                            description: Text("添加食物时上传小票，这里将以时间轴形式显示")
                        )
                        .padding(.top, 100)
                    }
                }
                .padding()
            }
            .navigationTitle("购物小票")
        }
    }
    
    private var sortedReceipts: [Receipt] {
        // 按添加日期降序排列
        return receiptStore.receipts.sorted { $0.addedDate > $1.addedDate }
    }
}

// 单个小票卡片视图
struct ReceiptCard: View {
    let receipt: Receipt
    @EnvironmentObject var receiptStore: ReceiptStore
    @EnvironmentObject var foodStore: FoodStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日期和关联食物
            HStack {
                VStack(alignment: .leading) {
                    Text(formatDate(receipt.addedDate))
                        .font(.headline)
                    
                    if let food = foodForReceipt {
                        Text(food.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("关联食物已删除")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                // 删除按钮
                Button(action: {
                    receiptStore.deleteReceipt(receipt)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            // 小票图片
            if let image = receiptStore.loadImage(id: receipt.imageID) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(10)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    // 获取与小票关联的食物
    private var foodForReceipt: FoodItem? {
        return foodStore.foodItems.first { $0.id == receipt.foodItemID }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

#if DEBUG
struct ReceiptListView_Previews: PreviewProvider {
    static var previews: some View {
        ReceiptListView()
            .environmentObject(ReceiptStore())
            .environmentObject(FoodStore())
    }
}
#endif 