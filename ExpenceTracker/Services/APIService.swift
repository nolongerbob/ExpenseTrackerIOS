//
// APIService.swift
// Сервис для работы с API бэкенда
//

import Foundation

class APIService {
    static let shared = APIService()
    
    // API Server URL
    // Для локальной разработки: "http://localhost:3001"
    // Для Render: "https://expense-tracker-api-sbxx.onrender.com"
    private let baseURL = "https://expense-tracker-api-sbxx.onrender.com"
    
    func getImageURL(_ path: String) -> String {
        if path.hasPrefix("http") {
            return path
        }
        return "\(baseURL)\(path)"
    }
    
    // Вспомогательная функция для парсинга даты из ISO8601 строки
    static func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Пытаемся распарсить с миллисекундами
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Fallback: пытаемся без миллисекунд
        let simpleFormatter = ISO8601DateFormatter()
        simpleFormatter.formatOptions = [.withInternetDateTime]
        if let date = simpleFormatter.date(from: dateString) {
            return date
        }
        
        // Fallback: обычный DateFormatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return dateFormatter.date(from: dateString)
    }
    
    private var authToken: String? {
        get {
            UserDefaults.standard.string(forKey: "auth_token")
        }
        set {
            if let token = newValue {
                UserDefaults.standard.set(token, forKey: "auth_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "auth_token")
            }
        }
    }
    
    private init() {}
    
    // MARK: - Helper Methods
    
    private func cleanBodyForJSON(_ body: [String: Any]) -> [String: Any] {
        var cleaned: [String: Any] = [:]
        for (key, value) in body {
            if value is NSNull {
                // Для NSNull передаем null в JSON через специальный маркер
                // JSONSerialization не поддерживает null напрямую, поэтому используем строку "null"
                // и обрабатываем на сервере
                cleaned[key] = NSNull()
            } else if let dict = value as? [String: Any] {
                cleaned[key] = cleanBodyForJSON(dict)
            } else {
                cleaned[key] = value
            }
        }
        return cleaned
    }
    
    // MARK: - Auth
    
    func login(email: String, password: String) async throws -> (token: String, user: UserProfileResponse) {
        let response: AuthResponse = try await request(
            endpoint: "/api/auth/login",
            method: "POST",
            body: ["email": email, "password": password]
        )
        
        authToken = response.token
        return (response.token, response.user)
    }
    
    func register(email: String, password: String, name: String?) async throws -> (token: String, user: UserProfileResponse) {
        var body: [String: Any] = ["email": email, "password": password]
        if let name = name {
            body["name"] = name
        }
        
        let response: AuthResponse = try await request(
            endpoint: "/api/auth/register",
            method: "POST",
            body: body
        )
        
        authToken = response.token
        return (response.token, response.user)
    }
    
    func logout() {
        authToken = nil
    }
    
    var isAuthenticated: Bool {
        authToken != nil
    }
    
    // MARK: - Profile
    
    func getProfile() async throws -> UserProfileResponse {
        try await request(endpoint: "/api/profile", method: "GET")
    }
    
    func updateProfile(name: String?, image: String?) async throws -> UserProfileResponse {
        var body: [String: Any] = [:]
        if let name = name {
            body["name"] = name
        }
        if let image = image {
            body["image"] = image
        }
        let response: UpdateProfileResponse = try await request(endpoint: "/api/profile", method: "PUT", body: body)
        return response.user
    }
    
    // MARK: - Expenses
    
    func getExpenses() async throws -> [ExpenseResponse] {
        try await request(endpoint: "/api/expenses", method: "GET")
    }
    
    func createExpense(amount: Double, categoryId: String?, note: String?, type: String = "EXPENSE", spentAt: Date? = nil) async throws -> ExpenseResponse {
        var body: [String: Any] = ["amount": amount, "currency": "RUB", "type": type]
        if let categoryId = categoryId {
            body["categoryId"] = categoryId
        }
        if let note = note {
            body["note"] = note
        }
        if let spentAt = spentAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["spentAt"] = formatter.string(from: spentAt)
        }
        
        return try await request(endpoint: "/api/expenses", method: "POST", body: body)
    }
    
    func updateExpense(id: String, amount: Double?, categoryId: String?, note: String?, type: String?, spentAt: Date?) async throws -> ExpenseResponse {
        var body: [String: Any] = [:]
        if let amount = amount {
            body["amount"] = amount
        }
        if let categoryId = categoryId {
            body["categoryId"] = categoryId
        }
        if let note = note {
            body["note"] = note
        }
        if let type = type {
            body["type"] = type
        }
        if let spentAt = spentAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["spentAt"] = formatter.string(from: spentAt)
        }
        
        return try await request(endpoint: "/api/expenses/\(id)", method: "PUT", body: body)
    }
    
    func deleteExpense(id: String) async throws {
        let _: EmptyResponse = try await request(endpoint: "/api/expenses/\(id)", method: "DELETE")
    }
    
    // MARK: - Categories
    
    func getCategories() async throws -> [CategoryResponse] {
        try await request(endpoint: "/api/categories", method: "GET")
    }
    
    func createCategory(name: String, color: String, type: String = "EXPENSE") async throws -> CategoryResponse {
        try await request(
            endpoint: "/api/categories",
            method: "POST",
            body: ["name": name, "color": color, "type": type]
        )
    }
    
    func deleteCategory(id: String) async throws {
        print("APIService: Deleting category with ID: \(id)")
        // Экранируем ID для URL
        guard let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL
        }
        let endpoint = "/api/categories/\(encodedId)"
        print("APIService: Endpoint: \(endpoint)")
        let _: EmptyResponse = try await request(endpoint: endpoint, method: "DELETE")
    }
    
    // MARK: - Leaderboard
    
    func getLeaderboard() async throws -> [LeaderboardResponse] {
        try await request(endpoint: "/api/leaderboard", method: "GET")
    }
    
    // MARK: - Posts
    
    func getPosts() async throws -> PostsResponse {
        try await request(endpoint: "/api/posts", method: "GET")
    }
    
    func createPost(content: String, imageUrl: String?) async throws -> PostResponse {
        var body: [String: Any] = ["content": content]
        if let imageUrl = imageUrl {
            body["imageUrl"] = imageUrl
        }
        
        let response: PostResponseWrapper = try await request(
            endpoint: "/api/posts",
            method: "POST",
            body: body
        )
        return response.post
    }
    
    func toggleLike(postId: String) async throws -> LikeResponse {
        try await request(endpoint: "/api/posts/\(postId)/like", method: "POST")
    }
    
    func addComment(postId: String, content: String) async throws -> CommentResponseWrapper {
        try await request(
            endpoint: "/api/posts/\(postId)/comments",
            method: "POST",
            body: ["content": content]
        )
    }
    
    func deleteComment(postId: String, commentId: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/api/posts/\(postId)/comments/\(commentId)",
            method: "DELETE"
        )
    }
    
    func deletePost(postId: String) async throws {
        let _: EmptyResponse = try await request(endpoint: "/api/posts/\(postId)", method: "DELETE")
    }
    
    func updatePost(postId: String, content: String) async throws -> PostResponse {
        try await request(
            endpoint: "/api/posts/\(postId)",
            method: "PUT",
            body: ["content": content]
        )
    }
    
    // MARK: - Friends
    
    func getFriends() async throws -> [FriendResponse] {
        try await request(endpoint: "/api/friends", method: "GET")
    }
    
    func addFriend(email: String) async throws -> FriendRequestResponse {
        try await request(
            endpoint: "/api/friends",
            method: "POST",
            body: ["email": email]
        )
    }
    
    func getFriendRequests() async throws -> FriendRequestsResponse {
        try await request(endpoint: "/api/friends/requests", method: "GET")
    }
    
    func respondToFriendRequest(requestId: String, action: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/api/friends/respond",
            method: "POST",
            body: ["requestId": requestId, "action": action]
        )
    }
    
    // MARK: - Notes
    
    func getNotes() async throws -> [NoteResponse] {
        try await request(endpoint: "/api/notes", method: "GET")
    }
    
    func createNote(title: String, content: String?, noteDate: Date?, reminderDate: Date?) async throws -> NoteResponse {
        var body: [String: Any] = ["title": title]
        if let content = content {
            body["content"] = content
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone.current
        if let noteDate = noteDate {
            let noteDateString = formatter.string(from: noteDate)
            body["noteDate"] = noteDateString
            print("APIService: Creating note with noteDate: \(noteDateString) (original: \(noteDate))")
        } else {
            // Если noteDate не указан, не передаем его (будет использоваться значение по умолчанию на сервере)
            print("APIService: Creating note without noteDate (will use default)")
        }
        if let reminderDate = reminderDate {
            let reminderDateString = formatter.string(from: reminderDate)
            body["reminderDate"] = reminderDateString
            print("APIService: Creating note with reminderDate: \(reminderDateString)")
        } else {
            print("APIService: Creating note without reminderDate")
        }
        return try await request(endpoint: "/api/notes", method: "POST", body: body)
    }
    
    func updateNote(id: String, title: String?, content: String?, noteDate: Date?, reminderDate: Date??) async throws -> NoteResponse {
        var body: [String: Any] = [:]
        if let title = title {
            body["title"] = title
        }
        if let content = content {
            body["content"] = content
        }
        if let noteDate = noteDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["noteDate"] = formatter.string(from: noteDate)
        }
        // Передаем reminderDate даже если он nil, чтобы можно было удалить напоминание
        if let reminderDateWrapper = reminderDate {
            if let date = reminderDateWrapper {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                body["reminderDate"] = formatter.string(from: date)
                print("APIService: Updating note with reminderDate: \(formatter.string(from: date))")
            } else {
                // Для удаления напоминания передаем null
                body["reminderDate"] = NSNull()
                print("APIService: Updating note to remove reminderDate")
            }
        }
        return try await request(endpoint: "/api/notes/\(id)", method: "PUT", body: body)
    }
    
    func deleteNote(id: String) async throws {
        let _: EmptyResponse = try await request(endpoint: "/api/notes/\(id)", method: "DELETE")
    }
    
    // MARK: - Upload
    
    func uploadImage(imageData: Data) async throws -> UploadResponse {
        let boundary = UUID().uuidString
        guard let url = URL(string: "\(baseURL)/api/upload") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Добавляем заголовок для ngrok только если используется ngrok
        if baseURL.contains("ngrok-free.dev") {
            request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? ""
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("=== Upload Error ===")
            print("Status: \(httpResponse.statusCode)")
            print("Response: \(responseString.prefix(500))")
            print("===================")
            if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.error)
            }
            throw APIError.serverError("Upload failed with status \(httpResponse.statusCode)")
        }
        
        do {
            return try JSONDecoder().decode(UploadResponse.self, from: data)
        } catch {
            print("=== Upload Decoding Error ===")
            print("Error: \(error)")
            print("Response: \(responseString)")
            print("============================")
            throw APIError.decodingError("Failed to decode upload response: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Request Helper
    
    private func request<T: Decodable>(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Добавляем заголовок для ngrok только если используется ngrok
        if baseURL.contains("ngrok-free.dev") {
            request.setValue("true", forHTTPHeaderField: "ngrok-skip-browser-warning")
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ExpenseTracker/1.0", forHTTPHeaderField: "User-Agent")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            // Обрабатываем NSNull для правильной сериализации nil значений
            let cleanedBody = cleanBodyForJSON(body)
            request.httpBody = try JSONSerialization.data(withJSONObject: cleanedBody)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? ""
        
        // Проверяем, не вернул ли ngrok HTML страницу (предупреждение) - только если используется ngrok
        if baseURL.contains("ngrok-free.dev") {
            let isHTML = responseString.contains("<!DOCTYPE html") || responseString.contains("<html")
            let isJSON = responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") || responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[")
            
            // Если это HTML (независимо от статуса), это страница предупреждения ngrok
            if isHTML && !isJSON {
                print("=== ngrok Warning Page Detected ===")
                print("URL: \(url.absoluteString)")
                print("Status Code: \(httpResponse.statusCode)")
                print("Response preview: \(responseString.prefix(500))")
                print("===================================")
                throw APIError.serverError("ngrok показал страницу предупреждения. Откройте URL в браузере один раз для подтверждения, затем попробуйте снова.")
            }
        }
        
        if httpResponse.statusCode == 401 {
            authToken = nil
            throw APIError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("=== API Error ===")
            print("Status: \(httpResponse.statusCode)")
            print("Method: \(method)")
            print("URL: \(url.absoluteString)")
            print("Response: \(responseString.prefix(500))")
            print("=================")
            if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorData.error)
            }
            // Для 404 ошибок пытаемся понять причину
            if httpResponse.statusCode == 404 {
                throw APIError.serverError("Эндпоинт не найден (404). Проверьте URL и убедитесь, что сервер запущен.")
            }
            throw APIError.serverError("Server error: \(httpResponse.statusCode)")
        }
        
        // Для 204 No Content или пустого ответа возвращаем пустой EmptyResponse
        if httpResponse.statusCode == 204 || data.isEmpty {
            // Если ожидается EmptyResponse, возвращаем его
            if T.self == EmptyResponse.self {
                return EmptyResponse(success: true) as! T
            }
            // Если данных нет, но ожидается другой тип - это ошибка
            if data.isEmpty {
                throw APIError.decodingError("Empty response body for non-EmptyResponse type")
            }
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Если декодирование не удалось, но это EmptyResponse и данные пустые - возвращаем пустой ответ
            if T.self == EmptyResponse.self && data.isEmpty {
                return EmptyResponse(success: true) as! T
            }
            print("Decoding error: \(error)")
            print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .unauthorized:
            return "Unauthorized"
        case .serverError(let message):
            return message
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let token: String
    let user: UserProfileResponse
}

struct UserProfileResponse: Codable {
    let id: String
    let email: String
    let name: String?
    let image: String?
}

struct ErrorResponse: Codable {
    let error: String
}

struct ExpenseResponse: Codable {
    let id: String
    let amount: String
    let currency: String
    let note: String?
    let spentAt: String
    let category: CategoryResponse?
    let categoryId: String?
    let type: String?
}

struct CategoryResponse: Codable {
    let id: String
    let name: String
    let color: String
    let type: String?
}

struct LeaderboardResponse: Codable {
    let userId: String
    let name: String
    let total: String
    let image: String?
}

struct PostsResponse: Codable {
    let posts: [PostResponse]
}

struct PostResponse: Codable {
    let id: String
    let content: String
    let imageUrl: String?
    let createdAt: String
    let author: AuthorResponse
    let likes: [LikeResponse]
    let comments: [CommentResponse]
    let _count: PostCountResponse?
}

struct PostResponseWrapper: Codable {
    let post: PostResponse
}

struct AuthorResponse: Codable {
    let id: String
    let name: String?
    let image: String?
}

struct LikeResponse: Codable {
    let userId: String?
    let postId: String?
    let liked: Bool?
}

struct CommentResponse: Codable {
    let id: String
    let content: String
    let createdAt: String
    let author: AuthorResponse
}

struct CommentResponseWrapper: Codable {
    let comment: CommentResponse
}

struct PostCountResponse: Codable {
    let likes: Int
    let comments: Int
}

struct FriendResponse: Codable {
    let id: String
    let name: String?
    let email: String
    let image: String?
}

struct FriendRequestResponse: Codable {
    let id: String
    let addressee: FriendResponse
}

struct FriendRequestsResponse: Codable {
    let incoming: [FriendRequestItem]
    let outgoing: [FriendRequestItem]
}

struct FriendRequestItem: Codable {
    let id: String
    let user: FriendResponse
    let createdAt: String
}

struct UploadResponse: Codable {
    let url: String
    let filename: String?
    let public_id: String?
    let format: String?
    let width: Int?
    let height: Int?
    let size: Int?
    let mimetype: String?
}

struct EmptyResponse: Codable {
    let success: Bool?
}

struct UpdateProfileResponse: Codable {
    let message: String?
    let user: UserProfileResponse
}

struct NoteResponse: Codable {
    let id: String
    let title: String
    let content: String?
    let noteDate: String
    let reminderDate: String?
    let createdAt: String
    let updatedAt: String
}

