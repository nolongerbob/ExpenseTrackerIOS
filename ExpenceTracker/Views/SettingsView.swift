//
// SettingsView.swift
// Экран настроек профиля
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @Environment(\.dismiss) private var dismiss
    @AppStorage("is_authenticated") private var isAuthenticated = false
    @AppStorage("colorScheme") private var colorScheme: String = "dark"
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showLogoutAlert = false
    
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
                        // Фото профиля
                        LiquidGlassCard {
                            VStack(spacing: 16) {
                                Text("Фото профиля")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                    Group {
                                        if let image = selectedImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } else if let avatar = modelData.profile?.avatar, !avatar.isEmpty,
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
                                                        Text(String(modelData.profile?.name.prefix(1) ?? "П").uppercased())
                                                            .font(.system(size: 48, weight: .bold))
                                                            .foregroundStyle(.white)
                                                    }
                                            }
                                            .frame(width: 120, height: 120)
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
                                                .frame(width: 120, height: 120)
                                                .overlay {
                                                    Text(String(modelData.profile?.name.prefix(1) ?? "П").uppercased())
                                                        .font(.system(size: 48, weight: .bold))
                                                        .foregroundStyle(.white)
                                                }
                                        }
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle()
                                            .strokeBorder(.white.opacity(0.3), lineWidth: 2)
                                    }
                                }
                                
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }
                                
                                if let error = errorMessage {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical)
                        }
                        .padding(.horizontal)
                        
                        // Тема
                        LiquidGlassCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Тема")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Spacer()
                                    
                                    Picker("Тема", selection: $colorScheme) {
                                        Text("Темная").tag("dark")
                                        Text("Светлая").tag("light")
                                        Text("Системная").tag("system")
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                        
                        // Выход из аккаунта
                        LiquidGlassCard {
                            Button {
                                showLogoutAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Выйти из аккаунта")
                                        .foregroundStyle(.red)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    await loadPhoto(newValue)
                }
            }
            .onChange(of: colorScheme) { _, newValue in
                updateColorScheme(newValue)
            }
            .alert("Выйти из аккаунта?", isPresented: $showLogoutAlert) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Вы уверены, что хотите выйти из аккаунта?")
            }
        }
    }
    
    func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
                
                // Загружаем изображение на сервер
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    let uploadResponse = try await APIService.shared.uploadImage(imageData: imageData)
                    let imageUrl = APIService.shared.getImageURL(uploadResponse.url)
                    
                    // Обновляем профиль
                    let updatedProfile = try await APIService.shared.updateProfile(name: nil, image: imageUrl)
                    
                    await MainActor.run {
                        modelData.profile?.avatar = updatedProfile.image
                        isLoading = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func updateColorScheme(_ scheme: String) {
        // Обновление темы будет применено через @AppStorage
        // Можно добавить сохранение в UserDefaults для применения при следующем запуске
    }
    
    func logout() {
        APIService.shared.logout()
        isAuthenticated = false
        modelData.clearAllData()
    }
}

