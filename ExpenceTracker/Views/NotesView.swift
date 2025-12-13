//
// NotesView.swift
// Экран заметок с напоминаниями
//

import SwiftUI
import UserNotifications

struct NotesView: View {
    @Environment(ExpenseModelData.self) private var modelData
    @State private var showAddNote = false
    @State private var selectedNote: Note?
    @AppStorage("notificationPermissionRequested") private var notificationPermissionRequested = false
    @State private var viewMode: ViewMode = .list
    @State private var selectedDateForNewNote: Date? = nil
    
    enum ViewMode: String, CaseIterable {
        case list = "Список"
        case calendar = "Календарь"
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
                
                VStack(spacing: 0) {
                    // Переключатель Список/Календарь
                    Picker("Режим просмотра", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    if viewMode == .list {
                        listView
                    } else {
                        calendarView
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Заметки")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddNote = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(isPresented: $showAddNote) {
                AddNoteView(initialDate: selectedDateForNewNote) {
                    // Сбрасываем выбранную дату после создания заметки
                    selectedDateForNewNote = nil
                }
            }
            .sheet(item: $selectedNote) { note in
                EditNoteView(note: note)
            }
            .task {
                await requestNotificationPermission()
                await refreshData()
                await scheduleAllNotifications()
            }
        }
    }
    
    var listView: some View {
        Group {
            // Показываем заметки, у которых noteDate <= сегодня (или сегодняшние), или заметки без даты
            // Заметки без даты определяются как те, у которых noteDate == createdAt (с точностью до минуты)
            let today = Date()
            let visibleNotes = modelData.notes.filter { note in
                // Если дата заметки совпадает с датой создания (разница меньше минуты), считаем что дата не указана
                let timeDiff = abs(note.noteDate.timeIntervalSince(note.createdAt))
                let isNoDate = timeDiff < 60 // Разница меньше минуты
                if isNoDate {
                    return true // Заметки без даты всегда видны
                }
                // Иначе показываем только если дата уже наступила или сегодня
                return Calendar.current.isDate(note.noteDate, inSameDayAs: today) || note.noteDate < today
            }
            
            if visibleNotes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("Нет заметок")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Нажмите + чтобы создать заметку")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(visibleNotes.sorted(by: { $0.noteDate > $1.noteDate || ($0.noteDate == $1.noteDate && $0.createdAt > $1.createdAt) })) { note in
                            NoteCard(note: note) {
                                selectedNote = note
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await refreshData()
                }
            }
        }
    }
    
    var calendarView: some View {
        ScrollView {
            NotesCalendarView(
                notes: modelData.notes,
                selectedDate: $selectedDateForNewNote
            ) { note in
                selectedNote = note
            }
            .padding()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    func requestNotificationPermission() async {
        if !notificationPermissionRequested {
            let granted = await NotificationService.shared.requestAuthorization()
            await MainActor.run {
                notificationPermissionRequested = true
            }
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    func scheduleAllNotifications() async {
        // Планируем уведомления для всех заметок с напоминаниями
        print("📅 Scheduling notifications for \(modelData.notes.count) notes")
        for note in modelData.notes {
            if let reminderDate = note.reminderDate {
                print("  📌 Note '\(note.title)' has reminderDate: \(reminderDate)")
                if reminderDate > Date() {
                    NotificationService.shared.scheduleNotification(for: note)
                } else {
                    print("  ⏭️ Skipping note '\(note.title)' - reminderDate is in the past")
                }
            } else {
                print("  ⚠️ Note '\(note.title)' has no reminderDate")
            }
        }
    }
    
    func refreshData() async {
        do {
            let notesData = try await APIService.shared.getNotes()
            await MainActor.run {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                modelData.notes = notesData.map { note in
                    // Парсим noteDate с поддержкой разных форматов
                    var noteDate = formatter.date(from: note.noteDate)
                    if noteDate == nil {
                        let simpleFormatter = ISO8601DateFormatter()
                        noteDate = simpleFormatter.date(from: note.noteDate)
                    }
                    if noteDate == nil {
                        // Fallback: пытаемся распарсить как обычную дату
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                        noteDate = dateFormatter.date(from: note.noteDate)
                    }
                    let finalNoteDate = noteDate ?? Date()
                    
                    let reminderDate = note.reminderDate.flatMap { dateString in
                        formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
                    }
                    
                    print("Loaded note \(note.id): noteDate string='\(note.noteDate)', parsed=\(finalNoteDate)")
                    
                    return Note(
                        id: note.id,
                        title: note.title,
                        content: note.content,
                        noteDate: finalNoteDate,
                        reminderDate: reminderDate,
                        createdAt: ISO8601DateFormatter().date(from: note.createdAt) ?? Date(),
                        updatedAt: ISO8601DateFormatter().date(from: note.updatedAt) ?? Date()
                    )
                }
            }
        } catch {
            print("Error loading notes: \(error)")
        }
    }
}

struct NoteCard: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 12) {
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
                            .lineLimit(3)
                    }
                    
                    HStack {
                        if let reminderDate = note.reminderDate {
                            Label(reminderDate.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        Spacer()
                        
                        Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExpenseModelData.self) private var modelData
    let initialDate: Date?
    let onDismiss: () -> Void
    
    @State private var title = ""
    @State private var content = ""
    @State private var hasNoteDate = true
    @State private var noteDate = Date()
    @State private var reminderDate: Date?
    @State private var showReminderPicker = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(initialDate: Date? = nil, onDismiss: @escaping () -> Void = {}) {
        self.initialDate = initialDate
        self.onDismiss = onDismiss
        // Инициализируем noteDate с initialDate или сегодняшней датой
        _noteDate = State(initialValue: initialDate ?? Date())
        _hasNoteDate = State(initialValue: initialDate != nil)
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Название")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Введите название", text: $title)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal)
                        
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Содержание")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Введите текст заметки", text: $content, axis: .vertical)
                                    .foregroundStyle(.white)
                                    .lineLimit(5...10)
                            }
                        }
                        .padding(.horizontal)
                        
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Дата заметки")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $hasNoteDate)
                                }
                                
                                if hasNoteDate {
                                    DatePicker("Дата", selection: $noteDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .foregroundStyle(.white)
                                } else {
                                    Text("Заметка будет видна всегда в списке")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Напоминание")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { reminderDate != nil },
                                        set: { if $0 { reminderDate = Date().addingTimeInterval(3600) } else { reminderDate = nil } }
                                    ))
                                }
                                
                                if let reminderDate = reminderDate {
                                    DatePicker("Дата и время", selection: Binding(
                                        get: { reminderDate },
                                        set: { self.reminderDate = $0 }
                                    ), displayedComponents: [.date, .hourAndMinute])
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        
                        Button {
                            Task {
                                await saveNote()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Сохранить")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(title.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                        .disabled(title.isEmpty || isLoading)
                        .padding(.horizontal)
                    }
                    .padding(.top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Новая заметка")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
    
    func saveNote() async {
        guard !title.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let finalNoteDate = hasNoteDate ? noteDate : nil
            print("Creating note with hasNoteDate: \(hasNoteDate), noteDate: \(finalNoteDate?.description ?? "nil"), reminderDate: \(reminderDate?.description ?? "nil")")
            let createdNote = try await APIService.shared.createNote(
                title: title,
                content: content.isEmpty ? nil : content,
                noteDate: finalNoteDate,
                reminderDate: reminderDate
            )
            print("Created note: \(createdNote.id), reminderDate: \(createdNote.reminderDate ?? "nil")")
            
            let notesData = try await APIService.shared.getNotes()
            await MainActor.run {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                modelData.notes = notesData.map { note in
                    let noteDate = formatter.date(from: note.noteDate) ?? ISO8601DateFormatter().date(from: note.noteDate) ?? Date()
                    let reminderDate = note.reminderDate.flatMap { dateString in
                        formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
                    }
                    return Note(
                        id: note.id,
                        title: note.title,
                        content: note.content,
                        noteDate: noteDate,
                        reminderDate: reminderDate,
                        createdAt: ISO8601DateFormatter().date(from: note.createdAt) ?? Date(),
                        updatedAt: ISO8601DateFormatter().date(from: note.updatedAt) ?? Date()
                    )
                }
                
                // Планируем уведомление для новой заметки
                if let reminderDate = reminderDate, reminderDate > Date() {
                    if let newNote = modelData.notes.first(where: { $0.id == createdNote.id }) {
                        NotificationService.shared.scheduleNotification(for: newNote)
                        print("Scheduled notification for note: \(newNote.id) at \(reminderDate)")
                    }
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
}

struct EditNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExpenseModelData.self) private var modelData
    let note: Note
    @State private var title: String
    @State private var content: String
    @State private var hasNoteDate: Bool
    @State private var noteDate: Date
    @State private var reminderDate: Date?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    
    init(note: Note) {
        self.note = note
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content ?? "")
        // Определяем, есть ли у заметки дата (если noteDate != createdAt, значит дата указана)
        let timeDiff = abs(note.noteDate.timeIntervalSince(note.createdAt))
        let hasDate = timeDiff >= 60 // Разница больше минуты означает, что дата указана
        _hasNoteDate = State(initialValue: hasDate)
        _noteDate = State(initialValue: note.noteDate)
        _reminderDate = State(initialValue: note.reminderDate)
        print("EditNoteView init: note.id=\(note.id), noteDate=\(note.noteDate), hasNoteDate=\(hasDate), reminderDate=\(note.reminderDate?.description ?? "nil")")
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Название")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Введите название", text: $title)
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal)
                        
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Содержание")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                TextField("Введите текст заметки", text: $content, axis: .vertical)
                                    .foregroundStyle(.white)
                                    .lineLimit(5...10)
                            }
                        }
                        .padding(.horizontal)
                        
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Дата заметки")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $hasNoteDate)
                                }
                                
                                if hasNoteDate {
                                    DatePicker("Дата", selection: $noteDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .foregroundStyle(.white)
                                } else {
                                    Text("Заметка будет видна всегда в списке")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Напоминание")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { reminderDate != nil },
                                        set: { if $0 { reminderDate = Date().addingTimeInterval(3600) } else { reminderDate = nil } }
                                    ))
                                }
                                
                                if let reminderDate = reminderDate {
                                    DatePicker("Дата и время", selection: Binding(
                                        get: { reminderDate },
                                        set: { self.reminderDate = $0 }
                                    ), displayedComponents: [.date, .hourAndMinute])
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        
                        Button {
                            Task {
                                await saveNote()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Сохранить")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(title.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                        .disabled(title.isEmpty || isLoading)
                        .padding(.horizontal)
                        
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Удалить заметку")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding(.top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Редактировать заметку")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .confirmationDialog("Удалить заметку?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    Task {
                        await deleteNote()
                    }
                }
                Button("Отмена", role: .cancel) {}
            }
        }
    }
    
    func saveNote() async {
        guard !title.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let finalNoteDate = hasNoteDate ? noteDate : nil
            print("Updating note \(note.id) with hasNoteDate: \(hasNoteDate), noteDate: \(finalNoteDate?.description ?? "nil"), reminderDate: \(reminderDate?.description ?? "nil")")
            _ = try await APIService.shared.updateNote(
                id: note.id,
                title: title,
                content: content.isEmpty ? nil : content,
                noteDate: finalNoteDate,
                reminderDate: reminderDate as Date??
            )
            
            let notesData = try await APIService.shared.getNotes()
            await MainActor.run {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                modelData.notes = notesData.map { note in
                    let noteDate = formatter.date(from: note.noteDate) ?? ISO8601DateFormatter().date(from: note.noteDate) ?? Date()
                    let reminderDate = note.reminderDate.flatMap { dateString in
                        formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
                    }
                    return Note(
                        id: note.id,
                        title: note.title,
                        content: note.content,
                        noteDate: noteDate,
                        reminderDate: reminderDate,
                        createdAt: ISO8601DateFormatter().date(from: note.createdAt) ?? Date(),
                        updatedAt: ISO8601DateFormatter().date(from: note.updatedAt) ?? Date()
                    )
                }
                
                // Обновляем уведомление для измененной заметки
                if let updatedNote = modelData.notes.first(where: { $0.id == note.id }) {
                    NotificationService.shared.updateNotification(for: updatedNote)
                    if let reminderDate = updatedNote.reminderDate {
                        print("Updated notification for note: \(updatedNote.id) at \(reminderDate)")
                    } else {
                        print("Cancelled notification for note: \(updatedNote.id)")
                    }
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
    
    func deleteNote() async {
        isLoading = true
        
        do {
            try await APIService.shared.deleteNote(id: note.id)
            
            let notesData = try await APIService.shared.getNotes()
            await MainActor.run {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                modelData.notes = notesData.map { note in
                    let noteDate = formatter.date(from: note.noteDate) ?? ISO8601DateFormatter().date(from: note.noteDate) ?? Date()
                    let reminderDate = note.reminderDate.flatMap { dateString in
                        formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
                    }
                    return Note(
                        id: note.id,
                        title: note.title,
                        content: note.content,
                        noteDate: noteDate,
                        reminderDate: reminderDate,
                        createdAt: ISO8601DateFormatter().date(from: note.createdAt) ?? Date(),
                        updatedAt: ISO8601DateFormatter().date(from: note.updatedAt) ?? Date()
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
}

