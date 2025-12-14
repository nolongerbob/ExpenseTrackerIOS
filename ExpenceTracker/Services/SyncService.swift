//
// SyncService.swift
// Сервис для синхронизации данных с сервером в фоне
//

import Foundation
import SwiftUI

@MainActor
class SyncService {
    private var isSyncing = false
    private var lastSyncTime: Date?
    private let syncInterval: TimeInterval = 30 // Синхронизация каждые 30 секунд
    private weak var modelData: ExpenseModelData?
    
    init(modelData: ExpenseModelData) {
        self.modelData = modelData
    }
    
    static func create(with modelData: ExpenseModelData) -> SyncService {
        SyncService(modelData: modelData)
    }
    
    // MARK: - Public Methods
    
    func startPeriodicSync() {
        // НЕ синхронизируем сразу при старте - даем приложению загрузиться
        // Синхронизируем только периодически
        Task {
            // Ждем 5 секунд перед первой синхронизацией
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await syncAll()
            
            // Затем синхронизируем периодически
            while true {
                try? await Task.sleep(nanoseconds: UInt64(syncInterval * 1_000_000_000))
                await syncAll()
            }
        }
    }
    
    func syncAll() async {
        guard !isSyncing else { return }
        guard APIService.shared.isAuthenticated else { return }
        guard let modelData = modelData else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        print("🔄 Starting background sync...")
        
        // Синхронизируем все данные параллельно
        await syncExpenses(modelData: modelData)
        await syncCategories(modelData: modelData)
        await syncPosts(modelData: modelData)
        await syncNotes(modelData: modelData)
        await syncFriends(modelData: modelData)
        
        lastSyncTime = Date()
        print("✅ Background sync completed at \(lastSyncTime?.description ?? "unknown")")
    }
    
    // MARK: - Sync Individual Data Types
    
    private func syncExpenses(modelData: ExpenseModelData) async {
        do {
            let expensesData = try await APIService.shared.getExpenses()
            await MainActor.run {
                // Обновляем расходы
                let storage = CategoryIconStorage.shared
                let newExpenses = expensesData.map { expense in
                    Expense(
                        id: UUID(uuidString: expense.id) ?? UUID(),
                        apiId: expense.id,
                        amount: Double(expense.amount) ?? 0,
                        category: expense.category.map { cat in
                            let icon = storage.loadIcon(categoryId: cat.id) ?? "tag.fill"
                            return Category(
                                id: cat.id,
                                name: cat.name,
                                color: Color(hex: cat.color) ?? .blue,
                                icon: icon,
                                type: Expense.ExpenseType.fromAPI(cat.type)
                            )
                        } ?? Category(id: "none", name: "Без категории", color: .gray, icon: "tag.fill", type: Expense.ExpenseType.fromAPI(expense.type)),
                        note: expense.note,
                        date: APIService.parseDate(expense.spentAt) ?? Date(),
                        type: Expense.ExpenseType.fromAPI(expense.type)
                    )
                }
                // Обновляем только если данные изменились
                if newExpenses.count != modelData.expenses.count ||
                   !newExpenses.elementsEqual(modelData.expenses, by: { $0.apiId == $1.apiId }) {
                    modelData.expenses = newExpenses
                }
            }
        } catch {
            print("⚠️ Error syncing expenses: \(error)")
        }
    }
    
    private func syncCategories(modelData: ExpenseModelData) async {
        do {
            let categoriesData = try await APIService.shared.getCategories()
            await MainActor.run {
                let newCategories = categoriesData.map { cat in
                    Category(
                        id: cat.id,
                        name: cat.name,
                        color: Color(hex: cat.color) ?? .blue,
                        icon: "tag.fill",
                        type: Expense.ExpenseType.fromAPI(cat.type)
                    )
                }
                if newCategories.count != modelData.categories.count ||
                   !newCategories.elementsEqual(modelData.categories, by: { $0.id == $1.id }) {
                    modelData.categories = newCategories
                }
            }
        } catch {
            print("⚠️ Error syncing categories: \(error)")
        }
    }
    
    private func syncPosts(modelData: ExpenseModelData) async {
        do {
            let postsData = try await APIService.shared.getPosts()
            await MainActor.run {
                let newPosts = postsData.posts.map { post in
                    Post(
                        id: UUID(uuidString: post.id) ?? UUID(),
                        apiId: post.id,
                        content: post.content,
                        author: UserProfile(
                            name: post.author.name ?? post.author.id,
                            email: post.author.id,
                            avatar: post.author.image
                        ),
                        authorId: post.author.id,
                        createdAt: ISO8601DateFormatter().date(from: post.createdAt) ?? Date(),
                        imageUrl: post.imageUrl.map { APIService.shared.getImageURL($0) },
                        likes: post.likes.compactMap { like in
                            guard let userIdString = like.userId else { return nil }
                            return Like(id: UUID(), userId: UUID(uuidString: userIdString) ?? UUID())
                        },
                        comments: post.comments.map { comment in
                            Comment(
                                id: UUID(uuidString: comment.id) ?? UUID(),
                                apiId: comment.id,
                                content: comment.content,
                                author: UserProfile(
                                    name: comment.author.name ?? comment.author.id,
                                    email: comment.author.id,
                                    avatar: comment.author.image
                                ),
                                authorId: comment.author.id,
                                createdAt: ISO8601DateFormatter().date(from: comment.createdAt) ?? Date()
                            )
                        }
                    )
                }
                if newPosts.count != modelData.posts.count ||
                   !newPosts.elementsEqual(modelData.posts, by: { $0.apiId == $1.apiId }) {
                    modelData.posts = newPosts
                }
            }
        } catch {
            print("⚠️ Error syncing posts: \(error)")
        }
    }
    
    private func syncNotes(modelData: ExpenseModelData) async {
        do {
            let notesData = try await APIService.shared.getNotes()
            await MainActor.run {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let newNotes = notesData.map { note in
                    let noteDate = formatter.date(from: note.noteDate) ?? ISO8601DateFormatter().date(from: note.noteDate) ?? Date()
                    let reminderDate = note.reminderDate.flatMap { dateString in
                        formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
                    }
                    return Note(
                        id: note.id,
                        title: note.title,
                        content: note.content,
                        noteDate: noteDate,
                        reminderDate: reminderDate,
                        createdAt: ISO8601DateFormatter().date(from: note.createdAt) ?? Date(),
                        updatedAt: ISO8601DateFormatter().date(from: note.updatedAt) ?? Date()
                    )
                }
                if newNotes.count != modelData.notes.count ||
                   !newNotes.elementsEqual(modelData.notes, by: { $0.id == $1.id }) {
                    modelData.notes = newNotes
                }
            }
        } catch {
            print("⚠️ Error syncing notes: \(error)")
        }
    }
    
    private func syncFriends(modelData: ExpenseModelData) async {
        do {
            let friendsData = try await APIService.shared.getFriends()
            await MainActor.run {
                let newFriends = friendsData.map { friend in
                    Friend(
                        id: UUID(uuidString: friend.id) ?? UUID(),
                        name: friend.name ?? friend.email,
                        email: friend.email
                    )
                }
                if newFriends.count != modelData.friends.count ||
                   !newFriends.elementsEqual(modelData.friends, by: { $0.id == $1.id }) {
                    modelData.friends = newFriends
                }
            }
        } catch {
            print("⚠️ Error syncing friends: \(error)")
        }
    }
    
    // MARK: - Manual Sync
    
    func forceSync() async {
        await syncAll()
    }
}

