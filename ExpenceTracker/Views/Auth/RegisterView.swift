//
// RegisterView.swift
// Экран регистрации
//

import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExpenseModelData.self) private var modelData
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                    VStack(spacing: 32) {
                        VStack(spacing: 8) {
                            Text("Создать аккаунт")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("Зарегистрируйтесь для начала")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)
                        
                        LiquidGlassCard {
                            VStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Имя (необязательно)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("Ваше имя", text: $name)
                                        .textFieldStyle(.plain)
                                        .padding(12)
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                        .foregroundStyle(.white)
                                }
                                
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
                                    
                                    SecureField("Минимум 6 символов", text: $password)
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
                                        await register()
                                    }
                                } label: {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("Зарегистрироваться")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(LiquidGlassButton())
                                .frame(maxWidth: .infinity)
                                .disabled(isLoading || email.isEmpty || password.isEmpty || password.count < 6)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func register() async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await APIService.shared.register(
                email: email,
                password: password,
                name: name.isEmpty ? nil : name
            )
            
            // Очищаем данные перед загрузкой
            await MainActor.run {
                modelData.clearAllData()
            }
            
            // Загружаем профиль из API
            let profileData = try await APIService.shared.getProfile()
            
            await MainActor.run {
                modelData.profile = UserProfile(
                    name: profileData.name ?? profileData.email,
                    email: profileData.email,
                    avatar: profileData.image
                )
                // Сохраняем ID пользователя для проверки лайков
                modelData.currentUserId = profileData.id
                
                // Устанавливаем флаг авторизации
                UserDefaults.standard.set(true, forKey: "is_authenticated")
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

