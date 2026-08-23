import Foundation

struct MonthStatistic: Identifiable, Equatable {
    var id: Int { month }
    let month: Int
    let amount: Decimal?
    let change: Double?
}

struct YearStatistic: Identifiable, Equatable {
    var id: Int { year }
    let year: Int
    let total: Decimal
    let average: Decimal
    let change: Double?
    let bestMonth: IncomeEntry?
    let filledMonthCount: Int
    let comparisonEndMonth: Int
}
