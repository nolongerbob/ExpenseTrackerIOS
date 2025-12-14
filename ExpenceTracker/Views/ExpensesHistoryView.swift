//
// ExpensesHistoryView.swift
// Экран истории расходов с фильтрами и диаграммами
//

import SwiftUI

struct ExpensesHistoryView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @State private var selectedCategory: Category?
    @State private var selectedPeriod: PeriodFilter
    @State private var showFilters = false
    @State private var transactionType: TransactionType
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showDatePicker = false
    
    init(
        transactionType: TransactionType = .expenses,
        selectedPeriod: PeriodFilter = .all,
        selectedCategory: Category? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        let calendar = Calendar.current
        let now = Date()
        
        // Если передан период "месяц", устанавливаем даты текущего месяца
        let monthStartDate: Date
        let monthEndDate: Date
        if selectedPeriod == .month {
            monthStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            monthEndDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStartDate) ?? now
        } else {
            monthStartDate = startDate ?? calendar.date(byAdding: .month, value: -1, to: now) ?? now
            monthEndDate = endDate ?? now
        }
        
        _transactionType = State(initialValue: transactionType)
        _selectedPeriod = State(initialValue: selectedPeriod)
        _selectedCategory = State(initialValue: selectedCategory)
        _startDate = State(initialValue: monthStartDate)
        _endDate = State(initialValue: monthEndDate)
    }
    
    enum TransactionType: String, CaseIterable {
        case expenses = "Расходы"
        case income = "Доходы"
    }
    
    enum PeriodFilter: String, CaseIterable {
        case all = "Все время"
        case today = "Сегодня"
        case week = "Неделя"
        case month = "Месяц"
        case year = "Год"
        case custom = "Выбрать даты"
    }
    
    var filteredExpenses: [Expense] {
        var expenses = modelData.expenses
        
        // Фильтр по типу транзакции
        let targetType = transactionType == .expenses ? Expense.ExpenseType.expense : Expense.ExpenseType.income
        expenses = expenses.filter { $0.type == targetType }
        
        // Фильтр по категории
        if let category = selectedCategory {
            expenses = expenses.filter { $0.category.id == category.id }
        }
        
        // Фильтр по периоду
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .all:
            break
        case .today:
            expenses = expenses.filter { calendar.isDateInToday($0.date) }
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            expenses = expenses.filter { $0.date >= weekAgo }
        case .month:
            // Фильтр по текущему месяцу
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) ?? now
            expenses = expenses.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            expenses = expenses.filter { $0.date >= yearAgo }
        case .custom:
            expenses = expenses.filter { $0.date >= startDate && $0.date <= endDate }
        }
        
        // Сортируем по дате по убыванию (новые сверху), затем по apiId (cuid содержит timestamp)
        // CUID содержит timestamp в начале, поэтому лексикографическая сортировка даст правильный порядок
        return expenses.sorted { expense1, expense2 in
            // Сначала по дате (более новые даты сверху)
            if expense1.date != expense2.date {
                return expense1.date > expense2.date
            }
            // Если даты одинаковые, сортируем по apiId в обратном порядке (cuid содержит timestamp)
            // Более новые cuid будут иметь больший timestamp в начале строки
            return expense1.apiId > expense2.apiId
        }
    }
    
    var totalFiltered: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var categoryChartData: [(category: Category, total: Double, percentage: Double)] {
        let totals = Dictionary(grouping: filteredExpenses, by: { $0.category.id })
            .mapValues { expenses in
                expenses.reduce(0) { $0 + $1.amount }
            }
        
        return totals.compactMap { (categoryId, total) in
            guard let category = modelData.categories.first(where: { $0.id == categoryId }) else {
                return nil
            }
            let percentage = totalFiltered > 0 ? (total / totalFiltered) * 100 : 0
            return (category, total, percentage)
        }
        .sorted { $0.total > $1.total }
    }
    
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
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Переключатель Расходы/Доходы
                        Picker("Тип транзакций", selection: $transactionType) {
                            ForEach(TransactionType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Фильтры
                        LiquidGlassCard {
                            VStack(spacing: 8) {
                                // Период
                                HStack {
                                    Text("Период")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Picker("Период", selection: $selectedPeriod) {
                                        ForEach(PeriodFilter.allCases, id: \.self) { period in
                                            Text(period.rawValue).tag(period)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.blue)
                                }
                                
                                // Выбор дат (если выбран custom)
                                if selectedPeriod == .custom {
                                    Divider()
                                    
                                    VStack(spacing: 8) {
                                        DatePicker("От", selection: $startDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .tint(.blue)
                                        
                                        DatePicker("До", selection: $endDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .tint(.blue)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                }
                                
                                Divider()
                                
                                // Категория
                                HStack {
                                    Text("Категория")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Picker("Категория", selection: $selectedCategory) {
                                        Text("Все категории").tag(nil as Category?)
                                        ForEach(modelData.categories, id: \.id) { category in
                                            HStack {
                                                Circle()
                                                    .fill(category.color)
                                                    .frame(width: 12, height: 12)
                                                Text(category.name)
                                            }
                                            .tag(category as Category?)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.blue)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .padding(.horizontal)
                        
                        // Статистика
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(transactionType == .expenses ? "Всего расходов" : "Всего доходов")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    if selectedPeriod == .custom {
                                        Text("\(startDate, style: .date) - \(endDate, style: .date)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Text(formatCurrency(totalFiltered))
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(transactionType == .expenses ? .red : .green)
                                
                                HStack {
                                    Text("\(filteredExpenses.count) операций")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    if !categoryChartData.isEmpty {
                                        Text("\(categoryChartData.count) категорий")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        
                        // Круговая диаграмма
                        if !filteredExpenses.isEmpty && !categoryChartData.isEmpty {
                            LiquidGlassCard {
                                VStack(spacing: 20) {
                                    HStack {
                                        Text("Распределение расходов")
                                            .font(.headline)
                                            .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                        
                                        Spacer()
                                        
                                        NavigationLink(destination: CategoriesView()) {
                                            Text("Все категории")
                                                .font(.subheadline)
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    
                                    PieChartView(data: categoryChartData)
                                        .frame(height: 250)
                                    
                                    // Легенда
                                    VStack(spacing: 12) {
                                        ForEach(categoryChartData.prefix(5), id: \.category.id) { item in
                                            NavigationLink(destination: CategoryExpensesView(category: item.category)) {
                                                HStack(spacing: 12) {
                                                    Circle()
                                                        .fill(item.category.color)
                                                        .frame(width: 12, height: 12)
                                                    
                                                    Text(item.category.name)
                                                        .font(.subheadline)
                                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                                    
                                                    Spacer()
                                                    
                                                    Text(formatCurrency(item.total))
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                                    
                                                    Text("\(item.percentage, specifier: "%.0f")%")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: 40, alignment: .trailing)
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .padding(.horizontal)
                        }
                        
                        
                        // Список расходов
                        if filteredExpenses.isEmpty {
                            LiquidGlassCard {
                                VStack(spacing: 16) {
                                    Image(systemName: transactionType == .expenses ? "tray" : "arrow.down.circle")
                                        .font(.system(size: 64))
                                        .foregroundStyle(.secondary)
                                    Text(transactionType == .expenses ? "Нет расходов" : "Нет доходов")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                    Text("Измените фильтры для просмотра данных")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 40)
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("История \(transactionType == .expenses ? "расходов" : "доходов")")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                    .padding(.horizontal)
                                
                                ForEach(filteredExpenses) { expense in
                                    ExpenseHistoryRow(expense: expense, transactionType: transactionType) {
                                        Task {
                                            await refreshData()
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationTitle("История")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(currentColorScheme, for: .navigationBar)
        }
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount)) ₽"
    }
    
    func refreshData() async {
        do {
            let expensesData = try await APIService.shared.getExpenses()
            let categoriesData = try await APIService.shared.getCategories()
            
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
            print("Error refreshing data: \(error)")
        }
    }
}

// Компонент строки расхода для истории (как в AllExpensesView)
struct ExpenseHistoryRow: View {
    let expense: Expense
    let transactionType: ExpensesHistoryView.TransactionType
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
                        Text(transactionType == .expenses ? "-\(formatCurrency(expense.amount))" : "+\(formatCurrency(expense.amount))")
                            .font(.headline)
                            .foregroundStyle(transactionType == .expenses ? .red : .green)
                        
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
        .confirmationDialog("Удалить \(transactionType == .expenses ? "расход" : "доход")?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
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

