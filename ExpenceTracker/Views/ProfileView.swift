//
// ProfileView.swift
// Экран профиля с liquid glass эффектом
//

import SwiftUI

struct ProfileView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @AppStorage("is_authenticated") private var isAuthenticated = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showFriends = false
    @State private var showCreatePost = false
    @State private var showSettings = false
    @State private var expandedComments: Set<UUID> = []
    @State private var commentTexts: [UUID: String] = [:]
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient(for: currentColorScheme)
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Avatar and name
                        LiquidGlassCard {
                            HStack(spacing: 16) {
                                // Имя и почта слева
                                VStack(alignment: .leading, spacing: 8) {
                                    if let profile = modelData.profile {
                                        Text(profile.name)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                        
                                        Text(profile.email)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ProgressView()
                                            .tint(AppColors.primaryText(for: currentColorScheme))
                                    }
                                }
                                
                                Spacer()
                                
                                // Аватар справа
                                Group {
                                    if let profile = modelData.profile,
                                       let avatar = profile.avatar, !avatar.isEmpty,
                                       let avatarURL = URL(string: APIService.shared.getImageURL(avatar)) {
                                        AsyncImage(url: avatarURL) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            case .failure, .empty:
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
                                                            .font(.system(size: 40, weight: .bold))
                                                            .foregroundStyle(.white)
                                                    }
                                            @unknown default:
                                                ProgressView()
                                                    .tint(AppColors.primaryText(for: currentColorScheme))
                                            }
                                        }
                                        .frame(width: 80, height: 80)
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
                                            .frame(width: 80, height: 80)
                                            .overlay {
                                                if let profile = modelData.profile {
                                                    Text(String(profile.name.prefix(1)).uppercased())
                                                        .font(.system(size: 40, weight: .bold))
                                                        .foregroundStyle(.white)
                                                } else {
                                                    ProgressView()
                                                        .tint(.white)
                                                }
                                            }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                        }
                        .padding(.horizontal)
                        
                        // Friends button
                        Button {
                            showFriends = true
                        } label: {
                            LiquidGlassCard {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                    
                                    Text("Друзья")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                    
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
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                        .contentShape(Rectangle())
                        
                        // Blog section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Блог")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                
                                Spacer()
                                
                                Button {
                                    showCreatePost = true
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                            }
                            .padding(.horizontal)
                            
                            // Posts
                            ForEach(modelData.posts.prefix(5)) { post in
                                PostCard(
                                    post: post,
                                    expandedComments: $expandedComments,
                                    commentTexts: $commentTexts,
                                    onLike: {
                                        Task {
                                            await updatePost(postId: post.id)
                                        }
                                    },
                                    onAddComment: { comment in
                                        modelData.addComment(postId: post.id, comment: comment)
                                        Task {
                                            await updatePost(postId: post.id)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 8)
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
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
            .sheet(isPresented: $showFriends) {
                FriendsView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                // Загружаем посты только если их нет локально
                if modelData.posts.isEmpty {
                    await loadPosts()
                }
            }
        }
    }
    
    func refreshData() async {
        await loadPosts()
    }
    
    func updatePost(postId: UUID) async {
        do {
            let postsResponse = try await APIService.shared.getPosts()
            
            await MainActor.run {
                if let post = modelData.posts.first(where: { $0.id == postId }),
                   let updatedPost = postsResponse.posts.first(where: { $0.id == post.apiId }) {
                    let likes: [Like] = updatedPost.likes.compactMap { like in
                        guard let userIdString = like.userId else { return nil }
                        return Like(id: UUID(), userId: UUID(uuidString: userIdString) ?? UUID())
                    }
                    let comments = updatedPost.comments.map { comment in
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
                    modelData.updatePost(postId: postId, likes: likes, comments: comments)
                }
            }
        } catch {
            print("Error updating post: \(error)")
        }
    }
    
    func loadPosts() async {
        do {
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
            }
        } catch {
            print("Error loading posts: \(error)")
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
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @FocusState private var isCommentFieldFocused: Bool
    @State private var isLiked = false
    @State private var isLiking = false
    @State private var isCommenting = false
    @State private var likesCount: Int = 0
    @State private var commentsCount: Int = 0
    @State private var showDeleteConfirmation = false
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        LiquidGlassCard {
            postContent
        }
        .padding(.horizontal)
        .confirmationDialog("Удалить пост?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                Task {
                    await deletePost()
                }
            }
            Button("Отмена", role: .cancel) {
                showDeleteConfirmation = false
            }
        } message: {
            Text("Это действие нельзя отменить")
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: post.likes.count) { _, newValue in
            likesCount = newValue
            updateLikedState()
        }
        .onChange(of: post.comments.count) { _, newValue in
            commentsCount = newValue
        }
        .onChange(of: post.likes) { _, _ in
            updateLikedState()
        }
    }
    
    private var postContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            postHeader
            postContentText
            postImage
            postActions
            postCommentsSection
        }
    }
    
    private var postHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            authorAvatar
            authorInfo
            Spacer()
                .allowsHitTesting(false)
            deleteButton
        }
    }
    
    private var authorAvatar: some View {
        Group {
            if let avatar = post.author.avatar, !avatar.isEmpty,
               let avatarURL = URL(string: APIService.shared.getImageURL(avatar)) {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        defaultAvatar
                    @unknown default:
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.5)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                defaultAvatar
            }
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 40)
            .overlay {
                Text(String(post.author.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
    }
    
    private var authorInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.author.name)
                .font(.headline)
                .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
            
            Text(post.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText(for: currentColorScheme))
        }
    }
    
    @ViewBuilder
    private var deleteButton: some View {
        if let currentUserId = modelData.currentUserId,
           post.authorId == currentUserId {
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
        }
    }
    
    private var postContentText: some View {
        Text(post.content)
            .font(.body)
            .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var postImage: some View {
        if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    ProgressView()
                        .tint(AppColors.primaryText(for: currentColorScheme))
                @unknown default:
                    ProgressView()
                        .tint(AppColors.primaryText(for: currentColorScheme))
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
            .clipped()
            .allowsHitTesting(false)
        }
    }
    
    private var postActions: some View {
        HStack(spacing: 24) {
            likeButton
            commentButton
        }
        .font(.subheadline)
    }
    
    private var likeButton: some View {
        Button {
            Task {
                await toggleLike()
            }
        } label: {
            HStack(spacing: 6) {
                if isLiking {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AppColors.primaryText(for: currentColorScheme))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : AppColors.primaryText(for: currentColorScheme))
                }
                Text("\(likesCount)")
                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidGlassActionButton())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .disabled(isLiking)
    }
    
    private var commentButton: some View {
        Button {
            withAnimation {
                if expandedComments.contains(post.id) {
                    expandedComments.remove(post.id)
                } else {
                    expandedComments.insert(post.id)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                Text("\(commentsCount)")
                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidGlassActionButton())
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var postCommentsSection: some View {
        if expandedComments.contains(post.id) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(post.comments) { comment in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.author.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            Text(comment.content)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Кнопка удаления для своих комментариев
                        if let currentUserId = modelData.currentUserId,
                           comment.authorId == currentUserId {
                            Button {
                                Task {
                                    await deleteComment(commentId: comment.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.red)
                                    .frame(width: 30, height: 30)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                addCommentForm
            }
            .padding(.top, 8)
        }
    }
    
    private var addCommentForm: some View {
        HStack(spacing: 8) {
            TextField("Добавить комментарий...", text: Binding(
                get: { commentTexts[post.id] ?? "" },
                set: { commentTexts[post.id] = $0 }
            ))
            .focused($isCommentFieldFocused)
            .textFieldStyle(.plain)
            .padding(12)
            .background(AppColors.textFieldBackground(for: currentColorScheme))
            .cornerRadius(8)
            .foregroundStyle(AppColors.textFieldText(for: currentColorScheme))
            .frame(minHeight: 44)
            
            Button {
                Task {
                    await addComment()
                }
            } label: {
                if isCommenting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.blue)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
            .buttonStyle(LiquidGlassSmallButton())
            .disabled(isCommenting || (commentTexts[post.id] ?? "").isEmpty)
        }
    }
    
    private func setupInitialState() {
        likesCount = post.likes.count
        commentsCount = post.comments.count
        updateLikedState()
    }
    
    private func updateLikedState() {
        if let currentUserId = modelData.currentUserId,
           let userIdUUID = UUID(uuidString: currentUserId) {
            isLiked = post.likes.contains { $0.userId == userIdUUID }
        }
    }
    
    func toggleLike() async {
        guard !isLiking else { return }
        
        await MainActor.run {
            isLiking = true
        }
        
        do {
            let response = try await APIService.shared.toggleLike(postId: post.apiId)
            
            await MainActor.run {
                isLiked = response.liked ?? !isLiked
                isLiking = false
            }
            
            onLike()
            
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
        guard let text = commentTexts[post.id], !text.isEmpty, !isCommenting else { return }
        
        await MainActor.run {
            isCommenting = true
        }
        
        do {
            let response = try await APIService.shared.addComment(postId: post.apiId, content: text)
            
            let comment = Comment(
                id: UUID(uuidString: response.comment.id) ?? UUID(),
                apiId: response.comment.id,
                content: response.comment.content,
                author: UserProfile(
                    name: response.comment.author.name ?? response.comment.author.id,
                    email: response.comment.author.id,
                    avatar: response.comment.author.image
                ),
                authorId: response.comment.author.id,
                createdAt: ISO8601DateFormatter().date(from: response.comment.createdAt) ?? Date()
            )
            
            await MainActor.run {
                commentTexts[post.id] = ""
                isCommenting = false
                isCommentFieldFocused = false
            }
            
            onAddComment(comment)
            
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
    
    func deleteComment(commentId: UUID) async {
        guard let comment = post.comments.first(where: { $0.id == commentId }) else { return }
        
        do {
            try await APIService.shared.deleteComment(postId: post.apiId, commentId: comment.apiId)
            
            await MainActor.run {
                modelData.removeComment(postId: post.id, commentId: commentId)
                commentsCount = max(0, commentsCount - 1)
            }
        } catch {
            print("Error deleting comment: \(error)")
        }
    }
    
    func deletePost() async {
        // Сбрасываем состояние диалога сразу
        await MainActor.run {
            showDeleteConfirmation = false
        }
        
        do {
            try await APIService.shared.deletePost(postId: post.apiId)
            
            await MainActor.run {
                modelData.removePost(postId: post.id)
            }
        } catch {
            print("Error deleting post: \(error)")
            // В случае ошибки тоже сбрасываем состояние
            await MainActor.run {
                showDeleteConfirmation = false
            }
        }
    }
}
