//
// ProfileView.swift
// Экран профиля с liquid glass эффектом
//

import SwiftUI

struct ProfileView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @AppStorage("is_authenticated") private var isAuthenticated = false
    @State private var showFriends = false
    @State private var showCreatePost = false
    @State private var showSettings = false
    @State private var expandedComments: Set<UUID> = []
    @State private var commentTexts: [UUID: String] = [:]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Аватар и имя
                        LiquidGlassCard {
                            VStack(spacing: 16) {
                                Group {
                                    if let profile = modelData.profile,
                                       let avatar = profile.avatar, !avatar.isEmpty,
                                       let avatarURL = URL(string: APIService.shared.getImageURL(avatar)) {
                                        AsyncImage(url: avatarURL) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.blue, .purple],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .overlay {
                                                    Text(String(profile.name.prefix(1)).uppercased())
                                                        .font(.system(size: 48, weight: .bold))
                                                        .foregroundStyle(.white)
                                                }
                                        }
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 100, height: 100)
                                            .overlay {
                                                if let profile = modelData.profile {
                                                    Text(String(profile.name.prefix(1)).uppercased())
                                                        .font(.system(size: 48, weight: .bold))
                                                        .foregroundStyle(.white)
                                                } else {
                                                    ProgressView()
                                                        .tint(.white)
                                                }
                                            }
                                    }
                                }
                                
                                if let profile = modelData.profile {
                                    Text(profile.name)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.white)
                                    
                                    Text(profile.email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                        }
                        .padding(.horizontal)
                        
                        // Статистика
                        LiquidGlassCard {
                            VStack(spacing: 16) {
                                StatRow(title: "Всего расходов", value: formatCurrency(totalExpenses))
                                Divider()
                                StatRow(title: "Операций", value: "\(modelData.expenses.count)")
                                Divider()
                                StatRow(title: "Категорий", value: "\(modelData.categories.count)")
                            }
                        }
                        .padding(.horizontal)
                        
                        // Друзья
                        NavigationLink(destination: FriendsView()) {
                            LiquidGlassCard {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    
                                    Text("Друзья")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(modelData.friends.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        
                        // Блог
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Блог")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                Button {
                                    showCreatePost = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Кнопка создания поста
                            Button {
                                showCreatePost = true
                            } label: {
                                LiquidGlassCard {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.blue)
                                        Text("Создать пост")
                                            .font(.headline)
                                            .foregroundStyle(.blue)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                            
                            // Посты
                            ForEach(modelData.posts.prefix(5)) { post in
                                PostCard(
                                    post: post,
                                    expandedComments: $expandedComments,
                                    commentTexts: $commentTexts,
                                    onLike: {
                                        // Обновляем конкретный пост после лайка
                                        Task {
                                            await updatePost(postId: post.id)
                                        }
                                    },
                                    onAddComment: { comment in
                                        modelData.addComment(postId: post.id, comment: comment)
                                        // Обновляем пост после добавления комментария
                                        Task {
                                            await updatePost(postId: post.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                Task {
                    await loadPosts()
                }
            }
        }
    }
    
    func refreshData() async {
        await loadPosts()
    }
    
    func updatePost(postId: UUID) async {
        // Обновляем конкретный пост из API
        do {
            let postsResponse = try await APIService.shared.getPosts()
            
            await MainActor.run {
                if let post = modelData.posts.first(where: { $0.id == postId }),
                   let updatedPost = postsResponse.posts.first(where: { $0.id == post.apiId }) {
                    // Маппим лайки: API возвращает userId как String, но мы храним как UUID
                    let likes = updatedPost.likes.map { like in
                        Like(id: UUID(), userId: UUID(uuidString: like.userId) ?? UUID())
                    }
                    let comments = updatedPost.comments.map { comment in
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
                    modelData.updatePost(postId: postId, likes: likes, comments: comments)
                }
            }
        } catch {
            print("Error updating post: \(error)")
        }
    }
    
    func loadPosts() async {
        do {
            // Загружаем профиль для получения ID пользователя
            if modelData.currentUserId == nil {
                let profileData = try await APIService.shared.getProfile()
                await MainActor.run {
                    modelData.currentUserId = profileData.id
                }
            }
            
            let postsResponse = try await APIService.shared.getPosts()
            
            await MainActor.run {
                modelData.posts = postsResponse.posts.map { post in
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
            print("Error loading posts: \(error)")
            // Если эндпоинт не существует, просто оставляем пустой список
            await MainActor.run {
                modelData.posts = []
            }
        }
    }
    
    var totalExpenses: Double {
        modelData.expenses.reduce(0) { $0 + $1.amount }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₽"
    }
    
    func logout() {
        APIService.shared.logout()
        isAuthenticated = false
        modelData.clearAllData()
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
    }
}

struct PostCard: View {
    let post: Post
    @Binding var expandedComments: Set<UUID>
    @Binding var commentTexts: [UUID: String]
    let onLike: () -> Void
    let onAddComment: (Comment) -> Void
    @Environment(ExpenseModelData.self) private var modelData
    @State private var isLiked = false
    @State private var isLiking = false
    @State private var isCommenting = false
    @State private var likesCount: Int = 0
    @State private var commentsCount: Int = 0
    
    var body: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Заголовок поста
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.author.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(post.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Кнопки редактирования и удаления для своих постов
                    if let currentUserId = modelData.currentUserId,
                       post.authorId == currentUserId {
                        Menu {
                            Button(role: .destructive) {
                                Task {
                                    await deletePost()
                                }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                // Содержимое поста
                Text(post.content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .lineLimit(nil)
                
                // Изображение (если есть)
                if let imageUrl = post.imageUrl {
                    // imageUrl уже обработан в loadPosts() через getImageURL
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                }
                
                // Действия
                HStack(spacing: 24) {
                    Button {
                        Task {
                            await toggleLike()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isLiking {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .foregroundStyle(isLiked ? .red : .white)
                            }
                            Text("\(likesCount)")
                                .foregroundStyle(.white)
                        }
                    }
                    .disabled(isLiking)
                    
                    Button {
                        if expandedComments.contains(post.id) {
                            expandedComments.remove(post.id)
                        } else {
                            expandedComments.insert(post.id)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.right")
                                .foregroundStyle(.white)
                            Text("\(commentsCount)")
                                .foregroundStyle(.white)
                        }
                    }
                }
                .font(.subheadline)
                
                // Комментарии
                if expandedComments.contains(post.id) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(post.comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.author.name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                
                                Text(comment.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                            .padding(.vertical, 4)
                        }
                        
                        // Форма добавления комментария
                        HStack {
                            TextField("Добавить комментарий...", text: Binding(
                                get: { commentTexts[post.id] ?? "" },
                                set: { commentTexts[post.id] = $0 }
                            ))
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundStyle(.white)
                            
                            Button {
                                Task {
                                    await addComment()
                                }
                            } label: {
                                if isCommenting {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.blue)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                }
                            }
                            .disabled(isCommenting || (commentTexts[post.id] ?? "").isEmpty)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal)
        .onAppear {
            // Обновляем счетчики
            likesCount = post.likes.count
            commentsCount = post.comments.count
            
            // Проверяем, лайкнул ли текущий пользователь пост
            if let currentUserId = modelData.currentUserId,
               let userIdUUID = UUID(uuidString: currentUserId) {
                // Сравниваем UUID напрямую
                isLiked = post.likes.contains { $0.userId == userIdUUID }
            }
        }
        .onChange(of: post.likes.count) { _, newValue in
            likesCount = newValue
        }
        .onChange(of: post.comments.count) { _, newValue in
            commentsCount = newValue
        }
    }
    
    func toggleLike() async {
        isLiking = true
        
        do {
            // Используем apiId вместо id.uuidString
            let response = try await APIService.shared.toggleLike(postId: post.apiId)
            
            await MainActor.run {
                isLiked = response.liked ?? !isLiked
                isLiking = false
            }
            
            // Обновляем данные поста после успешного лайка
            onLike()
            
            // Обновляем счетчик лайков из обновленного поста
            await MainActor.run {
                if let updatedPost = modelData.posts.first(where: { $0.id == post.id }) {
                    likesCount = updatedPost.likes.count
                    if let currentUserId = modelData.currentUserId,
                       let userIdUUID = UUID(uuidString: currentUserId) {
                        isLiked = updatedPost.likes.contains { $0.userId == userIdUUID }
                    }
                }
            }
        } catch {
            await MainActor.run {
                isLiking = false
                print("Error toggling like: \(error)")
            }
        }
    }
    
    func addComment() async {
        guard let text = commentTexts[post.id], !text.isEmpty else { return }
        
        isCommenting = true
        
        do {
            // Используем apiId вместо id.uuidString
            let response = try await APIService.shared.addComment(postId: post.apiId, content: text)
            
            let comment = Comment(
                id: UUID(uuidString: response.comment.id) ?? UUID(),
                content: response.comment.content,
                author: UserProfile(
                    name: response.comment.author.name ?? response.comment.author.id,
                    email: response.comment.author.id,
                    avatar: response.comment.author.image
                ),
                createdAt: ISO8601DateFormatter().date(from: response.comment.createdAt) ?? Date()
            )
            
            await MainActor.run {
                commentTexts[post.id] = ""
                isCommenting = false
            }
            
            // Обновляем данные поста после успешного комментария
            onAddComment(comment)
            
            // Обновляем счетчик комментариев из обновленного поста
            await MainActor.run {
                if let updatedPost = modelData.posts.first(where: { $0.id == post.id }) {
                    commentsCount = updatedPost.comments.count
                }
            }
        } catch {
            await MainActor.run {
                isCommenting = false
                print("Error adding comment: \(error)")
            }
        }
    }
    
    func deletePost() async {
        do {
            try await APIService.shared.deletePost(postId: post.apiId)
            
            // Удаляем пост из локальных данных
            await MainActor.run {
                modelData.removePost(postId: post.id)
            }
        } catch {
            print("Error deleting post: \(error)")
        }
    }
}

