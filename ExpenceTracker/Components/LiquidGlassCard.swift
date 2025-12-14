//
// LiquidGlassCard.swift
// Оптимизированный компонент карточки с liquid glass эффектом
//

import SwiftUI

/// Карточка с нативным liquid glass эффектом
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        content
            .padding()
            .background {
                Group {
                    if currentColorScheme == .light {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(red: 0.92, green: 0.92, blue: 0.94))
                    } else {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial.opacity(0.6))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: currentColorScheme == .light ? [
                                    Color(red: 0.8, green: 0.8, blue: 0.85).opacity(0.6),
                                    Color(red: 0.7, green: 0.7, blue: 0.75).opacity(0.4)
                                ] : [
                                    .white.opacity(0.15),
                                    .white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: currentColorScheme == .light ? 0.5 : 0.33
                        )
                }
            }
    }
}

/// Кнопка с нативным liquid glass эффектом и правильными hit areas
struct LiquidGlassButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Маленькая кнопка с liquid glass эффектом
struct LiquidGlassSmallButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Кнопка действия (лайк, комментарий) с liquid glass
struct LiquidGlassActionButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.15),
                                        .white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Расширение для применения glass button style
extension ButtonStyle where Self == LiquidGlassButton {
    static var liquidGlass: LiquidGlassButton {
        LiquidGlassButton()
    }
}

extension ButtonStyle where Self == LiquidGlassSmallButton {
    static var liquidGlassSmall: LiquidGlassSmallButton {
        LiquidGlassSmallButton()
    }
}

extension ButtonStyle where Self == LiquidGlassActionButton {
    static var liquidGlassAction: LiquidGlassActionButton {
        LiquidGlassActionButton()
    }
}
