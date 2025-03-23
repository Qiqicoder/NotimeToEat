import Foundation

extension Services {
    class AIService {
        private let apiKey: String
        private let baseURL: String
        
        init(apiKey: String, baseURL: String = "https://api.deepseek.com") {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
        
        func generateCompletion(prompt: String) async throws -> String {
            guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let payload: [String: Any] = [
                "model": "deepseek-chat",
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            
            guard let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = jsonResponse["choices"] as? [[String: Any]],
                let firstChoice = choices.first,
                let message = firstChoice["message"] as? [String: Any],
                let content = message["content"] as? String else {
                throw NSError(domain: "AIServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
            }
            
            return content
        }
        
        // 添加新方法用于分析小票文本
        func analyzeReceiptText(_ text: String, completion: @escaping (String?) -> Void) {
            Task {
                do {
                    let receiptPrompt = """
                    这里是购物小票OCR的识别结果：
                    
                    \(text)
                    
                    请严格按照以下格式分析并返回结果:
                    食品名称|种类|保质期天数
                    
                    请注意:
                    1. 请适当结合你的推断补全小票的缩写产品名称
                    2. 种类请分配为以下之一: 肉类, 蔬菜, 水果, 海鲜, 乳制品, 零食, 饮料, 调味品, 主食, 其他
                    3. 保质期天数请根据常识预估, 例如肉类约7天, 新鲜蔬果约7-14天, 乳制品约10-20天, 零食约180天等
                    4. 每行一个食品, 用竖线'|'分隔字段
                    
                    返回示例:
                    香蕉|水果|7
                    牛奶|乳制品|14
                    面包|主食|5
                    """
                    
                    let result = try await generateCompletion(prompt: receiptPrompt)
                    DispatchQueue.main.async {
                        completion(result)
                    }
                } catch {
                    print("AI分析错误: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
        
        // 添加新方法用于推荐处理即将过期食材的菜品
        func recommendDishesForFood(expiringFood: String, allFoods: [String], completion: @escaping ([(formula: String, dish: String)]?) -> Void) {
            Task {
                do {
                    let promptTemplate = """
                    我想处理即将过期的食材：\(expiringFood)。
                    我冰箱里还有这些食材：\(allFoods.joined(separator: ", "))
                    
                    请根据我冰箱里有的食材，推荐1-3道可以处理掉\(expiringFood)的菜品。
                    注意：
                    1. 禁止使用冰箱中没有的食材
                    2. 如果没有足够合适的搭配，只推荐1-2道菜即可
                    3. 必须以公式形式给出食材组合，然后是菜品名称
                    
                    例如：
                    土豆 + 大蒜 + 牛排 = 蒜香牛排炒土豆
                    西红柿 + 鸡蛋 = 西红柿炒鸡蛋
                    
                    请直接返回公式和菜名，每行一个，不要包含任何其他文字。
                    """
                    
                    let result = try await generateCompletion(prompt: promptTemplate)
                    // 解析结果，按行分割并过滤空行
                    let lines = result.split(separator: "\n")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .prefix(3) // 确保最多只返回3道菜
                    
                    // 将每行解析为"公式"和"菜名"
                    var dishes: [(formula: String, dish: String)] = []
                    
                    for line in lines {
                        if let equalsIndex = line.firstIndex(of: "=") {
                            let formula = line[..<equalsIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                            let dish = line[line.index(after: equalsIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
                            dishes.append((formula: formula, dish: dish))
                        } else {
                            // 如果格式不匹配，尝试将整行作为菜名
                            dishes.append((formula: expiringFood, dish: line))
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(dishes)
                    }
                } catch {
                    print("AI菜品推荐错误: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
} 