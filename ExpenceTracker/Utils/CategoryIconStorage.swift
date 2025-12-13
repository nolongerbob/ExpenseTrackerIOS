//
// CategoryIconStorage.swift
// Утилита для локального хранения иконок категорий
//

import Foundation

class CategoryIconStorage {
    static let shared = CategoryIconStorage()
    private let userDefaults = UserDefaults.standard
    private let iconsKey = "categoryIcons"
    
    private init() {}
    
    // Сохранить иконку для категории
    func saveIcon(categoryId: String, icon: String) {
        var icons = loadAllIcons()
        icons[categoryId] = icon
        userDefaults.set(icons, forKey: iconsKey)
    }
    
    // Загрузить иконку для категории
    func loadIcon(categoryId: String) -> String? {
        let icons = loadAllIcons()
        return icons[categoryId]
    }
    
    // Загрузить все иконки
    private func loadAllIcons() -> [String: String] {
        return userDefaults.dictionary(forKey: iconsKey) as? [String: String] ?? [:]
    }
    
    // Удалить иконку для категории
    func removeIcon(categoryId: String) {
        var icons = loadAllIcons()
        icons.removeValue(forKey: categoryId)
        userDefaults.set(icons, forKey: iconsKey)
    }
}

