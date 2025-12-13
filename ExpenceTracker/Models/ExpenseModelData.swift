//
// ExpenseModelData.swift
// Модель данных для приложения учета расходов
//

import Foundation
import SwiftUI

@Observable
@MainActor
class ExpenseModelData {
    var expenses: [Expense] = []
    var categories: [Category] = []
    var profile: UserProfile?
    var posts: [Post] = []
    var friends: [Friend] = []
    var leaderboard: [LeaderboardEntry] = []
    var notes: [Note] = []
    var currentUserId: String?
    
    init() {
        // Не загружаем тестовые данные при инициализации
        // Данные будут загружены из API после авторизации
    }
    
    func clearAllData() {
        expenses = []
        categories = []
        profile = nil
        posts = []
        friends = []
        leaderboard = []
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

struct Expense: Identifiable, Hashable {
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

struct Category: Identifiable, Hashable {
    let id: String
    var name: String
    var color: Color
    var icon: String
    var type: Expense.ExpenseType
}

struct UserProfile: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var email: String
    var avatar: String?
}

struct Post: Identifiable {
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

struct Like: Identifiable {
    let id: UUID
    let userId: UUID
}

struct Comment: Identifiable {
    let id: UUID
    var content: String
    var author: UserProfile
    var createdAt: Date = Date()
}

struct Friend: Identifiable {
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

struct Note: Identifiable, Hashable {
    let id: String
    var title: String
    var content: String?
    var noteDate: Date
    var reminderDate: Date?
    var createdAt: Date
    var updatedAt: Date
}

