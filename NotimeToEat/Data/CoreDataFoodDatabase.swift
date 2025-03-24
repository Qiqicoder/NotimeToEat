import Foundation
import CoreData
import SwiftUI

// Self-contained Core Data food database implementation
class CoreDataFoodDatabase: ObservableObject {
    // Singleton instance
    static let shared = CoreDataFoodDatabase()
    
    // Access to Core Data persistence controller
    private let container: NSPersistentContainer
    
    // Initialize with Core Data container
    private init() {
        container = NSPersistentContainer(name: "NotimeToEat")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading Core Data stores: \(error.localizedDescription)")
            }
        }
        populateInitialDataIfNeeded()
    }
    
    // MARK: - Public Methods
    
    // Get all food names from Core Data
    var allFoodNames: [String] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        
        print("DEBUG: Fetching all food names from database")
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            if results.isEmpty {
                print("DEBUG: Database appears to be empty - no CommonFood entities found")
                return []
            } 
            
            print("DEBUG: Found \(results.count) CommonFood entities in database")
            
            // Get all non-empty Chinese names
            var names = results.compactMap { $0.value(forKey: "chineseName") as? String }
            
            // Get all non-empty English names
            let englishNames = results.compactMap { $0.value(forKey: "englishName") as? String }
            
            // Merge Chinese and English names (ensure no duplicates)
            names.append(contentsOf: englishNames)
            let uniqueNames = Array(Set(names))
            
            // Print the first few entries for debugging
            let maxEntriesToShow = min(5, results.count)
            for i in 0..<maxEntriesToShow {
                let obj = results[i]
                let name = obj.value(forKey: "chineseName") as? String ?? "nil"
                let englishName = obj.value(forKey: "englishName") as? String ?? "nil"
                let category = obj.value(forKey: "category") as? String ?? "nil"
                print("DEBUG: Entry \(i): chineseName='\(name)', englishName='\(englishName)', category='\(category)'")
            }
            
            print("DEBUG: Returning \(uniqueNames.count) food names (combined Chinese and English)")
            return uniqueNames
        } catch {
            print("Error fetching food names: \(error.localizedDescription)")
            return []
        }
    }
    
    // Get food names for a specific category
    func foodNames(forCategory categoryString: String) -> [String] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        
        // Try both exact match and case-insensitive match
        let predicate1 = NSPredicate(format: "category == %@", categoryString)
        let predicate2 = NSPredicate(format: "category CONTAINS[cd] %@", categoryString)
        fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [predicate1, predicate2])
        
        print("DEBUG: Querying for foods in category: '\(categoryString)'")
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            if results.isEmpty {
                print("DEBUG: No results found for category '\(categoryString)'")
                return []
            } else {
                // Get all non-empty Chinese names
                var names = results.compactMap { $0.value(forKey: "chineseName") as? String }
                
                // Get all non-empty English names
                let englishNames = results.compactMap { $0.value(forKey: "englishName") as? String }
                
                // Merge Chinese and English names (ensure no duplicates)
                names.append(contentsOf: englishNames)
                let uniqueNames = Array(Set(names))
                
                print("DEBUG: Found \(uniqueNames.count) foods in category \(categoryString) (combined Chinese and English)")
                return uniqueNames
            }
        } catch {
            print("Error fetching food names for category \(categoryString): \(error.localizedDescription)")
            return []
        }
    }
    
    // Search for food names matching the search text
    func searchFoodNames(matching searchText: String) -> [String] {
        guard !searchText.isEmpty else { return [] }
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        fetchRequest.predicate = NSPredicate(format: "chineseName CONTAINS[cd] %@ OR englishName CONTAINS[cd] %@", 
                                            searchText, searchText)
        
        print("DEBUG: Searching for foods matching: \(searchText)")
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            // Get all non-empty Chinese names
            var names = results.compactMap { $0.value(forKey: "chineseName") as? String }
            
            // Get all non-empty English names
            let englishNames = results.compactMap { 
                let engName = $0.value(forKey: "englishName") as? String
                // Only return English names containing the search text
                return engName?.localizedCaseInsensitiveContains(searchText) == true ? engName : nil
            }
            
            // Merge Chinese and English names (ensure no duplicates)
            names.append(contentsOf: englishNames)
            let uniqueNames = Array(Set(names))
            
            print("DEBUG: Found \(uniqueNames.count) matching foods (combined Chinese and English)")
            return uniqueNames
        } catch {
            print("Error searching food names: \(error.localizedDescription)")
            return []
        }
    }
    
    // Add a new common food item
    func addCommonFood(chineseName: String, englishName: String, category: String) {
        let context = container.viewContext
        if let entity = NSEntityDescription.entity(forEntityName: "CommonFood", in: context) {
            let food = NSManagedObject(entity: entity, insertInto: context)
            food.setValue(chineseName, forKey: "chineseName")
            food.setValue(englishName, forKey: "englishName")
            food.setValue(category, forKey: "category")
            
            saveContext()
        }
    }
    
    // Delete a common food item by name
    func deleteCommonFood(withName name: String) {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        fetchRequest.predicate = NSPredicate(format: "chineseName == %@", name)
        
        do {
            if let result = try context.fetch(fetchRequest).first as? NSManagedObject {
                context.delete(result)
                saveContext()
            }
        } catch {
            print("Error deleting food: \(error.localizedDescription)")
        }
    }
    
    // Populate with initial data if needed
    func populateInitialDataIfNeeded() {
        let count = allFoodNames.count
        print("DEBUG: Checking database - current food count: \(count)")
        
        if count == 0 {
            print("DEBUG: Database empty, populating with initial data...")
            
            // Vegetables
            addCommonFood(chineseName: "西兰花", englishName: "Broccoli", category: "vegetable")
            addCommonFood(chineseName: "胡萝卜", englishName: "Carrot", category: "vegetable")
            addCommonFood(chineseName: "青椒", englishName: "Green Pepper", category: "vegetable")
            addCommonFood(chineseName: "西红柿", englishName: "Tomato", category: "vegetable")
            addCommonFood(chineseName: "黄瓜", englishName: "Cucumber", category: "vegetable")
            
            // Fruits
            addCommonFood(chineseName: "苹果", englishName: "Apple", category: "fruit")
            addCommonFood(chineseName: "香蕉", englishName: "Banana", category: "fruit")
            addCommonFood(chineseName: "草莓", englishName: "Strawberry", category: "fruit")
            addCommonFood(chineseName: "葡萄", englishName: "Grape", category: "fruit")
            addCommonFood(chineseName: "橙子", englishName: "Orange", category: "fruit")
            
            // Meats
            addCommonFood(chineseName: "鸡胸肉", englishName: "Chicken Breast", category: "meat")
            addCommonFood(chineseName: "牛肉", englishName: "Beef", category: "meat")
            addCommonFood(chineseName: "猪肉", englishName: "Pork", category: "meat")
            addCommonFood(chineseName: "羊肉", englishName: "Lamb", category: "meat")
            
            // Dairy
            addCommonFood(chineseName: "牛奶", englishName: "Milk", category: "dairy")
            addCommonFood(chineseName: "酸奶", englishName: "Yogurt", category: "dairy")
            addCommonFood(chineseName: "奶酪", englishName: "Cheese", category: "dairy")
            addCommonFood(chineseName: "黄油", englishName: "Butter", category: "dairy")
            
            // Seafood
            addCommonFood(chineseName: "三文鱼", englishName: "Salmon", category: "seafood")
            addCommonFood(chineseName: "虾", englishName: "Shrimp", category: "seafood")
            addCommonFood(chineseName: "鱿鱼", englishName: "Squid", category: "seafood")
            addCommonFood(chineseName: "螃蟹", englishName: "Crab", category: "seafood")
            
            print("DEBUG: Database population completed. New food count: \(allFoodNames.count)")
        }
    }
    
    // Get category for a food by name
    func getCategoryForFood(_ foodName: String) -> String? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        fetchRequest.predicate = NSPredicate(format: "chineseName == %@", foodName)
        
        print("DEBUG: Looking up category for food: '\(foodName)'")
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            if let result = results.first {
                let category = result.value(forKey: "category") as? String
                print("DEBUG: Found category '\(category ?? "nil")' for food '\(foodName)'")
                return category
            }
            
            print("DEBUG: No category found for food '\(foodName)'")
            return nil
        } catch {
            print("Error finding category for food \(foodName): \(error.localizedDescription)")
            return nil
        }
    }
    
    // Dump current database content for debugging
    func dumpDatabaseContent() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            print("DEBUG: ====== DATABASE CONTENT DUMP ======")
            print("DEBUG: Total entries: \(results.count)")
            
            for (index, obj) in results.enumerated() {
                let chineseName = obj.value(forKey: "chineseName") as? String ?? "nil"
                let englishName = obj.value(forKey: "englishName") as? String ?? "nil"
                let category = obj.value(forKey: "category") as? String ?? "nil"
                
                print("DEBUG: Entry \(index): chineseName='\(chineseName)', englishName='\(englishName)', category='\(category)'")
            }
            
            print("DEBUG: ====== END OF DATABASE DUMP ======")
        } catch {
            print("Error dumping database: \(error.localizedDescription)")
        }
    }
    
    // 获取食物的中英文名称（用于显示）
    func getFoodDisplayName(chineseName: String) -> String {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        fetchRequest.predicate = NSPredicate(format: "chineseName == %@", chineseName)
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            if let result = results.first, let englishName = result.value(forKey: "englishName") as? String {
                return "\(chineseName) (\(englishName))"
            }
            
            return chineseName
        } catch {
            return chineseName
        }
    }
    
    // 获取英文名称基于中文名称
    func getEnglishName(for chineseName: String) -> String? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        fetchRequest.predicate = NSPredicate(format: "chineseName == %@", chineseName)
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            if let result = results.first {
                return result.value(forKey: "englishName") as? String
            }
            
            return nil
        } catch {
            print("Error fetching English name for \(chineseName): \(error.localizedDescription)")
            return nil
        }
    }
    
    // 根据英文名称获取中文名称
    func getChineseNameByEnglishName(_ englishName: String) -> String? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        fetchRequest.predicate = NSPredicate(format: "englishName CONTAINS[cd] %@", englishName)
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            if let result = results.first {
                return result.value(forKey: "chineseName") as? String
            }
            
            return nil
        } catch {
            print("Error fetching Chinese name for \(englishName): \(error.localizedDescription)")
            return nil
        }
    }
    
    // 获取所有英文食物名称
    var allEnglishFoodNames: [String] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        
        print("DEBUG: Fetching all English food names from database")
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            // 只获取非空的英文名称
            let englishNames = results.compactMap { $0.value(forKey: "englishName") as? String }
                .filter { !$0.isEmpty }
            
            print("DEBUG: Found \(englishNames.count) English food names")
            
            return englishNames
        } catch {
            print("Error fetching English food names: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Private Methods
    
    // Save the Core Data context
    private func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error.localizedDescription)")
            }
        }
    }
} 