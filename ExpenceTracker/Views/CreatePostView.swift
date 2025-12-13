//
// CreatePostView.swift
// Экран создания поста
//

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
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
                    VStack(spacing: 20) {
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Текст поста")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Что нового?", text: $content, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(.white)
                                    .frame(minHeight: 120, alignment: .top)
                            }
                        }
                        .padding(.horizontal)
                        
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
                                                }
                                        }
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
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        
                        Button {
                            Task {
                                await createPost()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Опубликовать")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(content.isEmpty || isLoading ? Color.gray : Color.blue)
                        .cornerRadius(12)
                        .disabled(content.isEmpty || isLoading)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Создать пост")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }
    
    func createPost() async {
        guard !content.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            var imageUrl: String? = nil
            
            // Загружаем изображение, если есть
            if let image = selectedImage,
               let imageData = image.jpegData(compressionQuality: 0.8) {
                let uploadResponse = try await APIService.shared.uploadImage(imageData: imageData)
                imageUrl = APIService.shared.getImageURL(uploadResponse.url)
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
                    apiId: postResponse.id, // Сохраняем оригинальный API ID
                    content: postResponse.content,
                    author: UserProfile(
                        name: postResponse.author.name ?? postResponse.author.id,
                        email: postResponse.author.id,
                        avatar: postResponse.author.image
                    ),
                    authorId: postResponse.author.id, // Сохраняем ID автора
                    createdAt: ISO8601DateFormatter().date(from: postResponse.createdAt) ?? Date(),
                    imageUrl: postResponse.imageUrl,
                    likes: [],
                    comments: []
                )
                
                modelData.addPost(newPost)
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

