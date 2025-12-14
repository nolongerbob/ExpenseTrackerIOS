//
// AllExpensesView.swift
// Экран просмотра всех расходов с возможностью удаления
//

import SwiftUI

struct AllExpensesView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient(for: currentColorScheme)
                    .ignoresSafeArea()
                
                if modelData.expenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        Text("Нет расходов")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(modelData.expenses.sorted(by: { $0.date > $1.date })) { expense in
                                ExpenseRow(expense: expense) {
                                    Task {
                                        await refreshExpenses()
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshExpenses()
                    }
                }
            }
            .navigationTitle("Все расходы")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
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
                        } ?? Category(id: "none", name: "Без категории", color: .gray, icon: "tag.fill", type: Expense.ExpenseType.fromAPI(expense.type)),
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
}

struct ExpenseRow: View {
    let expense: Expense
    let onDelete: () -> Void
    @Environment(ExpenseModelData.self) private var modelData
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showEditExpense = false
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        Button {
            showEditExpense = true
        } label: {
            LiquidGlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.note ?? "Без описания")
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                        
                        HStack(spacing: 8) {
                            Text(expense.category.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            Text(expense.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("-\(formatCurrency(expense.amount))")
                            .font(.headline)
                            .foregroundStyle(.red)
                        
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.red)
                            } else {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                        .disabled(isDeleting)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditExpense) {
            EditExpenseView(expense: expense)
        }
        .confirmationDialog("Удалить расход?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                Task {
                    await deleteExpense()
                }
            }
            Button("Отмена", role: .cancel) {}
        }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₽"
    }
    
    func deleteExpense() async {
        isDeleting = true
        
        do {
            try await APIService.shared.deleteExpense(id: expense.apiId)
            
            // Обновляем список расходов из API
            let updatedExpenses = try await APIService.shared.getExpenses()
            
            await MainActor.run {
                // Обновляем все расходы из API
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
                        } ?? Category(id: "none", name: "Без категории", color: .gray, icon: "tag.fill", type: Expense.ExpenseType.fromAPI(expense.type)),
                        note: expense.note,
                        date: APIService.parseDate(expense.spentAt) ?? Date(),
                        type: Expense.ExpenseType.fromAPI(expense.type)
                    )
                }
                onDelete()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                print("Error deleting expense: \(error)")
            }
        }
    }
}

