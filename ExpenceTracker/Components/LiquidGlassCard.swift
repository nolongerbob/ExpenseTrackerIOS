//
// LiquidGlassCard.swift
// Компонент карточки с нативным liquid glass эффектом
// Использует SwiftUI .glassEffect() как в примере Landmarks
//

import SwiftUI

/// Карточка с нативным liquid glass эффектом
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background {
                // Нативный liquid glass эффект как в SwiftUI
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .overlay {
                        // Тонкая граница согласно Apple HIG
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.15),
                                        .white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.33
                            )
                    }
            }
            // Применяем нативный glass effect
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

/// Кнопка с нативным liquid glass эффектом
struct LiquidGlassButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

/// Расширение для применения glass button style
extension ButtonStyle where Self == LiquidGlassButton {
    static var liquidGlass: LiquidGlassButton {
        LiquidGlassButton()
    }
}

/// Расширение для применения glass effect
extension View {
    func liquidGlassCard() -> some View {
        self
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: 15))
    }
}

