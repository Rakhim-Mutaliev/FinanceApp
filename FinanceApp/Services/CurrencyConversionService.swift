import Foundation
import SwiftData

enum CurrencyConversionService {
    static func convertedAmount(_ amount: Decimal, targetToSourceRate rate: Decimal) -> Decimal? {
        guard rate > .zero else { return nil }
        return amount / rate
    }

    @MainActor
    static func convertAll(
        _ entries: [IncomeEntry],
        targetToSourceRate rate: Decimal,
        in context: ModelContext
    ) throws {
        guard rate > .zero else { throw CurrencyConversionError.invalidRate }
        let updateDate = Date.now
        for entry in entries {
            guard let converted = convertedAmount(entry.amount, targetToSourceRate: rate) else {
                throw CurrencyConversionError.invalidRate
            }
            entry.amount = converted
            entry.updatedAt = updateDate
        }
        try context.save()
    }
}

enum CurrencyConversionError: LocalizedError {
    case invalidRate

    var errorDescription: String? {
        "Курс должен быть больше нуля"
    }
}
