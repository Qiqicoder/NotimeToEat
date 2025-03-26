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
            
            // Sort alphabetically
            let sortedNames = uniqueNames.sorted()
            
            return sortedNames
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
                
                // Sort alphabetically
                let sortedNames = uniqueNames.sorted()
                
                print("DEBUG: Found \(sortedNames.count) foods in category \(categoryString) (combined Chinese and English, alphabetically sorted)")
                return sortedNames
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
            
            // Sort alphabetically
            let sortedNames = uniqueNames.sorted()
            
            print("DEBUG: Found \(sortedNames.count) matching foods (combined Chinese and English, alphabetically sorted)")
            return sortedNames
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
            print("DEBUG: Database empty, populating with initial data from CSV...")
            
            // Load data from CSV file
            if let csvData = loadFoodDataFromCSV() {
                for item in csvData {
                    addCommonFood(
                        chineseName: item.chineseName,
                        englishName: item.englishName,
                        category: item.category
                    )
                }
                print("DEBUG: Database population completed. New food count: \(allFoodNames.count)")
            } else {
                print("DEBUG: Failed to load food data from CSV file")
            }
        }
    }
    
    // MARK: - CSV Data Loading
    
    // Structure to represent a food item in CSV
    private struct CSVFoodItem {
        let chineseName: String
        let englishName: String
        let category: String
    }
    
    // Load food data from CSV file
    private func loadFoodDataFromCSV() -> [CSVFoodItem]? {
        guard let csvPath = Bundle.main.path(forResource: "commonFood", ofType: "csv") else {
            print("ERROR: Could not find commonFood.csv in bundle")
            return nil
        }
        
        do {
            let csvString = try String(contentsOfFile: csvPath, encoding: .utf8)
            let rows = csvString.components(separatedBy: "\n")
            
            // Skip the header row and empty rows
            var foodItems = [CSVFoodItem]()
            
            for (index, row) in rows.enumerated() {
                // Skip header row and empty rows
                if index == 0 || row.isEmpty {
                    continue
                }
                
                let columns = row.components(separatedBy: ",")
                
                // Ensure we have exactly 3 columns (chineseName, englishName, category)
                guard columns.count >= 3 else {
                    print("WARNING: Skipping invalid row in CSV: \(row)")
                    continue
                }
                
                let chineseName = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let englishName = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let category = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                
                let foodItem = CSVFoodItem(
                    chineseName: chineseName,
                    englishName: englishName,
                    category: category
                )
                
                foodItems.append(foodItem)
            }
            
            print("DEBUG: Successfully loaded \(foodItems.count) food items from CSV")
            return foodItems
            
        } catch {
            print("ERROR: Failed to load CSV file: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Get category for a food by name
    func getCategoryForFood(_ foodName: String) -> String? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CommonFood")
        fetchRequest.predicate = NSPredicate(format: "chineseName == %@", foodName)
        
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            if let result = results.first {
                let category = result.value(forKey: "category") as? String
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
            print("DEBUG: Total entries: \(results.count)")
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
        
        do {
            let results = try container.viewContext.fetch(fetchRequest) as? [NSManagedObject] ?? []
            
            // 只获取非空的英文名称
            let englishNames = results.compactMap { $0.value(forKey: "englishName") as? String }
                .filter { !$0.isEmpty }
            
            // 按字母顺序排序
            let sortedNames = englishNames.sorted()
            
            
            return sortedNames
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
