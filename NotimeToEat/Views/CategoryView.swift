import SwiftUI

// 导入Globals.swift中定义的类型和管理器
// 导入共享的FoodItemRow组件

struct CategoryView: View {
    @EnvironmentObject var foodStore: FoodStore
    
    // 定义网格布局，增加间距
    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 25) {
                    ForEach(Category.allCases, id: \.self) { category in
                        NavigationLink(destination: CategoryDetailView(category: category)) {
                            CategoryCard(
                                category: category,
                                count: foodStore.items(inCategory: category).count
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle(NSLocalizedString("nav_title_food_categories", comment: ""))
        }
    }
}

// 新添加的CategoryCard组件
struct CategoryCard: View {
    let category: Category
    let count: Int
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 20)  // 增加圆角
                    .fill(Color.gray.opacity(0.1))  // 使用SwiftUI原生颜色代替UIKit颜色
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                VStack(spacing: 16) {  // 增加内部间距
                    Image(systemName: category.iconName)
                        .font(.system(size: 38))  // 增大图标
                        .foregroundColor(.blue)
                    
                    Text(NSLocalizedString(category.displayName, comment: ""))
                        .font(.title3)  // 增大字体
                        .bold()  // 加粗文字
                        .multilineTextAlignment(.center)
                    
                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 30)  // 增加上下内边距
                .padding(.horizontal, 16)
            }
        }
        .aspectRatio(0.9, contentMode: .fit)  // 调整比例，略微增加高度
        .padding(.bottom, 5)  // 底部添加一点空间
    }
}

struct CategoryDetailView: View {
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var shoppingListStore: ShoppingListStore
    let category: Category
    
    var body: some View {
        List {
            ForEach(foodStore.items(inCategory: category)) { item in
                // 使用共享的FoodItemRow组件，并配置为简单标签样式，不显示编辑按钮
                FoodItemRow(item: item, showEditButton: false, tagDisplayStyle: .simple)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            foodStore.deleteFood(item)
                        } label: {
                            Label(NSLocalizedString("delete_simply", comment: ""), systemImage: "trash")
                        }
                        
                        Button {
                            foodStore.deleteFood(item)
                            shoppingListStore.addFromFood(item)
                        } label: {
                            Label(NSLocalizedString("delete_add_to_shopping_list", comment: ""), systemImage: "cart.badge.plus")
                        }
                        .tint(.green)
                    }
            }
        }
        .navigationTitle(category.displayName)
    }
}

#Preview {
    CategoryView()
        .environmentObject(FoodStore())
        .environmentObject(ShoppingListStore())
} 