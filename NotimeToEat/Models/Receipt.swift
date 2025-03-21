import Foundation
import SwiftUI

struct Receipt_Struct: Identifiable, Codable {
    var id: UUID
    var imageID: String
    var foodItemID: UUID
    var addedDate: Date
    
    init(id: UUID = UUID(), imageID: String, foodItemID: UUID, addedDate: Date = Date()) {
        self.id = id
        self.imageID = imageID
        self.foodItemID = foodItemID
        self.addedDate = addedDate
    }
} 