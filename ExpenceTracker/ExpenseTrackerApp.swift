//
// ExpenseTrackerApp.swift
// Нативное iOS приложение для учета расходов с Liquid Glass эффектом
// Использует современные возможности iOS включая Dynamic Island
//

import SwiftUI
import UserNotifications

@main
struct ExpenseTrackerApp: App {
    @State private var modelData = ExpenseModelData()
    @AppStorage("is_authenticated") private var isAuthenticated = false
    @AppStorage("colorScheme") private var colorScheme: String = "dark"
    @AppStorage("notificationPermissionRequested") private var notificationPermissionRequested = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    if modelData.profile != nil {
                        MainTabView()
                    } else {
                        // Показываем загрузку пока профиль не загружен
                        ZStack {
                            LinearGradient(
                                colors: [.black, Color(red: 0.1, green: 0.1, blue: 0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                            
                            ProgressView()
                                .tint(.white)
                        }
                    }
                } else {
                    LoginView()
                }
            }
            .environment(modelData)
            .preferredColorScheme(colorScheme == "dark" ? .dark : (colorScheme == "light" ? .light : nil))
            .task {
                await checkAuthentication()
            }
        }
    }
    
    func checkAuthentication() async {
        let wasAuthenticated = APIService.shared.isAuthenticated
        isAuthenticated = wasAuthenticated
        
        if wasAuthenticated {
            // Очищаем данные перед загрузкой
            await MainActor.run {
                modelData.clearAllData()
            }
            // Загружаем данные пользователя
            await loadUserData()
        } else {
            // Если не авторизован, очищаем все данные
            await MainActor.run {
                modelData.clearAllData()
            }
        }
    }
    
    func loadUserData() async {
        // Очищаем все данные перед загрузкой новых
        await MainActor.run {
            modelData.clearAllData()
        }
        
        // Сначала загружаем профиль - это критично для отображения
        do {
            let profileData = try await APIService.shared.getProfile()
            
            await MainActor.run {
                // Обновляем профиль сразу
                modelData.profile = UserProfile(
                    name: profileData.name ?? profileData.email,
                    email: profileData.email,
                    avatar: profileData.image
                )
                // Сохраняем ID пользователя для проверки лайков
                modelData.currentUserId = profileData.id
            }
        } catch {
            print("Error loading profile: \(error)")
            // Если не удалось загрузить профиль, разлогиниваем
            await MainActor.run {
                APIService.shared.logout()
                isAuthenticated = false
                modelData.clearAllData()
            }
            return
        }
        
        // Затем загружаем остальные данные (можно с ошибками, но не критично)
        do {
            async let expenses = APIService.shared.getExpenses()
            async let categories = APIService.shared.getCategories()
            
            let (expensesData, categoriesData) = try await (expenses, categories)
            
            // Опциональные данные - загружаем с обработкой ошибок
            var friendsData: [FriendResponse] = []
            var leaderboardData: [LeaderboardResponse] = []
            var postsData = PostsResponse(posts: [])
            
            // Загружаем друзей (если эндпоинт существует)
            do {
                friendsData = try await APIService.shared.getFriends()
            } catch {
                print("Friends endpoint not available: \(error)")
            }
            
            // Загружаем лидерборд (если эндпоинт существует)
            do {
                leaderboardData = try await APIService.shared.getLeaderboard()
            } catch {
                print("Leaderboard endpoint not available: \(error)")
            }
            
            // Загружаем посты (если эндпоинт существует)
            do {
                postsData = try await APIService.shared.getPosts()
            } catch {
                print("Posts endpoint not available: \(error)")
            }
            
            await MainActor.run {
                
                // Обновляем расходы
                modelData.expenses = expensesData.map { expense in
                    Expense(
                        id: UUID(uuidString: expense.id) ?? UUID(),
                        apiId: expense.id,
                        amount: Double(expense.amount) ?? 0,
                        category: expense.category.map { cat in
                            let icon = CategoryIconStorage.shared.loadIcon(categoryId: cat.id) ?? "tag.fill"
                            return Category(
                                id: cat.id,
                                name: cat.name,
                                color: Color(hex: cat.color) ?? .blue,
                                icon: icon,
                                type: Expense.ExpenseType.fromAPI(cat.type)
                            )
                        } ?? Category(id: "none", name: "Без категории", color: .gray, icon: "tag.fill", type: Expense.ExpenseType.fromAPI(expense.type)),
                        note: expense.note,
                        date: ISO8601DateFormatter().date(from: expense.spentAt) ?? Date(),
                        type: Expense.ExpenseType.fromAPI(expense.type)
                    )
                }
                
                // Обновляем категории
                modelData.categories = categoriesData.map { cat in
                    Category(
                        id: cat.id,
                        name: cat.name,
                        color: Color(hex: cat.color) ?? .blue,
                        icon: "tag.fill",
                        type: Expense.ExpenseType.fromAPI(cat.type)
                    )
                }
                
                // Обновляем друзей
                modelData.friends = friendsData.map { friend in
                    Friend(
                        id: UUID(uuidString: friend.id) ?? UUID(),
                        name: friend.name ?? friend.email,
                        email: friend.email
                    )
                }
                
                // Обновляем лидерборд
                modelData.leaderboard = leaderboardData.map { entry in
                    LeaderboardEntry(
                        userId: UUID(uuidString: entry.userId) ?? UUID(),
                        name: entry.name,
                        total: Double(entry.total) ?? 0
                    )
                }
                
                // Обновляем посты
                modelData.posts = postsData.posts.map { post in
                    Post(
                        id: UUID(uuidString: post.id) ?? UUID(),
                        apiId: post.id, // Сохраняем оригинальный API ID
                        content: post.content,
                        author: UserProfile(
                            name: post.author.name ?? post.author.id,
                            email: post.author.id,
                            avatar: post.author.image
                        ),
                        authorId: post.author.id, // Сохраняем ID автора
                        createdAt: ISO8601DateFormatter().date(from: post.createdAt) ?? Date(),
                        imageUrl: post.imageUrl.map { APIService.shared.getImageURL($0) },
                        likes: post.likes.map { like in
                            Like(id: UUID(), userId: UUID(uuidString: like.userId) ?? UUID())
                        },
                        comments: post.comments.map { comment in
                            Comment(
                                id: UUID(uuidString: comment.id) ?? UUID(),
                                content: comment.content,
                                author: UserProfile(
                                    name: comment.author.name ?? comment.author.id,
                                    email: comment.author.id,
                                    avatar: comment.author.image
                                ),
                                createdAt: ISO8601DateFormatter().date(from: comment.createdAt) ?? Date()
                            )
                        }
                    )
                }
            }
        } catch {
            print("Error loading user data: \(error)")
            // Если ошибка авторизации, разлогиниваем
            if let apiError = error as? APIError,
               case .unauthorized = apiError {
                await MainActor.run {
                    APIService.shared.logout()
                    isAuthenticated = false
                    modelData.clearAllData()
                }
            }
            // Для других ошибок просто логируем, профиль уже загружен
        }
    }
}

