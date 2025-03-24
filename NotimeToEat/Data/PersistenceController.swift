import Foundation
import CoreData

/// 管理 Core Data 存储并提供视图上下文
class PersistenceController {
    // 共享单例实例
    static let shared = PersistenceController()
    
    // 测试和预览用的实例，包含样本数据
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // 创建10个样本食物
        let viewContext = controller.container.viewContext
        for i in 0..<10 {
            let newFood = CommonFood(context: viewContext)
            newFood.chineseName = "样本食物\(i)"
            newFood.englishName = "Sample Food \(i)"
            newFood.category = i % 6 == 0 ? "vegetable" : 
                              i % 6 == 1 ? "fruit" : 
                              i % 6 == 2 ? "meat" : 
                              i % 6 == 3 ? "seafood" : 
                              i % 6 == 4 ? "dairy" : "grain"
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("创建预览数据时无法保存上下文: \(nsError), \(nsError.userInfo)")
        }
        return controller
    }()
    
    // Core Data 容器
    let container: NSPersistentContainer
    
    // Context for view operations (main thread)
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    // Initialize with store configuration
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "NotimeToEat")
        
        // Print the database path
        print("数据库路径: \(NSPersistentContainer.defaultDirectoryURL().path)")
          
        if inMemory {
            // 内存存储用于测试和预览
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Configure the view context for automatic merge
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // Create a new background context for background operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // Save context if it has changes
    func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Unresolved error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
} 