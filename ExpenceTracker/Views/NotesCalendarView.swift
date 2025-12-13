//
// NotesCalendarView.swift
// Календарное представление заметок
//

import SwiftUI

struct NotesCalendarView: View {
    let notes: [Note]
    @Binding var selectedDate: Date?
    let onNoteTap: (Note) -> Void
    
    @State private var currentMonth = Date()
    
    private let calendar = Calendar.current
    
    init(notes: [Note], selectedDate: Binding<Date?>, onNoteTap: @escaping (Note) -> Void) {
        self.notes = notes
        self._selectedDate = selectedDate
        self.onNoteTap = onNoteTap
        // Инициализируем selectedDate если он nil
        if selectedDate.wrappedValue == nil {
            selectedDate.wrappedValue = Date()
        }
    }
    
    // Кэш для дат с заметками (вычисляется один раз) - используем noteDate
    private var datesWithNotes: Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        var dates = Set<String>()
        dates.reserveCapacity(notes.count)
        
        for note in notes {
            // Пропускаем заметки без даты (noteDate == createdAt)
            let timeDiff = abs(note.noteDate.timeIntervalSince(note.createdAt))
            if timeDiff < 60 {
                // Это заметка без даты, не показываем в календаре
                continue
            }
            let dateString = formatter.string(from: note.noteDate)
            dates.insert(dateString)
            print("Calendar: Added note date '\(dateString)' for note '\(note.title)' (noteDate: \(note.noteDate))")
        }
        print("Calendar: Total dates with notes: \(dates.count), dates: \(dates)")
        return dates
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок с навигацией по месяцам
            HStack {
                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button {
                    withAnimation {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal)
            
            // Календарь
            calendarGrid
            
            // Заметки на выбранную дату
            if let selectedDate = selectedDate, !notesForSelectedDate.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Заметки на \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    
                    ForEach(notesForSelectedDate) { note in
                        Button {
                            onNoteTap(note)
                        } label: {
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(note.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        if note.reminderDate != nil {
                                            Image(systemName: "bell.fill")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    
                                    if let content = note.content, !content.isEmpty {
                                        Text(content)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    
                                    if let reminderDate = note.reminderDate {
                                        Label(reminderDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Нет заметок на эту дату")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 40)
            }
        }
    }
    
    var calendarGrid: some View {
        VStack(spacing: 8) {
            // Дни недели
            HStack(spacing: 0) {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Дни месяца
            let days = daysInMonth
            let weeksCount = max(1, (days.count + 6) / 7)
            ForEach(0..<weeksCount, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { day in
                        let dayIndex = week * 7 + day
                        if dayIndex < days.count {
                            let dayInfo = days[dayIndex]
                            DayView(
                                day: dayInfo.day,
                                isToday: dayInfo.isToday,
                                isSelected: calendar.isDate(dayInfo.date, inSameDayAs: selectedDate ?? Date()),
                                hasNotes: dayInfo.hasNotes,
                                isCurrentMonth: dayInfo.isCurrentMonth
                            ) {
                                selectedDate = dayInfo.date
                            }
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    var daysInMonth: [(day: Int, date: Date, isToday: Bool, isSelected: Bool, hasNotes: Bool, isCurrentMonth: Bool)] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let firstDayOfMonth = monthInterval.start
        guard let firstWeekday = calendar.dateComponents([.weekday], from: firstDayOfMonth).weekday else {
            return []
        }
        
        // Начинаем с понедельника (weekday 2)
        let firstWeekdayAdjusted = (firstWeekday + 5) % 7
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)?.count ?? 0
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)?.count ?? 0
        
        var result: [(day: Int, date: Date, isToday: Bool, isSelected: Bool, hasNotes: Bool, isCurrentMonth: Bool)] = []
        
        // Кэшируем даты с заметками для быстрой проверки (используем noteDate, а не createdAt)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let datesWithNotesSet = datesWithNotes
        
        // Дни предыдущего месяца
        let startDay = daysInPreviousMonth - firstWeekdayAdjusted + 1
        let endDay = daysInPreviousMonth
        
        if startDay <= endDay && startDay > 0 {
            for i in startDay...endDay {
                if let date = calendar.date(byAdding: .day, value: i - daysInPreviousMonth, to: firstDayOfMonth) {
                    let dateString = formatter.string(from: date)
                    let hasNotes = datesWithNotesSet.contains(dateString)
                    if hasNotes {
                        print("Calendar: Day \(i) (previous month) has notes: \(dateString)")
                    }
                    result.append((
                        day: i,
                        date: date,
                        isToday: calendar.isDateInToday(date),
                        isSelected: false,
                        hasNotes: hasNotes,
                        isCurrentMonth: false
                    ))
                }
            }
        }
        
        // Дни текущего месяца
        if daysInMonth > 0 {
            for day in 1...daysInMonth {
                if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                    let dateString = formatter.string(from: date)
                    let hasNotes = datesWithNotesSet.contains(dateString)
                    if hasNotes {
                        print("Calendar: Day \(day) (current month) has notes: \(dateString)")
                    }
                    result.append((
                        day: day,
                        date: date,
                        isToday: calendar.isDateInToday(date),
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date()),
                        hasNotes: hasNotes,
                        isCurrentMonth: true
                    ))
                }
            }
        }
        
        // Дни следующего месяца для заполнения сетки
        let remainingDays = max(0, 42 - result.count)
        if remainingDays > 0, let lastDayOfMonth = calendar.date(byAdding: .day, value: daysInMonth - 1, to: firstDayOfMonth) {
            for day in 1...remainingDays {
                if let date = calendar.date(byAdding: .day, value: day, to: lastDayOfMonth) {
                    let dateString = formatter.string(from: date)
                    let hasNotes = datesWithNotesSet.contains(dateString)
                    result.append((
                        day: day,
                        date: date,
                        isToday: calendar.isDateInToday(date),
                        isSelected: false,
                        hasNotes: hasNotes,
                        isCurrentMonth: false
                    ))
                }
            }
        }
        
        return result
    }
    
    var notesForSelectedDate: [Note] {
        guard let selectedDate = selectedDate else { return [] }
        
        // Показываем заметки только если их noteDate совпадает с выбранной датой
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let selectedDateString = formatter.string(from: selectedDate)
        print("Calendar: Selected date: \(selectedDate) -> '\(selectedDateString)'")
        
        let filteredNotes = notes.filter { note in
            let noteDateString = formatter.string(from: note.noteDate)
            let matches = noteDateString == selectedDateString
            if matches {
                print("Calendar: Match found - Note '\(note.title)' noteDate: \(note.noteDate) -> '\(noteDateString)'")
            }
            return matches
        }
        print("Calendar: Found \(filteredNotes.count) notes for selected date")
        return filteredNotes
    }
}

struct DayView: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let hasNotes: Bool
    let isCurrentMonth: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.3) : Color.clear))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                
                VStack(spacing: 2) {
                    Text("\(day)")
                        .font(.system(size: 14, weight: isToday ? .bold : .regular))
                        .foregroundStyle(
                            isSelected ? .white :
                            (isToday ? .blue :
                            (isCurrentMonth ? .white : .secondary))
                        )
                    
                    if hasNotes {
                        Circle()
                            .fill(isSelected ? .white : .blue)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

