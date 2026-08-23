import Foundation
import SwiftData

@Model
final class IncomeEntry {
    var periodKey: String = ""
    var id: UUID = UUID()
    var year: Int = 0
    var month: Int = 0
    var amount: Decimal = Decimal.zero
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        year: Int,
        month: Int,
        amount: Decimal,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.periodKey = Self.makePeriodKey(year: year, month: month)
        self.id = id
        self.year = year
        self.month = month
        self.amount = amount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func makePeriodKey(year: Int, month: Int) -> String {
        String(format: "%04d-%02d", year, month)
    }
}
