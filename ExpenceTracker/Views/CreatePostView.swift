//
// CreatePostView.swift
// Экран создания поста
//

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @FocusState private var isTextFieldFocused: Bool
    @State private var content = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var isUploadingImage = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    
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
                    VStack(spacing: 20) {
                        // Text input
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Текст поста")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Что нового?", text: $content, axis: .vertical)
                                    .focused($isTextFieldFocused)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(AppColors.textFieldText(for: currentColorScheme))
                                    .padding(12)
                                    .frame(minHeight: 120, alignment: .topLeading)
                                    .background(AppColors.textFieldBackground(for: currentColorScheme))
                                    .cornerRadius(12)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Image picker
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Изображение")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                if let image = selectedImage {
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 200)
                                            .cornerRadius(12)
                                            .clipped()
                                            .contentShape(Rectangle())
                                        
                                        Button {
                                            selectedImage = nil
                                            selectedPhoto = nil
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                                .font(.title2)
                                                .background {
                                                    Circle()
                                                        .fill(.white)
                                                        .frame(width: 24, height: 24)
                                                }
                                        }
                                        .buttonStyle(LiquidGlassSmallButton())
                                        .padding(8)
                                    }
                                } else {
                                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                        HStack {
                                            Image(systemName: "photo")
                                                .foregroundStyle(.blue)
                                            Text("Выбрать фото")
                                                .foregroundStyle(.blue)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                    }
                                    .buttonStyle(LiquidGlassActionButton())
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        
                        // Progress indicator
                        if isUploadingImage {
                            VStack(spacing: 8) {
                                ProgressView(value: uploadProgress, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .tint(.yellow)
                                Text("Загрузка изображения... \(Int(uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Submit button
                        Button {
                            Task { @MainActor in
                                await createPost()
                            }
                        } label: {
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                    Text("Публикация...")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            } else {
                                Text("Опубликовать")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(LiquidGlassButton())
                        .disabled(content.isEmpty || isLoading)
                        .opacity(content.isEmpty || isLoading ? 0.5 : 1.0)
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Создать пост")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Отмена")
                            .foregroundStyle(.white)
                            .font(.body)
                    }
                    .frame(minWidth: 60, minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue = newValue else { return }
                Task.detached(priority: .userInitiated) {
                    // Загружаем изображение в фоне
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                        }
                    }
                }
            }
            .onAppear {
                // Убираем автофокус - он может вызывать зависания
                // Пользователь сам может нажать на поле для ввода
            }
        }
    }
    
    func createPost() async {
        guard !content.isEmpty else { return }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            isUploadingImage = false
            uploadProgress = 0
        }
        
        do {
            var imageUrl: String? = nil
            
            // Загружаем изображение, если есть (в фоне)
            if let image = selectedImage {
                await MainActor.run {
                    isUploadingImage = true
                    uploadProgress = 0.1
                }
                
                // Оптимизируем изображение в фоне
                if let imageData = await ImageProcessor.shared.optimizeImage(image, maxDimension: 1920, quality: 0.8) {
                    await MainActor.run {
                        uploadProgress = 0.3
                    }
                    
                    // Загружаем на сервер
                    let uploadResponse = try await APIService.shared.uploadImage(imageData: imageData)
                    imageUrl = uploadResponse.url
                    
                    await MainActor.run {
                        uploadProgress = 1.0
                        isUploadingImage = false
                    }
                } else {
                    await MainActor.run {
                        isUploadingImage = false
                        errorMessage = "Не удалось обработать изображение"
                        isLoading = false
                    }
                    return
                }
            }
            
            await MainActor.run {
                uploadProgress = 0
            }
            
            // Создаем пост через API
            let postResponse = try await APIService.shared.createPost(
                content: content,
                imageUrl: imageUrl
            )
            
            // Обновляем локальные данные
            await MainActor.run {
                let newPost = Post(
                    id: UUID(uuidString: postResponse.id) ?? UUID(),
                    apiId: postResponse.id,
                    content: postResponse.content,
                    author: UserProfile(
                        name: postResponse.author.name ?? postResponse.author.id,
                        email: postResponse.author.id,
                        avatar: postResponse.author.image
                    ),
                    authorId: postResponse.author.id,
                    createdAt: ISO8601DateFormatter().date(from: postResponse.createdAt) ?? Date(),
                    imageUrl: postResponse.imageUrl,
                    likes: [],
                    comments: []
                )
                
                modelData.addPost(newPost)
                isLoading = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                isUploadingImage = false
                uploadProgress = 0
            }
        }
    }
}
