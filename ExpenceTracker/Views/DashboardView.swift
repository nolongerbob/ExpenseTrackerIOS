//
// DashboardView.swift
// Экран обзора расходов с liquid glass эффектом
//

import SwiftUI

struct DashboardView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showAllExpenses = false
    @State private var isRefreshing = false
    
    // Фильтр по текущему месяцу
    var currentMonthExpenses: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return modelData.expenses.filter { expense in
            expense.type == .expense && expense.date >= startOfMonth && expense.date <= endOfMonth
        }
    }
    
    var totalExpenses: Double {
        currentMonthExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var currentMonthIncome: [Expense] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return modelData.expenses.filter { expense in
            expense.type == .income && expense.date >= startOfMonth && expense.date <= endOfMonth
        }
    }
    
    var totalIncome: Double {
        currentMonthIncome.reduce(0) { $0 + $1.amount }
    }
    
    var incomeCount: Int {
        currentMonthIncome.count
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
                    LazyVStack(spacing: 20) {
                        // Приветствие
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(greeting)
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                if let profile = modelData.profile {
                                    Text(profile.name)
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                } else {
                                    ProgressView()
                                        .tint(AppColors.primaryText(for: currentColorScheme))
                                }
                            }
                            
                            Spacer()
                            
                            // Круг с фото профиля
                            NavigationLink(destination: ProfileView()) {
                                Group {
                                    if let avatar = modelData.profile?.avatar, !avatar.isEmpty,
                                       let avatarURL = URL(string: APIService.shared.getImageURL(avatar)) {
                                        AsyncImage(url: avatarURL) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.blue, .purple],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .overlay {
                                                    Text(String(modelData.profile?.name.prefix(1) ?? "П").uppercased())
                                                        .font(.system(size: 20, weight: .bold))
                                                        .foregroundStyle(.white)
                                                }
                                        }
                                        .frame(width: 70, height: 70)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [.blue, .purple],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 70, height: 70)
                                            .overlay {
                                                Text(String(modelData.profile?.name.prefix(1) ?? "П").uppercased())
                                                    .font(.system(size: 28, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Карточка общей статистики с liquid glass
                        NavigationLink(destination: ExpensesHistoryView(transactionType: .expenses, selectedPeriod: .month)) {
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Всего расходов")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 4) {
                                            Text("за месяц")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Text(formatCurrency(totalExpenses))
                                        .font(.system(size: 42, weight: .bold))
                                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                    
                                    Text("\(currentMonthExpenses.count) операций")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        
                        // Блок доходов (меньше по размеру)
                        NavigationLink(destination: ExpensesHistoryView(transactionType: .income, selectedPeriod: .month)) {
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Всего доходов")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        HStack(spacing: 4) {
                                            Text("за месяц")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Text(formatCurrency(totalIncome))
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(.green)
                                    
                                    Text("\(incomeCount) операций")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                        
                        // Круговая диаграмма расходов по категориям
                        if !currentMonthExpenses.isEmpty && !categoryChartData.isEmpty {
                            NavigationLink(destination: CategoriesView()) {
                                LiquidGlassCard {
                                    VStack(spacing: 16) {
                                        HStack {
                                            Text("Распределение расходов")
                                                .font(.headline)
                                                .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                            
                                            Spacer()
                                            
                                            HStack(spacing: 4) {
                                                Text("за месяц")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        
                                        // Горизонтальное расположение: диаграмма слева, легенда справа
                                        HStack(alignment: .top, spacing: 20) {
                                            // Круговая диаграмма
                                            PieChartView(data: categoryChartData)
                                                .frame(width: 200, height: 200)
                                            
                                            // Легенда справа
                                            VStack(alignment: .leading, spacing: 12) {
                                                ForEach(categoryChartData.prefix(5), id: \.category.id) { item in
                                                    HStack(spacing: 12) {
                                                        Circle()
                                                            .fill(item.category.color)
                                                            .frame(width: 12, height: 12)
                                                        
                                                        Text(item.category.name)
                                                            .font(.subheadline)
                                                            .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                                            .lineLimit(1)
                                                        
                                                        Spacer()
                                                        
                                                        Text("\(item.percentage, specifier: "%.0f")%")
                                                            .font(.subheadline)
                                                            .fontWeight(.semibold)
                                                            .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await refreshData()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Обзор")
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                }
            }
        }
    }
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 {
            return "Доброе утро"
        } else if hour >= 12 && hour < 17 {
            return "Добрый день"
        } else if hour >= 17 && hour < 22 {
            return "Добрый вечер"
        } else {
            return "Доброй ночи"
        }
    }
    
    var categoryChartData: [(category: Category, total: Double, percentage: Double)] {
        guard totalExpenses > 0, !currentMonthExpenses.isEmpty, !modelData.categories.isEmpty else {
            return []
        }
        
        let totals = Dictionary(grouping: currentMonthExpenses, by: { $0.category.id })
            .mapValues { expenses in
                expenses.reduce(0) { $0 + $1.amount }
            }
        
        let result = totals.compactMap { (categoryId, total) -> (category: Category, total: Double, percentage: Double)? in
            guard total > 0 else { return nil }
            guard let category = modelData.categories.first(where: { $0.id == categoryId }) else {
                return nil
            }
            let percentage = (total / totalExpenses) * 100
            return (category, total, percentage)
        }
        .sorted { $0.total > $1.total }
        
        return result
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
                        } ?? Category(id: "none", name: "Без категории", color: .gray, icon: "tag.fill", type: Expense.ExpenseType.fromAPI(expense.type)),
                        note: expense.note,
                        date: APIService.parseDate(expense.spentAt) ?? Date(),
                        type: Expense.ExpenseType.fromAPI(expense.type)
                    )
                }
                
                modelData.categories = categoriesData.map { cat in
                    let icon = CategoryIconStorage.shared.loadIcon(categoryId: cat.id) ?? "tag.fill"
                    return Category(
                        id: cat.id,
                        name: cat.name,
                        color: Color(hex: cat.color) ?? .blue,
                        icon: icon,
                        type: Expense.ExpenseType.fromAPI(cat.type)
                    )
                }
            }
        } catch {
            print("Error refreshing data: \(error)")
        }
    }
}

// Круговая диаграмма
struct PieChartDataItem: Identifiable {
    let id: String
    let category: Category
    let total: Double
    let percentage: Double
    let index: Int
}

struct PieChartView: View {
    let data: [(category: Category, total: Double, percentage: Double)]
    @AppStorage("colorScheme") private var colorScheme: String = "system"
    @Environment(\.colorScheme) private var systemColorScheme
    
    private var currentColorScheme: ColorScheme? {
        let theme = AppTheme(rawValue: colorScheme) ?? .system
        return theme.colorScheme ?? systemColorScheme
    }
    
    private var chartItems: [PieChartDataItem] {
        data.enumerated().map { index, item in
            PieChartDataItem(
                id: item.category.id,
                category: item.category,
                total: item.total,
                percentage: item.percentage,
                index: index
            )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            if data.isEmpty {
                // Показываем пустое состояние
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Нет данных")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let radius = min(geometry.size.width, geometry.size.height) / 2 - 20
                let innerRadius = radius * 0.75 // Большой внутренний радиус как в Apple Watch
                let items = chartItems
                
                ZStack {
                    ForEach(items, id: \.id) { item in
                        let startAngle = angleForIndex(item.index)
                        let endAngle = item.index < data.count - 1 
                            ? angleForIndex(item.index + 1)
                            : Angle(degrees: -90 + 360)
                        
                        PieSliceShape(
                            startAngle: startAngle,
                            endAngle: endAngle,
                            innerRadius: innerRadius,
                            outerRadius: radius
                        )
                        .fill(item.category.color)
                        .overlay {
                            PieSliceShape(
                                startAngle: startAngle,
                                endAngle: endAngle,
                                innerRadius: innerRadius,
                                outerRadius: radius
                            )
                            .stroke(.white.opacity(0.15), lineWidth: 3)
                        }
                    }
                    
                    // Центральный круг с общей суммой
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: innerRadius * 2, height: innerRadius * 2)
                        .overlay {
                            VStack(spacing: 4) {
                                Text("Всего")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatTotal())
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(AppColors.primaryText(for: currentColorScheme))
                            }
                        }
                }
            }
        }
    }
    
    private func angleForIndex(_ index: Int) -> Angle {
        guard !data.isEmpty else { return Angle(degrees: 0) }
        
        // Если индекс равен количеству элементов, возвращаем полный круг
        if index >= data.count {
            return Angle(degrees: -90 + 360) // Начинаем сверху и делаем полный круг
        }
        
        var currentAngle: Double = -90 // Начинаем сверху
        
        // Проценты уже в диапазоне 0-100, поэтому просто умножаем на 3.6 (360/100)
        for i in 0..<index {
            if i < data.count {
                currentAngle += data[i].percentage * 3.6
            }
        }
        
        return Angle(degrees: currentAngle)
    }
    
    private func formatTotal() -> String {
        let total = data.reduce(0) { $0 + $1.total }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RUB"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: total)) ?? "\(Int(total)) ₽"
    }
}

struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let gap: CGFloat = 3 // Зазор между сегментами в градусах
        
        var path = Path()
        
        // Внутренняя дуга с учетом зазора
        let innerStart = startAngle + Angle(degrees: Double(gap / 2))
        let innerEnd = endAngle - Angle(degrees: Double(gap / 2))
        
        // Внешняя дуга с учетом зазора
        let outerStart = startAngle + Angle(degrees: Double(gap / 2))
        let outerEnd = endAngle - Angle(degrees: Double(gap / 2))
        
        // Конвертируем углы в радианы
        let innerStartRad = innerStart.radiansValue
        let outerEndRad = outerEnd.radiansValue
        
        // Начинаем с внутренней точки
        let innerStartPoint = CGPoint(
            x: center.x + innerRadius * cos(innerStartRad),
            y: center.y + innerRadius * sin(innerStartRad)
        )
        path.move(to: innerStartPoint)
        
        // Внутренняя дуга
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: innerStart,
            endAngle: innerEnd,
            clockwise: false
        )
        
        // Линия к внешней дуге с закруглением
        let outerEndPoint = CGPoint(
            x: center.x + outerRadius * cos(outerEndRad),
            y: center.y + outerRadius * sin(outerEndRad)
        )
        
        // Добавляем закругление на внешнем крае
        let controlPoint1 = CGPoint(
            x: center.x + outerRadius * 0.98 * cos(outerEndRad),
            y: center.y + outerRadius * 0.98 * sin(outerEndRad)
        )
        path.addQuadCurve(to: outerEndPoint, control: controlPoint1)
        
        // Внешняя дуга
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: outerEnd,
            endAngle: outerStart,
            clockwise: true
        )
        
        // Закругляем обратно к внутренней дуге
        let controlPoint2 = CGPoint(
            x: center.x + innerRadius * 1.02 * cos(innerStartRad),
            y: center.y + innerRadius * 1.02 * sin(innerStartRad)
        )
        path.addQuadCurve(to: innerStartPoint, control: controlPoint2)
        
        path.closeSubpath()
        
        return path
    }
}

extension Angle {
    var radiansValue: CGFloat {
        CGFloat(self.radians)
    }
}

