//
// LoginView.swift
// Экран входа в систему
//

import SwiftUI

struct LoginView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @AppStorage("is_authenticated") private var isAuthenticated = false
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRegister = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Добро пожаловать!")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Войдите в свой аккаунт")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 60)
                    
                    LiquidGlassCard {
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("example@mail.com", text: $email)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Пароль")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                SecureField("Введите пароль", text: $password)
                                    .textFieldStyle(.plain)
                                    .autocapitalization(.none)
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                    .foregroundStyle(.white)
                            }
                            
                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            
                            Button {
                                Task {
                                    await login()
                                }
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Text("Войти")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(LiquidGlassButton())
                            .frame(maxWidth: .infinity)
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            
                            HStack {
                                Text("Нет аккаунта?")
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    showRegister = true
                                } label: {
                                    Text("Зарегистрироваться")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }
    
    func login() async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await APIService.shared.login(email: email, password: password)
            
            // Очищаем данные перед загрузкой
            await MainActor.run {
                modelData.clearAllData()
            }
            
            // Загружаем данные пользователя (включая профиль)
            await loadUserData()
            
            // Устанавливаем флаг авторизации только после успешной загрузки
            await MainActor.run {
                if modelData.profile != nil {
                    isAuthenticated = true
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                // Очищаем данные при ошибке
                modelData.clearAllData()
            }
        }
    }
    
    func loadUserData() async {
        // Очищаем все данные перед загрузкой новых
        await MainActor.run {
            modelData.clearAllData()
        }
        
        // Сначала загружаем профиль - это критично
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
            await MainActor.run {
                errorMessage = "Не удалось загрузить профиль: \(error.localizedDescription)"
                isLoading = false
                modelData.clearAllData()
            }
            return
        }
        
        // Затем загружаем остальные данные (не критично, можно с ошибками)
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
            // Ошибки загрузки данных не критичны, просто логируем
            print("Error loading user data: \(error)")
        }
    }
}

// Расширение для создания Color из hex строки
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

