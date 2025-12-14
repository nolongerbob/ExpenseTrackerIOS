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
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @AppStorage("notificationPermissionRequested") private var notificationPermissionRequested = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isAuthenticated {
                    if modelData.profile != nil {
                        MainTabView()
                    } else {
                        // Показываем красивый загрузчик пока профиль не загружен
                        LoadingView()
                    }
                } else {
                    // Показываем onboarding для новых пользователей
                    Group {
                        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
                            LoginView()
                        } else {
                            OnboardingView()
                        }
                    }
                }
            }
            .environment(modelData)
            .preferredColorScheme(appColorScheme)
            .task {
                await checkAuthentication()
            }
        }
    }
    
    private var appColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme
    }
    
    func checkAuthentication() async {
        let wasAuthenticated = APIService.shared.isAuthenticated
        isAuthenticated = wasAuthenticated
        
        if wasAuthenticated {
            // Загружаем локальные данные сразу (показываем их пользователю)
            await MainActor.run {
                modelData.loadLocalData()
            }
            // Затем синхронизируем с сервером в фоне (отложенно, не блокируя UI)
            Task { @MainActor in
                await syncUserData()
            }
            // Запускаем периодическую синхронизацию (тоже в фоне)
            Task { @MainActor in
                let syncService = SyncService(modelData: modelData)
                await syncService.startPeriodicSync()
            }
        } else {
            // Если не авторизован, очищаем все данные
            await MainActor.run {
                modelData.clearAllData()
            }
        }
    }
    
    func syncUserData() async {
        // Синхронизируем с сервером в фоне, не блокируя UI
        
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
        
        // Затем загружаем только критичные данные (expenses и categories)
        // Остальное загрузится позже через синхронизацию
        do {
            async let expenses = APIService.shared.getExpenses()
            async let categories = APIService.shared.getCategories()
            
            let (expensesData, categoriesData) = try await (expenses, categories)
            
            // Опциональные данные загружаем в фоне, не блокируя UI
            Task.detached(priority: .utility) {
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
                }
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
                        date: APIService.parseDate(expense.spentAt) ?? Date(),
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
                
                // Друзья, лидерборд и посты загружаются в фоне через Task.detached выше
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

