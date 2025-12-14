//
// ImageProcessor.swift
// Утилита для оптимизации и обработки изображений в фоне
//

import UIKit
import Foundation

class ImageProcessor {
    static let shared = ImageProcessor()
    
    private init() {}
    
    /// Оптимизирует изображение для загрузки (сжимает и уменьшает размер)
    func optimizeImage(_ image: UIImage, maxDimension: CGFloat = 1920, quality: CGFloat = 0.8) async -> Data? {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                // Уменьшаем размер изображения если нужно
                let resizedImage = self.resizeImage(image, maxDimension: maxDimension)
                
                // Сжимаем в JPEG
                let imageData = resizedImage.jpegData(compressionQuality: quality)
                
                continuation.resume(returning: imageData)
            }
        }
    }
    
    /// Уменьшает размер изображения до максимального размера
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // Если изображение уже меньше максимального размера, возвращаем как есть
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Вычисляем новый размер с сохранением пропорций
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Создаем новое изображение с новым размером
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    /// Создает thumbnail изображения
    func createThumbnail(_ image: UIImage, size: CGSize = CGSize(width: 200, height: 200)) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            Task.detached(priority: .userInitiated) {
                let thumbnail = image.preparingThumbnail(of: size)
                continuation.resume(returning: thumbnail)
            }
        }
    }
}


