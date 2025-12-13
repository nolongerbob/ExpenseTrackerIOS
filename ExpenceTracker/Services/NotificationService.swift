//
// NotificationService.swift
// Сервис для управления локальными уведомлениями
//

import Foundation
import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    
    private init() {}
    
    // Запрос разрешения на уведомления
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    // Проверка статуса разрешения
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }
    
    // Запланировать уведомление для заметки
    func scheduleNotification(for note: Note) {
        guard let reminderDate = note.reminderDate else {
            print("NotificationService: Cannot schedule notification - no reminderDate for note \(note.id)")
            return
        }
        
        guard reminderDate > Date() else {
            print("NotificationService: Cannot schedule notification - reminderDate \(reminderDate) is in the past for note \(note.id)")
            return
        }
        
        print("NotificationService: Scheduling notification for note '\(note.title)' (id: \(note.id)) at \(reminderDate)")
        
        let content = UNMutableNotificationContent()
        content.title = note.title
        content.body = note.content ?? "Напоминание"
        content.sound = .default
        content.badge = 1
        
        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: note.id,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("NotificationService: Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("NotificationService: ✅ Notification successfully scheduled for note '\(note.title)' (id: \(note.id)) at \(reminderDate)")
            }
        }
    }
    
    // Отменить уведомление для заметки
    func cancelNotification(for noteId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [noteId])
        print("Notification cancelled for note: \(noteId)")
    }
    
    // Обновить уведомление для заметки
    func updateNotification(for note: Note) {
        // Сначала отменяем старое уведомление
        cancelNotification(for: note.id)
        
        // Затем создаем новое, если есть напоминание
        if let reminderDate = note.reminderDate, reminderDate > Date() {
            scheduleNotification(for: note)
        }
    }
    
    // Отменить все уведомления для массива заметок
    func cancelNotifications(for notes: [Note]) {
        let identifiers = notes.map { $0.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // Запланировать все уведомления для массива заметок
    func scheduleNotifications(for notes: [Note]) {
        for note in notes {
            if let reminderDate = note.reminderDate, reminderDate > Date() {
                scheduleNotification(for: note)
            }
        }
    }
}

