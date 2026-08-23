import Foundation
import SwiftData

@Observable
final class IncomeEditorViewModel {
    var year: Int
    var month: Int
    var amountText: String
    var errorMessage: String?

    private let editingEntry: IncomeEntry?

    init(entry: IncomeEntry? = nil, defaultYear: Int? = nil, defaultMonth: Int? = nil) {
        let now = Date()
        let calendar = Calendar.current
        editingEntry = entry
        year = entry?.year ?? defaultYear ?? calendar.component(.year, from: now)
        month = entry?.month ?? defaultMonth ?? calendar.component(.month, from: now)
        amountText = entry.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? ""
    }

    var title: String { editingEntry == nil ? "Новый доход" : "Редактирование" }
    var canDelete: Bool { editingEntry != nil }

    @MainActor
    func save(in context: ModelContext, existingEntries: [IncomeEntry]) -> Bool {
        let normalized = amountText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let amount = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), amount >= .zero else {
            errorMessage = "Введите корректную неотрицательную сумму"
            return false
        }

        let key = IncomeEntry.makePeriodKey(year: year, month: month)
        let matchingEntries = existingEntries.filter { $0.periodKey == key }
        let target = editingEntry ?? matchingEntries.max { $0.updatedAt < $1.updatedAt }

        if let editingEntry,
           existingEntries.contains(where: { $0 !== editingEntry && $0.periodKey == key }) {
            errorMessage = "За выбранный месяц уже есть запись. Откройте её из списка месяцев."
            return false
        }

        if let target {
            target.year = year
            target.month = month
            target.periodKey = key
            target.amount = amount
            target.updatedAt = .now
            matchingEntries
                .filter { $0 !== target }
                .forEach(context.delete)
        } else {
            context.insert(IncomeEntry(year: year, month: month, amount: amount))
        }

        do {
            try context.save()
            return true
        } catch {
            errorMessage = "Не удалось сохранить доход. Попробуйте ещё раз."
            return false
        }
    }

    @MainActor
    func delete(in context: ModelContext) -> Bool {
        guard let editingEntry else { return false }
        context.delete(editingEntry)
        do {
            try context.save()
            return true
        } catch {
            errorMessage = "Не удалось удалить запись."
            return false
        }
    }
}
