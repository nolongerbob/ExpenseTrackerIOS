//
// AddExpenseView.swift
// Экран добавления расхода с liquid glass эффектом
//

import SwiftUI
import UIKit

struct AddExpenseView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @Environment(\.dismiss) private var dismiss
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var transactionType: TransactionType = .expense
    @State private var amount: String = ""
    @State private var selectedCategory: Category?
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryColor: Color = .blue
    @State private var newCategoryIcon = "tag.fill"
    @State private var isLoading = false
    @State private var isCreatingCategory = false
    @State private var errorMessage: String?
    @State private var showSuccessBanner = false
    
    enum TransactionType: String, CaseIterable {
        case expense = "Расход"
        case income = "Доход"
    }
    
    private let colorPalette: [Color] = [
        .blue, .green, .purple, .orange, .red, .pink, .cyan, .indigo, .mint, .teal
    ]
    
    private let iconOptions = [
        "fork.knife", "car.fill", "gamecontroller.fill", "bag.fill",
        "house.fill", "heart.fill", "star.fill", "book.fill", "music.note", "camera.fill"
    ]
    
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
                                HStack {
                                    Text("Категория")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Button {
                                        withAnimation {
                                            showAddCategory.toggle()
                                        }
                                    } label: {
                                        Image(systemName: showAddCategory ? "minus.circle.fill" : "plus.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(LiquidGlassSmallButton())
                                }
                                
                                if showAddCategory {
                                    // Форма создания категории
                                    VStack(spacing: 12) {
                                        TextField("Название категории", text: $newCategoryName)
                                            .textFieldStyle(.plain)
                                            .padding(12)
                                            .background(AppColors.textFieldBackground(for: currentColorScheme))
                                            .cornerRadius(8)
                                            .foregroundStyle(AppColors.textFieldText(for: currentColorScheme))
                                            .onSubmit {
                                                hideKeyboard()
                                            }
                                        
                                        // Выбор цвета
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(colorPalette, id: \.self) { color in
                                                    Button {
                                                        newCategoryColor = color
                                                    } label: {
                                                        Circle()
                                                            .fill(color)
                                                            .frame(width: 36, height: 36)
                                                            .overlay {
                                                                if newCategoryColor == color {
                                                                    Circle()
                                                                        .strokeBorder(.white, lineWidth: 3)
                                                                }
                                                            }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Выбор иконки
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 12) {
                                                ForEach(iconOptions, id: \.self) { icon in
                                                    Button {
                                                        newCategoryIcon = icon
                                                    } label: {
                                                        Image(systemName: icon)
                                                            .font(.title3)
                                                            .foregroundStyle(newCategoryIcon == icon ? .white : .secondary)
                                                            .padding(12)
                                                            .background {
                                                                RoundedRectangle(cornerRadius: 8)
                                                                    .fill(newCategoryIcon == icon ? newCategoryColor : Color.white.opacity(0.1))
                                                            }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Button {
                                            Task {
                                                await createCategory()
                                            }
                                        } label: {
                                            if isCreatingCategory {
                                                ProgressView()
                                                    .progressViewStyle(.circular)
                                                    .tint(.white)
                                            } else {
                                                Text("Создать")
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .buttonStyle(LiquidGlassButton())
                                        .disabled(newCategoryName.isEmpty || isCreatingCategory)
                                        .opacity(newCategoryName.isEmpty || isCreatingCategory ? 0.5 : 1.0)
                                        
                                        Button {
                                            withAnimation {
                                                showAddCategory = false
                                                newCategoryName = ""
                                                newCategoryColor = .blue
                                                newCategoryIcon = "tag.fill"
                                            }
                                        } label: {
                                            Text("Отмена")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(LiquidGlassSmallButton())
                                    }
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
                                                } onDelete: {
                                                    Task {
                                                        await deleteCategory(category)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Дата
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Дата")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                DatePicker("Дата", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .tint(.blue)
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
                                    .foregroundStyle(.white)
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
            .navigationTitle(transactionType == .expense ? "Добавить расход" : "Добавить доход")
            .navigationBarTitleDisplayMode(.large)
            .overlay(alignment: .bottom) {
                if showSuccessBanner {
                    SuccessBanner(transactionType: transactionType)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1000)
                }
            }
            .animation(.spring(response: 0.3), value: showSuccessBanner)
        }
    }
    
    func saveExpense() async {
        guard let amountValue = Double(amount),
              let category = selectedCategory else { return }
        
        isLoading = true
        errorMessage = nil
        hideKeyboard()
        
        do {
            // Получаем ID категории
            let categoryId = category.id
            
            // Создаем транзакцию через API
            let expenseType = transactionType == .expense ? "EXPENSE" : "INCOME"
            _ = try await APIService.shared.createExpense(
                amount: amountValue,
                categoryId: categoryId,
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
                
                // Сброс формы
                amount = ""
                selectedCategory = nil
                note = ""
                date = Date()
                
                // Показываем баннер успеха
                showSuccessBanner = true
                isLoading = false
            }
            
            // Скрываем баннер через 2 секунды
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                withAnimation {
                    showSuccessBanner = false
                }
            }
            
            // Закрываем экран через еще 0.3 секунды (после анимации скрытия)
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
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
    
    func createCategory() async {
        guard !newCategoryName.isEmpty else { return }
        
        isCreatingCategory = true
        errorMessage = nil
        
        do {
            // Конвертируем Color в hex строку
            let hexColor = colorToHex(newCategoryColor)
            
            let categoryType = transactionType == .expense ? "EXPENSE" : "INCOME"
            let categoryResponse = try await APIService.shared.createCategory(
                name: newCategoryName,
                color: hexColor,
                type: categoryType
            )
            
            // Обновляем список категорий из API
            let updatedCategories = try await APIService.shared.getCategories()
            
            await MainActor.run {
                // Сохраняем иконку для новой категории локально
                CategoryIconStorage.shared.saveIcon(categoryId: categoryResponse.id, icon: newCategoryIcon)
                
                // Обновляем все категории из API
                modelData.categories = updatedCategories.map { cat in
                    // Загружаем сохраненную иконку или используем дефолтную
                    let icon = CategoryIconStorage.shared.loadIcon(categoryId: cat.id) ?? "tag.fill"
                    return Category(
                        id: cat.id,
                        name: cat.name,
                        color: Color(hex: cat.color) ?? .blue,
                        icon: icon,
                        type: Expense.ExpenseType.fromAPI(cat.type)
                    )
                }
                
                // Находим только что созданную категорию и выбираем её
                if let newCategory = modelData.categories.first(where: { $0.id == categoryResponse.id }) {
                    selectedCategory = newCategory
                }
                
                // Сброс формы создания категории
                withAnimation {
                    showAddCategory = false
                    newCategoryName = ""
                    newCategoryColor = .blue
                    newCategoryIcon = "tag.fill"
                }
                
                isCreatingCategory = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCreatingCategory = false
            }
        }
    }
    
    func colorToHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red*255)<<16 | (Int)(green*255)<<8 | (Int)(blue*255)<<0
        
        return String(format: "#%06x", rgb)
    }
    
    func deleteCategory(_ category: Category) async {
        print("=== deleteCategory called for category: \(category.name), ID: \(category.id) ===")
        do {
            print("Deleting category with ID: \(category.id)")
            try await APIService.shared.deleteCategory(id: category.id)
            print("Category deleted successfully")
            
            // Удаляем иконку категории из локального хранилища
            CategoryIconStorage.shared.removeIcon(categoryId: category.id)
            
            // Обновляем список категорий из API
            let updatedCategories = try await APIService.shared.getCategories()
            
            await MainActor.run {
                // Обновляем все категории из API
                modelData.categories = updatedCategories.map { cat in
                    let icon = CategoryIconStorage.shared.loadIcon(categoryId: cat.id) ?? "tag.fill"
                    return Category(
                        id: cat.id,
                        name: cat.name,
                        color: Color(hex: cat.color) ?? .blue,
                        icon: icon,
                        type: Expense.ExpenseType.fromAPI(cat.type)
                    )
                }
                
                // Если удаленная категория была выбрана, сбрасываем выбор
                if selectedCategory?.id == category.id {
                    selectedCategory = nil
                }
            }
        } catch {
            print("Error deleting category: \(error)")
            await MainActor.run {
                if let apiError = error as? APIError {
                    switch apiError {
                    case .serverError(let message):
                        errorMessage = "Ошибка сервера: \(message)"
                    default:
                        errorMessage = apiError.localizedDescription
                    }
                } else {
                    errorMessage = "Не удалось удалить категорию: \(error.localizedDescription)"
                }
            }
        }
    }
}

// Баннер успешного добавления расхода
struct SuccessBanner: View {
    let transactionType: AddExpenseView.TransactionType
    
    var body: some View {
        LiquidGlassCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text(transactionType == .expense ? "Расход успешно добавлен" : "Доход успешно добавлен")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

struct CategoryButton: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    let onDelete: (() -> Void)?
    @State private var showDeleteConfirmation = false
    
    init(category: Category, isSelected: Bool, action: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.category = category
        self.isSelected = isSelected
        self.action = action
        self.onDelete = onDelete
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : category.color)
                
                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .padding()
            .frame(width: 100)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(category.color, lineWidth: isSelected ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.5) {
            if onDelete != nil {
                showDeleteConfirmation = true
            }
        }
        .confirmationDialog("Удалить категорию?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                print("=== Delete button pressed in confirmation dialog ===")
                onDelete?()
            }
            Button("Отмена", role: .cancel) {
                print("=== Cancel button pressed ===")
            }
        } message: {
            Text("Категория \"\(category.name)\" будет удалена. Все расходы с этой категорией останутся без категории.")
        }
        .onChange(of: showDeleteConfirmation) { oldValue, newValue in
            print("=== showDeleteConfirmation changed: \(oldValue) -> \(newValue) ===")
        }
    }
}

