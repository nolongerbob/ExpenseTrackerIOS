//
// LocalStorageService.swift
// Сервис для локального хранения данных
//

import Foundation

class LocalStorageService {
    static let shared = LocalStorageService()
    
    private let fileManager = FileManager.default
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private init() {}
    
    // MARK: - Save Data
    
    func saveExpenses(_ expenses: [Expense]) {
        saveCodable(expenses, to: "expenses.json")
    }
    
    func saveCategories(_ categories: [Category]) {
        saveCodable(categories, to: "categories.json")
    }
    
    func saveProfile(_ profile: UserProfile) {
        saveCodable(profile, to: "profile.json")
    }
    
    func savePosts(_ posts: [Post]) {
        saveCodable(posts, to: "posts.json")
    }
    
    func saveFriends(_ friends: [Friend]) {
        saveCodable(friends, to: "friends.json")
    }
    
    func saveNotes(_ notes: [Note]) {
        saveCodable(notes, to: "notes.json")
    }
    
    func saveCurrentUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: "currentUserId")
    }
    
    // MARK: - Load Data
    
    func loadExpenses() -> [Expense] {
        loadCodable(from: "expenses.json") ?? []
    }
    
    func loadCategories() -> [Category] {
        loadCodable(from: "categories.json") ?? []
    }
    
    func loadProfile() -> UserProfile? {
        loadCodable(from: "profile.json")
    }
    
    func loadPosts() -> [Post] {
        loadCodable(from: "posts.json") ?? []
    }
    
    func loadFriends() -> [Friend] {
        loadCodable(from: "friends.json") ?? []
    }
    
    func loadNotes() -> [Note] {
        loadCodable(from: "notes.json") ?? []
    }
    
    func loadCurrentUserId() -> String? {
        UserDefaults.standard.string(forKey: "currentUserId")
    }
    
    // MARK: - Clear Data
    
    func clearAllData() {
        let files = ["expenses.json", "categories.json", "profile.json", "posts.json", "friends.json", "notes.json"]
        for file in files {
            let url = documentsURL.appendingPathComponent(file)
            try? fileManager.removeItem(at: url)
        }
        UserDefaults.standard.removeObject(forKey: "currentUserId")
    }
    
    // MARK: - Helper Methods
    
    private func saveCodable<T: Codable>(_ object: T, to filename: String) {
        let url = documentsURL.appendingPathComponent(filename)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(object)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Error saving \(filename): \(error)")
        }
    }
    
    private func loadCodable<T: Codable>(from filename: String) -> T? {
        let url = documentsURL.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Error loading \(filename): \(error)")
            return nil
        }
    }
}


