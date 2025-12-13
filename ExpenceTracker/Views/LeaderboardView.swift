//
// LeaderboardView.swift
// Экран лидерборда с liquid glass эффектом
//

import SwiftUI

struct LeaderboardView: View {
    @Environment(ExpenseModelData.self) private var modelData
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if modelData.leaderboard.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "trophy")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        Text("Нет данных")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(modelData.leaderboard.enumerated()), id: \.element.id) { index, entry in
                                LiquidGlassCard {
                                    HStack(spacing: 16) {
                                        // Место с медалью для топ-3
                                        ZStack {
                                            Circle()
                                                .fill(index < 3 ? Color.yellow.opacity(0.3) : Color.blue.opacity(0.3))
                                                .frame(width: 50, height: 50)
                                            
                                            if index < 3 {
                                                Text(medalEmoji(for: index))
                                                    .font(.system(size: 28))
                                            } else {
                                                Text("\(index + 1)")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            
                                            Text("Расходы: \(formatCurrency(entry.total))")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await refreshLeaderboard()
                    }
                }
            }
            .navigationTitle("Лидерборд экономии")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear {
                Task {
                    await refreshLeaderboard()
                }
            }
        }
    }
    
    func refreshLeaderboard() async {
        do {
            let leaderboardData = try await APIService.shared.getLeaderboard()
            
            await MainActor.run {
                modelData.leaderboard = leaderboardData.map { entry in
                    LeaderboardEntry(
                        userId: UUID(uuidString: entry.userId) ?? UUID(),
                        name: entry.name,
                        total: Double(entry.total) ?? 0
                    )
                }
            }
        } catch {
            print("Error loading leaderboard: \(error)")
            // Если эндпоинт не существует, просто оставляем пустой список
            await MainActor.run {
                modelData.leaderboard = []
            }
        }
    }
    
    func medalEmoji(for index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return ""
        }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₽"
    }
}

