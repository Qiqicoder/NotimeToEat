import SwiftUI

// 导入Globals.swift中定义的类型和管理器

struct CategoryView: View {
    @EnvironmentObject var foodStore: FoodStore
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Category.allCases, id: \.self) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        HStack {
                            Image(systemName: category.iconName)
                                .foregroundColor(.blue)
                            Text(NSLocalizedString(category.displayName, comment: ""))
                            Spacer()
                            Text("\(foodStore.items(inCategory: category).count)")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("nav_title_food_categories", comment: ""))
        }
    }
}

struct CategoryDetailView: View {
    @EnvironmentObject var foodStore: FoodStore
    @EnvironmentObject var shoppingListStore: ShoppingListStore
    let category: Category
    
    var body: some View {
        List {
            ForEach(foodStore.items(inCategory: category)) { item in
                FoodItemRow(item: item)
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