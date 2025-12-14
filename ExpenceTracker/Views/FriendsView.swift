//
// FriendsView.swift
// Экран управления друзьями
//

import SwiftUI

struct FriendsView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var friendEmail = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var friendRequests: FriendRequestsResponse?
    @State private var showRequests = false
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient(for: currentColorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Форма добавления друга
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Добавить друга")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                
                                HStack {
                                    TextField("Email друга", text: $friendEmail)
                                        .textFieldStyle(.plain)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .padding(12)
                                        .background(AppColors.textFieldBackground(for: currentColorScheme))
                                        .cornerRadius(8)
                                        .foregroundStyle(AppColors.textFieldText(for: currentColorScheme))
                                    
                                    Button {
                                        Task {
                                            await addFriend()
                                        }
                                    } label: {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(.circular)
                                                .tint(.white)
                                        } else {
                                            Text("Добавить")
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(.blue)
                                    .cornerRadius(8)
                                    .disabled(friendEmail.isEmpty || isLoading)
                                }
                                
                                if let error = errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Запросы на дружбу
                        if let requests = friendRequests, (!requests.incoming.isEmpty || !requests.outgoing.isEmpty) {
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Запросы на дружбу")
                                        .font(.headline)
                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                    
                                    if !requests.incoming.isEmpty {
                                        Text("Входящие")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        
                                        ForEach(requests.incoming, id: \.id) { request in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(request.user.name ?? request.user.email)
                                                        .font(.headline)
                                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                                    Text(request.user.email)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 8) {
                                                    Button {
                                                        Task {
                                                            await respondToRequest(requestId: request.id, action: "accept")
                                                        }
                                                    } label: {
                                                        Image(systemName: "checkmark")
                                                            .foregroundStyle(.green)
                                                    }
                                                    
                                                    Button {
                                                        Task {
                                                            await respondToRequest(requestId: request.id, action: "reject")
                                                        }
                                                    } label: {
                                                        Image(systemName: "xmark")
                                                            .foregroundStyle(.red)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                    
                                    if !requests.outgoing.isEmpty {
                                        Text("Исходящие")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                        
                                        ForEach(requests.outgoing, id: \.id) { request in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(request.user.name ?? request.user.email)
                                                        .font(.headline)
                                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                                    Text(request.user.email)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Text("Ожидание...")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Список друзей
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Друзья (\(modelData.friends.count))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                .padding(.horizontal)
                            
                            if modelData.friends.isEmpty {
                                LiquidGlassCard {
                                    VStack(spacing: 16) {
                                        Image(systemName: "person.2")
                                            .font(.system(size: 48))
                                            .foregroundStyle(.secondary)
                                        Text("У вас пока нет друзей")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                                }
                                .padding(.horizontal)
                            } else {
                                ForEach(modelData.friends) { friend in
                                    LiquidGlassCard {
                                        HStack {
                                            Circle()
                                                .fill(.blue.opacity(0.3))
                                                .frame(width: 50, height: 50)
                                                .overlay {
                                                    Text(String(friend.name.prefix(1).uppercased()))
                                                        .font(.headline)
                                                        .foregroundStyle(.white)
                                                }
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(friend.name)
                                                    .font(.headline)
                                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                                
                                                Text(friend.email)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await loadFriends()
                }
            }
            .navigationTitle("Друзья")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear {
                Task {
                    await loadFriends()
                }
            }
        }
    }
    
    func addFriend() async {
        guard !friendEmail.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await APIService.shared.addFriend(email: friendEmail)
            
            await MainActor.run {
                friendEmail = ""
                isLoading = false
            }
            
            // Обновляем список друзей
            await loadFriends()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func loadFriends() async {
        // Загружаем друзей (если эндпоинт существует)
        do {
            let friendsData = try await APIService.shared.getFriends()
            
            await MainActor.run {
                modelData.friends = friendsData.map { friend in
                    Friend(
                        id: UUID(uuidString: friend.id) ?? UUID(),
                        name: friend.name ?? friend.email,
                        email: friend.email
                    )
                }
            }
        } catch {
            print("Error loading friends: \(error)")
            // Если эндпоинт не существует, просто оставляем пустой список
            await MainActor.run {
                modelData.friends = []
            }
        }
        
        // Загружаем запросы на дружбу (если эндпоинт существует)
        do {
            let requestsData = try await APIService.shared.getFriendRequests()
            
            await MainActor.run {
                friendRequests = requestsData
            }
        } catch {
            print("Error loading friend requests: \(error)")
            // Если эндпоинт не существует, просто оставляем пустой список
            await MainActor.run {
                friendRequests = FriendRequestsResponse(incoming: [], outgoing: [])
            }
        }
    }
    
    func respondToRequest(requestId: String, action: String) async {
        do {
            try await APIService.shared.respondToFriendRequest(requestId: requestId, action: action)
            await loadFriends()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

