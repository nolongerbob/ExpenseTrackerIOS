//
// OnboardingView.swift
// Красивая страница приветствия с обучением
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showLogin = false
    @State private var showRegister = false
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "chart.pie.fill",
            title: "Отслеживайте расходы",
            description: "Ведите учет всех ваших трат и доходов в одном месте. Анализируйте свои финансы с помощью красивых графиков и статистики."
        ),
        OnboardingPage(
            icon: "tag.fill",
            title: "Категории и бюджеты",
            description: "Создавайте категории для удобной организации расходов. Устанавливайте бюджеты и следите за их выполнением."
        ),
        OnboardingPage(
            icon: "bell.fill",
            title: "Напоминания",
            description: "Не забывайте о важных платежах. Устанавливайте напоминания для регулярных трат и получайте уведомления вовремя."
        ),
        OnboardingPage(
            icon: "person.2.fill",
            title: "Социальные функции",
            description: "Делитесь своими достижениями с друзьями, сравнивайте расходы и участвуйте в соревнованиях по экономии."
        )
    ]
    
    var totalPages: Int {
        pages.count + 1 // +1 для финального слайда
    }
    
    var body: some View {
        ZStack {
            AppColors.backgroundGradient(for: currentColorScheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Индикатор страниц
                TabView(selection: $currentPage) {
                    // Слайды обучения
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                    
                    // Финальный слайд с кнопками входа
                    WelcomePageView(
                        showLogin: $showLogin,
                        showRegister: $showRegister,
                        onComplete: {
                            hasCompletedOnboarding = true
                        }
                    )
                    .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(maxHeight: .infinity)
                
                // Дополнительный отступ снизу для индикаторов
                Spacer()
                    .frame(height: 0)
                
                // Кнопка "Пропустить" (всегда видна, но только на первых страницах активна)
                HStack {
                    Spacer()
                    Button("Пропустить") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage = pages.count
                        }
                    }
                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme).opacity(currentPage < pages.count - 1 ? 0.7 : 0))
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                    .disabled(currentPage >= pages.count - 1)
                }
            }
        }
        .sheet(isPresented: $showLogin) {
            NavigationStack {
                LoginView()
            }
        }
        .sheet(isPresented: $showRegister) {
            NavigationStack {
                RegisterView()
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Иконка с фиксированной высотой
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.8, blue: 0.0),
                                Color(red: 1.0, green: 0.6, blue: 0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.5), radius: 30)
                
                Image(systemName: page.icon)
                    .font(.system(size: 80, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 200)
            }
            .frame(height: 200)
            .padding(.bottom, 20)
            
            // Заголовок
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .frame(minHeight: 80)
            
            // Описание
            Text(page.description)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(AppColors.secondaryText(for: currentColorScheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .frame(minHeight: 100)
            
            Spacer()
        }
        .padding(.vertical, 60)
    }
}

struct WelcomePageView: View {
    @Binding var showLogin: Bool
    @Binding var showRegister: Bool
    let onComplete: () -> Void
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showButton = false
    @State private var showAuthMethods = false
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Логотип/Иконка (уменьшенный размер)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.8, blue: 0.0),
                                    Color(red: 1.0, green: 0.6, blue: 0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                        .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.5), radius: 20)
                    
                    Text("₽")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 40)
                
                // Заголовок
                Text("Добро пожаловать!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Описание
                Text("Начните управлять своими финансами уже сегодня")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppColors.secondaryText(for: currentColorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                
                if !showAuthMethods {
                    // Кнопка "Начать" с плавным появлением
                    Button {
                        withAnimation(.easeOut(duration: 0.4)) {
                            showAuthMethods = true
                        }
                    } label: {
                        Text("Начать")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.8, blue: 0.0),
                                        Color(red: 1.0, green: 0.6, blue: 0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 20)
                } else {
                    // Кнопки входа (появляются после нажатия "Начать")
                    VStack(spacing: 12) {
                        // Основная кнопка "Войти"
                        Button {
                            showLogin = true
                        } label: {
                            Text("Войти")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.8, blue: 0.0),
                                            Color(red: 1.0, green: 0.6, blue: 0.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: Color(red: 1.0, green: 0.8, blue: 0.0).opacity(0.4), radius: 10, x: 0, y: 5)
                        }
                        .buttonStyle(.plain)
                        
                        // Кнопка "Зарегистрироваться"
                        Button {
                            showRegister = true
                        } label: {
                            Text("Зарегистрироваться")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            AppColors.cardBorder(for: currentColorScheme),
                                            lineWidth: 2
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    
                    // Разделитель
                    HStack(spacing: 16) {
                        Rectangle()
                            .fill(AppColors.cardBorder(for: currentColorScheme))
                            .frame(height: 1)
                        
                        Text("или")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText(for: currentColorScheme))
                        
                        Rectangle()
                            .fill(AppColors.cardBorder(for: currentColorScheme))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)
                    .transition(.opacity)
                    
                    // Социальные кнопки
                    VStack(spacing: 10) {
                        // Apple
                        SocialButton(
                            icon: "apple.logo",
                            text: "Продолжить с Apple",
                            backgroundColor: currentColorScheme == .light ? .black : .white,
                            textColor: currentColorScheme == .light ? .white : .black
                        ) {
                            // TODO: Реализовать вход через Apple
                            print("Apple Sign In")
                        }
                        
                        // Google
                        SocialButton(
                            icon: "globe",
                            text: "Продолжить с Google",
                            backgroundColor: AppColors.cardBackground(for: currentColorScheme),
                            textColor: AppColors.primaryText(for: currentColorScheme),
                            showBorder: true
                        ) {
                            // TODO: Реализовать вход через Google
                            print("Google Sign In")
                        }
                        
                        // X (Twitter)
                        SocialButton(
                            icon: "xmark",
                            text: "Продолжить с X",
                            backgroundColor: AppColors.cardBackground(for: currentColorScheme),
                            textColor: AppColors.primaryText(for: currentColorScheme),
                            showBorder: true
                        ) {
                            // TODO: Реализовать вход через X
                            print("X Sign In")
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 80)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            // Плавное появление кнопки "Начать" через 0.3 секунды
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showButton = true
                }
            }
        }
        .onDisappear {
            // Сбрасываем состояние при исчезновении
            showButton = false
            showAuthMethods = false
        }
    }
}

struct SocialButton: View {
    let icon: String
    let text: String
    let backgroundColor: Color
    let textColor: Color
    var showBorder: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(textColor)
                
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .cornerRadius(16)
            .overlay {
                if showBorder {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            AppColors.cardBorder(for: nil),
                            lineWidth: 1
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }
}

