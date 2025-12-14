//
// EditExpenseView.swift
// Экран редактирования расхода
//

import SwiftUI
import UIKit

struct EditExpenseView: View {
    let expense: Expense
    @Environment(ExpenseModelData.self) private var modelData
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var transactionType: TransactionType
    @State private var amount: String
    @State private var selectedCategory: Category?
    @State private var note: String
    @State private var date: Date
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    enum TransactionType: String, CaseIterable {
        case expense = "Расход"
        case income = "Доход"
    }
    
    init(expense: Expense) {
        self.expense = expense
        _transactionType = State(initialValue: expense.type == .expense ? .expense : .income)
        _amount = State(initialValue: String(format: "%.0f", expense.amount))
        _note = State(initialValue: expense.note ?? "")
        _date = State(initialValue: expense.date)
    }
    
    var filteredCategories: [Category] {
        let targetType: Expense.ExpenseType = transactionType == .expense ? .expense : .income
        return modelData.categories.filter { $0.type == targetType }
    }
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient(for: currentColorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Переключатель Расход/Доход
                        LiquidGlassCard {
                            Picker("Тип транзакции", selection: $transactionType) {
                                ForEach(TransactionType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 4)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Поле суммы
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Сумма")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("0", text: $amount)
                                    .font(.system(size: 48, weight: .bold))
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(AppColors.textFieldText(for: currentColorScheme))
                                    .padding(12)
                                    .background(AppColors.textFieldBackground(for: currentColorScheme))
                                    .cornerRadius(12)
                                    .contentShape(Rectangle())
                                    .frame(minHeight: 60)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Выбор категории
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Категория")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                if filteredCategories.isEmpty {
                                    Text("Нет категорий")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(filteredCategories) { category in
                                                CategoryButton(
                                                    category: category,
                                                    isSelected: selectedCategory?.id == category.id
                                                ) {
                                                    selectedCategory = category
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .onAppear {
                            // Устанавливаем выбранную категорию при появлении
                            selectedCategory = expense.category
                        }
                        
                        // Дата
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Дата")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                DatePicker("Дата", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                            }
                        }
                        .padding(.horizontal)
                        
                        // Заметка
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Заметка")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Добавить заметку", text: $note, axis: .vertical)
                                    .foregroundStyle(AppColors.textFieldText(for: currentColorScheme))
                                    .onSubmit {
                                        hideKeyboard()
                                    }
                            }
                        }
                        .padding(.horizontal)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        
                        // Кнопка сохранения
                        Button {
                            Task {
                                await saveExpense()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(AppColors.primaryText(for: currentColorScheme))
                            } else {
                                Text("Сохранить")
                                    .font(.headline)
                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                            }
                        }
                        .buttonStyle(LiquidGlassButton())
                        .padding(.horizontal)
                        .disabled(isLoading || amount.isEmpty || selectedCategory == nil)
                        .opacity(isLoading || amount.isEmpty || selectedCategory == nil ? 0.5 : 1.0)
                    }
                    .padding(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Редактировать \(transactionType == .expense ? "расход" : "доход")")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                    .buttonStyle(.plain)
                    .font(.system(size: 17, weight: .regular))
                }
            }
        }
    }
    
    func saveExpense() async {
        guard let amountValue = Double(amount),
              let category = selectedCategory else { return }
        
        isLoading = true
        errorMessage = nil
        hideKeyboard()
        
        do {
            let expenseType = transactionType == .expense ? "EXPENSE" : "INCOME"
            _ = try await APIService.shared.updateExpense(
                id: expense.apiId,
                amount: amountValue,
                categoryId: category.id,
                note: note.isEmpty ? nil : note,
                type: expenseType,
                spentAt: date
            )
            
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
                
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


