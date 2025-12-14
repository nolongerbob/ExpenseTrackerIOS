//
// CategoryExpensesView.swift
// Экран просмотра расходов по конкретной категории
//

import SwiftUI

struct CategoryExpensesView: View {
    let category: Category
    @Environment(ExpenseModelData.self) private var modelData
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var categoryExpenses: [Expense] {
        modelData.expenses.filter { $0.category.id == category.id && $0.type == .expense }
            .sorted(by: { $0.date > $1.date })
    }
    
    var categoryTotal: Double {
        categoryExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient(for: currentColorScheme)
                    .ignoresSafeArea()
                
                if categoryExpenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: category.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(category.color)
                        Text("Нет расходов в этой категории")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Карточка общей статистики
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Всего по категории")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(formatCurrency(categoryTotal))
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                    
                                    Text("Количество операций: \(categoryExpenses.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal)
                            
                            // Список расходов
                            LazyVStack(spacing: 12) {
                                ForEach(categoryExpenses) { expense in
                                    ExpenseRow(expense: expense) {
                                        Task {
                                            await deleteExpense(expense)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await refreshExpenses()
                    }
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(currentColorScheme, for: .navigationBar)
        }
    }
    
    func refreshExpenses() async {
        do {
            let expensesData = try await APIService.shared.getExpenses()
            
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
                        date: APIService.parseDate(expense.spentAt) ?? Date(),
                        type: Expense.ExpenseType.fromAPI(expense.type)
                    )
                }
            }
        } catch {
            print("Error refreshing expenses: \(error)")
        }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₽"
    }
    
    func deleteExpense(_ expense: Expense) async {
        do {
            try await APIService.shared.deleteExpense(id: expense.apiId)
            
            // Обновляем список расходов из API
            let updatedExpenses = try await APIService.shared.getExpenses()
            
            await MainActor.run {
                withAnimation {
                    modelData.expenses = updatedExpenses.map { expense in
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
                            date: APIService.parseDate(expense.spentAt) ?? Date(),
                            type: Expense.ExpenseType.fromAPI(expense.type)
                        )
                    }
                }
            }
        } catch {
            print("Error deleting expense: \(error)")
        }
    }
}

