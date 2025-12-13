//
// CategoriesView.swift
// Экран категорий с liquid glass эффектом
//

import SwiftUI

struct CategoriesView: View {
    @Environment(ExpenseModelData.self) private var modelData
    
    var totalSum: Double {
        modelData.expenses.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    var categoryTotals: [(category: Category, total: Double, count: Int, percentage: Double)] {
        modelData.categories.map { category in
            let expenses = modelData.expenses.filter { $0.category.id == category.id && $0.type == .expense }
            let total = expenses.reduce(0) { $0 + $1.amount }
            let percentage = totalSum > 0 ? (total / totalSum) * 100 : 0
            return (category, total, expenses.count, percentage)
        }
        .sorted { $0.total > $1.total }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if categoryTotals.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        Text("Нет категорий")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(categoryTotals, id: \.category.id) { item in
                                NavigationLink(destination: CategoryExpensesView(category: item.category)) {
                                    LiquidGlassCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                Circle()
                                                    .fill(item.category.color)
                                                    .frame(width: 16, height: 16)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(item.category.name)
                                                        .font(.headline)
                                                        .foregroundStyle(.white)
                                                    
                                                    Text("\(item.count) операций")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Text(formatCurrency(item.total))
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                            }
                                            
                                            // Прогресс-бар
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(Color.white.opacity(0.1))
                                                        .frame(height: 8)
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(item.category.color)
                                                        .frame(width: geometry.size.width * (item.percentage / 100), height: 8)
                                                }
                                            }
                                            .frame(height: 8)
                                            
                                            HStack {
                                                Spacer()
                                                Text("\(item.percentage, specifier: "%.1f")%")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await refreshData()
                    }
                }
            }
            .navigationTitle("Расходы по категориям")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear {
                Task {
                    await refreshData()
                }
            }
        }
    }
    
    func refreshData() async {
        do {
            async let expenses = APIService.shared.getExpenses()
            async let categories = APIService.shared.getCategories()
            
            let (expensesData, categoriesData) = try await (expenses, categories)
            
            await MainActor.run {
                modelData.expenses = expensesData.map { expense in
                    Expense(
                        id: UUID(uuidString: expense.id) ?? UUID(),
                        apiId: expense.id,
                        amount: Double(expense.amount) ?? 0,
                        category: expense.category.map { cat in
                            let icon = CategoryIconStorage.shared.loadIcon(categoryId: cat.id) ?? "tag.fill"
                            return Category(
                                id: cat.id,
                                name: cat.name,
                                color: Color(hex: cat.color) ?? .blue,
                                icon: icon,
                                type: Expense.ExpenseType.fromAPI(cat.type)
                            )
                        } ?? Category(id: "none", name: "Без категории", color: .gray, icon: "tag.fill", type: .expense),
                        note: expense.note,
                        date: ISO8601DateFormatter().date(from: expense.spentAt) ?? Date(),
                        type: Expense.ExpenseType.fromAPI(expense.type)
                    )
                }
                
                modelData.categories = categoriesData.map { cat in
                    Category(
                        id: cat.id,
                        name: cat.name,
                        color: Color(hex: cat.color) ?? .blue,
                        icon: "tag.fill",
                        type: Expense.ExpenseType.fromAPI(cat.type)
                    )
                }
            }
        } catch {
            print("Error refreshing categories: \(error)")
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

