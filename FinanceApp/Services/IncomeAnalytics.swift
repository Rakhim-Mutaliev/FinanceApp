import Foundation

enum IncomeAnalytics {
    static func total(_ entries: [IncomeEntry]) -> Decimal {
        entries.reduce(Decimal.zero) { $0 + $1.amount }
    }

    static func average(_ entries: [IncomeEntry]) -> Decimal {
        guard !entries.isEmpty else { return .zero }
        return total(entries) / Decimal(entries.count)
    }

    static func percentageChange(current: Decimal, previous: Decimal?) -> Double? {
        guard let previous, previous != .zero else { return nil }
        let value = ((current - previous) / previous) * 100
        return NSDecimalNumber(decimal: value).doubleValue.isFinite
            ? NSDecimalNumber(decimal: value).doubleValue
            : nil
    }

    static func bestMonth(in entries: [IncomeEntry]) -> IncomeEntry? {
        entries.max { lhs, rhs in
            if lhs.amount == rhs.amount { return lhs.month > rhs.month }
            return lhs.amount < rhs.amount
        }
    }

    static func entries(for year: Int, in entries: [IncomeEntry]) -> [IncomeEntry] {
        let grouped = Dictionary(grouping: entries.filter { $0.year == year && (1...12).contains($0.month) }) {
            $0.periodKey
        }
        return grouped.values
            .compactMap { duplicates in duplicates.max { $0.updatedAt < $1.updatedAt } }
            .sorted { $0.month < $1.month }
    }

    static func yearStatistic(
        for year: Int,
        entries: [IncomeEntry],
        currentYear: Int = Calendar.current.component(.year, from: .now)
    ) -> YearStatistic {
        let yearEntries = self.entries(for: year, in: entries)
        let endMonth = year == currentYear ? (yearEntries.map(\.month).max() ?? 0) : 12
        let currentComparable = yearEntries.filter { endMonth == 0 || $0.month <= endMonth }
        let previousEntries = self.entries(for: year - 1, in: entries)
            .filter { endMonth == 0 || $0.month <= endMonth }
        let previousTotal: Decimal? = previousEntries.isEmpty ? nil : total(previousEntries)

        return YearStatistic(
            year: year,
            total: total(yearEntries),
            average: average(yearEntries),
            change: percentageChange(current: total(currentComparable), previous: previousTotal),
            bestMonth: bestMonth(in: yearEntries),
            filledMonthCount: yearEntries.count,
            comparisonEndMonth: endMonth
        )
    }

    static func yearStatistics(
        from entries: [IncomeEntry],
        currentYear: Int = Calendar.current.component(.year, from: .now)
    ) -> [YearStatistic] {
        Set(entries.map(\.year))
            .sorted()
            .map { yearStatistic(for: $0, entries: entries, currentYear: currentYear) }
    }

    static func monthStatistics(for year: Int, entries: [IncomeEntry]) -> [MonthStatistic] {
        let values = Dictionary(uniqueKeysWithValues: self.entries(for: year, in: entries).map { ($0.month, $0.amount) })

        return (1...12).map { month in
            let amount = values[month]
            let change: Double?
            if let amount, month > 1, let previous = values[month - 1] {
                change = percentageChange(current: amount, previous: previous)
            } else {
                change = nil
            }
            return MonthStatistic(month: month, amount: amount, change: change)
        }
    }
}
