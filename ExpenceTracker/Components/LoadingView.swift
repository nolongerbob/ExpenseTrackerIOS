//
// LoadingView.swift
// Красивый загрузчик с анимацией денег и финансовыми советами
//

import SwiftUI

struct LoadingView: View {
    @State private var currentTipIndex = 0
    @State private var rotationAngle: Double = 0
    @State private var coinOffsets: [CGSize] = []
    @State private var coinOpacities: [Double] = []
    
    private let tips = [
        "💡 Ведите учет всех расходов - это поможет увидеть, куда уходят деньги",
        "💰 Откладывайте 10-20% от дохода на сбережения каждый месяц",
        "📊 Анализируйте свои траты раз в неделю, чтобы найти возможности для экономии",
        "🎯 Ставьте финансовые цели - это мотивирует экономить",
        "💳 Избегайте импульсивных покупок - подождите день перед крупной тратой",
        "📱 Используйте приложение для отслеживания расходов - это дисциплинирует",
        "🏦 Создайте резервный фонд на 3-6 месяцев расходов",
        "📈 Инвестируйте в свое образование - это лучшая инвестиция",
        "🛒 Составляйте список покупок перед походом в магазин",
        "⏰ Планируйте крупные покупки заранее, чтобы найти лучшие предложения",
        "💼 Разделяйте деньги на категории: обязательные расходы, развлечения, сбережения",
        "📉 Следите за подписками - отменяйте неиспользуемые сервисы",
        "🎁 Покупайте подарки заранее, чтобы избежать переплат",
        "🍽️ Готовьте дома чаще - это экономит деньги и полезнее для здоровья",
        "🚗 Используйте общественный транспорт или велосипед вместо такси",
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Анимация денег
                ZStack {
                    // Центральная монета
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow.opacity(0.9), .orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .overlay {
                            Text("₽")
                                .font(.system(size: 60, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: .yellow.opacity(0.5), radius: 20)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    // Вращающиеся монеты вокруг
                    ForEach(0..<8, id: \.self) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.7), .orange.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 45, height: 45)
                            .overlay {
                                Text("₽")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.95))
                            }
                            .shadow(color: .yellow.opacity(0.3), radius: 8)
                            .offset(coinOffsets[safe: index] ?? .zero)
                            .opacity(coinOpacities[safe: index] ?? 1.0)
                            .rotationEffect(.degrees(rotationAngle * Double(index + 1) * 0.3))
                            .scaleEffect(coinOpacities[safe: index] ?? 1.0)
                    }
                }
                .frame(height: 300)
                
                // Финансовый совет
                LiquidGlassCard {
                    VStack(spacing: 12) {
                        Text("💡 Совет дня")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Text(tips[currentTipIndex])
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .frame(minHeight: 60)
                    }
                    .padding()
                }
                .padding(.horizontal, 40)
                
                // Индикатор загрузки
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.yellow)
                    .scaleEffect(1.5)
                
                Spacer()
            }
        }
        .onAppear {
            setupCoinAnimation()
            startAnimations()
        }
    }
    
    private func setupCoinAnimation() {
        // Инициализируем позиции монет по кругу
        coinOffsets = (0..<8).map { index in
            let angle = Double(index) * (2 * .pi / 8)
            let radius: CGFloat = 100
            return CGSize(
                width: cos(angle) * radius,
                height: sin(angle) * radius
            )
        }
        coinOpacities = Array(repeating: 1.0, count: 8)
    }
    
    private func startAnimations() {
        // Анимация вращения центральной монеты
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // Анимация пульсации монет
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 1.5)) {
                        coinOpacities = coinOpacities.map { _ in Double.random(in: 0.7...1.0) }
                    }
                }
            }
        }
        
        // Смена советов каждые 4 секунды
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentTipIndex = (currentTipIndex + 1) % tips.count
                }
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

