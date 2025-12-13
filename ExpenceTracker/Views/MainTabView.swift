//
// MainTabView.swift
// Главный TabView с нативным liquid glass эффектом
//

import SwiftUI

struct MainTabView: View {
    @Environment(ExpenseModelData.self) private var modelData
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Обзор", systemImage: "chart.pie.fill")
                }
            
            ExpensesHistoryView()
                .tabItem {
                    Label("История", systemImage: "clock.fill")
                }
            
            AddExpenseView()
                .tabItem {
                    Label("Добавить", systemImage: "plus.circle.fill")
                }
            
            NotesView()
                .tabItem {
                    Label("Заметки", systemImage: "note.text")
                }
            
            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person.fill")
                }
        }
        .tint(.blue)
    }
}

