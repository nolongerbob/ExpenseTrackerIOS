//
// ThemeManager.swift
// Управление темами приложения
//

import SwiftUI

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "Светлая"
        case .dark:
            return "Темная"
        case .system:
            return "Системная"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // nil означает использовать системную тему
        }
    }
}

struct AppColors {
    static func backgroundGradient(for colorScheme: ColorScheme?) -> LinearGradient {
        let scheme = colorScheme ?? .dark // По умолчанию темная
        if scheme == .light {
            return LinearGradient(
                colors: [Color(red: 0.97, green: 0.97, blue: 0.98), Color(red: 0.92, green: 0.92, blue: 0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    static func primaryText(for colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? .dark
        return scheme == .light ? .black : .white
    }
    
    static func secondaryText(for colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? .dark
        return scheme == .light ? Color(red: 0.3, green: 0.3, blue: 0.35) : .secondary
    }
    
    static func cardBackground(for colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? .dark
        return scheme == .light ? Color(red: 0.95, green: 0.95, blue: 0.97) : Color.white.opacity(0.1)
    }
    
    static func textFieldBackground(for colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? .dark
        return scheme == .light ? Color(red: 0.96, green: 0.96, blue: 0.98) : Color.white.opacity(0.1)
    }
    
    static func textFieldText(for colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? .dark
        return scheme == .light ? .black : .white
    }
    
    static func cardBorder(for colorScheme: ColorScheme?) -> Color {
        let scheme = colorScheme ?? .dark
        return scheme == .light ? Color(red: 0.85, green: 0.85, blue: 0.9) : Color.white.opacity(0.15)
    }
}

