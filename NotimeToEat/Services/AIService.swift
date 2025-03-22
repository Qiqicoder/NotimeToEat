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
                    ["role": "user", "content": "这里是购物小票OCR的识别结果：\n" + prompt + "\n\n请严格按照以下形式返回你的结果\n\nfood\n\n 请注意，请适当结合你的推断补全小票的缩写产品名称\n\n返回例子：\nbanana\napple"]
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
                    let result = try await generateCompletion(prompt: text)
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
    }
} 