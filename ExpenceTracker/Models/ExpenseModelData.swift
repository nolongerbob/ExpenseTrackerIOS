//
// ExpenseModelData.swift
// Модель данных для приложения учета расходов
//

import Foundation
import SwiftUI

@Observable
@MainActor
class ExpenseModelData {
    var expenses: [Expense] = [] {
        didSet {
            // Сохраняем в фоне, чтобы не блокировать UI
            let expensesToSave = expenses
            Task(priority: .utility) {
                LocalStorageService.shared.saveExpenses(expensesToSave)
            }
        }
    }
    var categories: [Category] = [] {
        didSet {
            let categoriesToSave = categories
            Task(priority: .utility) {
                LocalStorageService.shared.saveCategories(categoriesToSave)
            }
        }
    }
    var profile: UserProfile? {
        didSet {
            if let profile = profile {
                let profileToSave = profile
                Task(priority: .utility) {
                    LocalStorageService.shared.saveProfile(profileToSave)
                }
            }
        }
    }
    var posts: [Post] = [] {
        didSet {
            let postsToSave = posts
            Task(priority: .utility) {
                LocalStorageService.shared.savePosts(postsToSave)
            }
        }
    }
    var friends: [Friend] = [] {
        didSet {
            let friendsToSave = friends
            Task(priority: .utility) {
                LocalStorageService.shared.saveFriends(friendsToSave)
            }
        }
    }
    var leaderboard: [LeaderboardEntry] = []
    var notes: [Note] = [] {
        didSet {
            let notesToSave = notes
            Task(priority: .utility) {
                LocalStorageService.shared.saveNotes(notesToSave)
            }
        }
    }
    var currentUserId: String? {
        didSet {
            if let userId = currentUserId {
                let userIdToSave = userId
                Task(priority: .utility) {
                    LocalStorageService.shared.saveCurrentUserId(userIdToSave)
                }
            }
        }
    }
    
    init() {
        // Загружаем локальные данные сразу
        loadLocalData()
    }
    
    func loadLocalData() {
        expenses = LocalStorageService.shared.loadExpenses()
        categories = LocalStorageService.shared.loadCategories()
        profile = LocalStorageService.shared.loadProfile()
        posts = LocalStorageService.shared.loadPosts()
        friends = LocalStorageService.shared.loadFriends()
        notes = LocalStorageService.shared.loadNotes()
        currentUserId = LocalStorageService.shared.loadCurrentUserId()
    }
    
    func clearAllData() {
        expenses = []
        categories = []
        profile = nil
        posts = []
        friends = []
        leaderboard = []
        notes = []
        currentUserId = nil
        LocalStorageService.shared.clearAllData()
    }
    
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
    }
    
    func removeExpense(_ id: UUID) {
        expenses.removeAll { $0.id == id }
    }
    
    func addCategory(_ category: Category) {
        categories.append(category)
    }
    
    func addPost(_ post: Post) {
        posts.insert(post, at: 0)
    }
    
    func toggleLike(postId: UUID, userId: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        if let likeIndex = posts[index].likes.firstIndex(where: { $0.userId == userId }) {
            posts[index].likes.remove(at: likeIndex)
        } else {
            posts[index].likes.append(Like(id: UUID(), userId: userId))
        }
    }
    
    func addComment(postId: UUID, comment: Comment) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[index].comments.append(comment)
    }
    
    func removeComment(postId: UUID, commentId: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        posts[index].comments.removeAll { $0.id == commentId }
    }
    
    func updatePost(postId: UUID, likes: [Like]? = nil, comments: [Comment]? = nil) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        if let likes = likes {
            posts[index].likes = likes
        }
        if let comments = comments {
            posts[index].comments = comments
        }
    }
    
    func removePost(postId: UUID) {
        posts.removeAll { $0.id == postId }
    }
    
    func addFriend(_ friend: Friend) {
        friends.append(friend)
    }
    
    func removeFriend(_ id: UUID) {
        friends.removeAll { $0.id == id }
    }
}

struct Expense: Identifiable, Hashable, Codable {
    let id: UUID
    let apiId: String // Оригинальный ID из API (cuid)
    var amount: Double
    var category: Category
    var note: String?
    var date: Date
    var type: ExpenseType = .expense
    
    enum ExpenseType: String, Codable {
        case expense = "expense"
        case income = "income"
        
        static func fromAPI(_ apiType: String?) -> ExpenseType {
            guard let apiType = apiType else { return .expense }
            return apiType == "INCOME" ? .income : .expense
        }
    }
}

struct Category: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var colorHex: String // Сохраняем как hex строку для Codable
    var icon: String
    var type: Expense.ExpenseType
    
    var color: Color {
        get { Color(hex: colorHex) ?? .blue }
        set { colorHex = colorToHex(newValue) }
    }
    
    init(id: String, name: String, color: Color, icon: String, type: Expense.ExpenseType) {
        self.id = id
        self.name = name
        self.colorHex = Category.colorToHex(color)
        self.icon = icon
        self.type = type
    }
    
    private static func colorToHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let rgb: Int = (Int)(red*255)<<16 | (Int)(green*255)<<8 | (Int)(blue*255)<<0
        return String(format: "#%06x", rgb)
    }
    
    private func colorToHex(_ color: Color) -> String {
        Category.colorToHex(color)
    }
}

struct UserProfile: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var email: String
    var avatar: String?
    
    init(name: String, email: String, avatar: String? = nil) {
        self.id = UUID()
        self.name = name
        self.email = email
        self.avatar = avatar
    }
}

struct Post: Identifiable, Codable {
    let id: UUID
    let apiId: String // Оригинальный ID из API (cuid)
    var content: String
    var author: UserProfile
    var authorId: String // ID автора для проверки владельца
    var createdAt: Date
    var imageUrl: String?
    var likes: [Like]
    var comments: [Comment]
}

struct Like: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: UUID
}

struct Comment: Identifiable, Codable {
    let id: UUID
    let apiId: String // Оригинальный ID из API (cuid) для удаления
    var content: String
    var author: UserProfile
    var authorId: String // ID автора для проверки владельца
    var createdAt: Date = Date()
}

struct Friend: Identifiable, Codable {
    let id: UUID
    var name: String
    var email: String
}

struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let userId: UUID
    var name: String
    var total: Double
}

struct Note: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var content: String?
    var noteDate: Date
    var reminderDate: Date?
    var createdAt: Date
    var updatedAt: Date
}

