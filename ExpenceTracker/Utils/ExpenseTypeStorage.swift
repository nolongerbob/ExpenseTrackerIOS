//
// ExpenseTypeStorage.swift
// Утилита для локального хранения типа транзакции (расход/доход)
//

import Foundation

class ExpenseTypeStorage {
    static let shared = ExpenseTypeStorage()
    private let userDefaults = UserDefaults.standard
    private let typesKey = "expenseTypes"
    
    private init() {}
    
    // Сохранить тип для транзакции
    func saveType(expenseId: String, type: Expense.ExpenseType) {
        var types = loadAllTypes()
        types[expenseId] = type.rawValue
        userDefaults.set(types, forKey: typesKey)
    }
    
    // Загрузить тип для транзакции
    func loadType(expenseId: String) -> Expense.ExpenseType? {
        let types = loadAllTypes()
        guard let typeString = types[expenseId],
              let type = Expense.ExpenseType(rawValue: typeString) else {
            return nil
        }
        return type
    }
    
    // Загрузить все типы
    private func loadAllTypes() -> [String: String] {
        return userDefaults.dictionary(forKey: typesKey) as? [String: String] ?? [:]
    }
    
    // Удалить тип для транзакции
    func removeType(expenseId: String) {
        var types = loadAllTypes()
        types.removeValue(forKey: expenseId)
        userDefaults.set(types, forKey: typesKey)
    }
}


