import Foundation
import SwiftData
import Testing
@testable import FinanceApp

@Suite("Income analytics")
@MainActor
struct FinanceAppTests {
    @Test("Total and average use only recorded months")
    func totalAndAverage() {
        let entries = [entry(2026, 1, 100_000), entry(2026, 2, 0), entry(2026, 4, 200_000)]
        #expect(IncomeAnalytics.total(entries) == 300_000)
        #expect(IncomeAnalytics.average(entries) == 100_000)
    }

    @Test("Empty history returns safe values")
    func emptyHistory() {
        let statistic = IncomeAnalytics.yearStatistic(for: 2026, entries: [], currentYear: 2026)
        #expect(statistic.total == 0)
        #expect(statistic.average == 0)
        #expect(statistic.change == nil)
        #expect(statistic.bestMonth == nil)
    }

    @Test("Month-over-month increase and decrease")
    func monthlyChange() {
        let months = IncomeAnalytics.monthStatistics(
            for: 2026,
            entries: [entry(2026, 1, 100_000), entry(2026, 2, 110_000), entry(2026, 3, 105_000)]
        )
        #expect(months[0].change == nil)
        #expect(abs((months[1].change ?? 0) - 10) < 0.0001)
        #expect(abs((months[2].change ?? 0) - (-4.5454545)) < 0.0001)
    }

    @Test("Missing month and zero income remain distinct")
    func missingAndZero() {
        let months = IncomeAnalytics.monthStatistics(
            for: 2026,
            entries: [entry(2026, 1, 0), entry(2026, 3, 50_000)]
        )
        #expect(months[0].amount == 0)
        #expect(months[1].amount == nil)
        #expect(months[2].change == nil)
        #expect(IncomeAnalytics.percentageChange(current: 50_000, previous: 0) == nil)
    }

    @Test("Current year uses YTD comparison")
    func ytdComparison() {
        let entries = [
            entry(2025, 1, 100), entry(2025, 2, 100), entry(2025, 3, 9_999),
            entry(2026, 1, 150), entry(2026, 2, 150)
        ]
        let statistic = IncomeAnalytics.yearStatistic(for: 2026, entries: entries, currentYear: 2026)
        #expect(statistic.comparisonEndMonth == 2)
        #expect(abs((statistic.change ?? 0) - 50) < 0.0001)
    }

    @Test("Completed year uses full previous year")
    func completedYearComparison() {
        let entries = [entry(2024, 1, 100), entry(2024, 12, 100), entry(2025, 1, 300)]
        let statistic = IncomeAnalytics.yearStatistic(for: 2025, entries: entries, currentYear: 2026)
        #expect(abs((statistic.change ?? 0) - 50) < 0.0001)
    }

    @Test("First year has no comparison")
    func firstYear() {
        let statistic = IncomeAnalytics.yearStatistic(for: 2026, entries: [entry(2026, 1, 100)], currentYear: 2026)
        #expect(statistic.change == nil)
    }

    @Test("Best month is calculated from recorded values")
    func bestMonth() {
        let entries = [entry(2026, 1, 100), entry(2026, 2, 500), entry(2026, 3, 200)]
        #expect(IncomeAnalytics.bestMonth(in: entries)?.month == 2)
    }

    @Test("Large monetary values do not overflow")
    func largeValues() {
        let huge = Decimal(string: "999999999999999999.99")!
        let entries = [IncomeEntry(year: 2026, month: 1, amount: huge), IncomeEntry(year: 2026, month: 2, amount: huge)]
        #expect(IncomeAnalytics.total(entries) == huge * 2)
        #expect(IncomeAnalytics.average(entries) == huge)
    }

    @Test("Editing updates the existing model")
    func editEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let original = entry(2026, 1, 100)
        context.insert(original)
        try context.save()
        let editor = IncomeEditorViewModel(entry: original)
        editor.amountText = "250000"
        #expect(editor.save(in: context, existingEntries: [original]))
        #expect(original.amount == 250_000)
        #expect(try context.fetch(FetchDescriptor<IncomeEntry>()).count == 1)
    }

    @Test("Creating for an existing period performs upsert")
    func upsertEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let original = entry(2026, 4, 100)
        context.insert(original)
        try context.save()
        let editor = IncomeEditorViewModel(defaultYear: 2026, defaultMonth: 4)
        editor.amountText = "900"
        #expect(editor.save(in: context, existingEntries: [original]))
        #expect(original.amount == 900)
        #expect(try context.fetch(FetchDescriptor<IncomeEntry>()).count == 1)
    }

    @Test("Deleting removes the model")
    func deleteEntry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let original = entry(2026, 1, 100)
        context.insert(original)
        try context.save()
        let editor = IncomeEditorViewModel(entry: original)
        #expect(editor.delete(in: context))
        #expect(try context.fetch(FetchDescriptor<IncomeEntry>()).isEmpty)
    }

    @Test("Overview and year PDF reports are generated")
    func pdfReports() throws {
        let entries = [entry(2025, 1, 100_000), entry(2026, 1, 125_000), entry(2026, 2, 140_000)]
        let overviewURL = try PDFReportService.makeOverviewReport(entries: entries)
        let yearURL = try PDFReportService.makeYearReport(year: 2026, entries: entries)
        #expect(try Data(contentsOf: overviewURL).count > 1_000)
        #expect(try Data(contentsOf: yearURL).count > 1_000)
    }

    @Test("Currency conversion applies target-to-source rate")
    func currencyConversion() throws {
        #expect(CurrencyConversionService.convertedAmount(8_000, targetToSourceRate: 80) == 100)
        #expect(CurrencyConversionService.convertedAmount(100, targetToSourceRate: 0) == nil)

        let container = try makeContainer()
        let context = container.mainContext
        let first = entry(2026, 1, 8_000)
        let second = entry(2026, 2, 16_000)
        context.insert(first)
        context.insert(second)
        try context.save()

        try CurrencyConversionService.convertAll([first, second], targetToSourceRate: 80, in: context)
        #expect(first.amount == 100)
        #expect(second.amount == 200)
    }

    @Test("All supported currencies use their symbols")
    func currencyFormatting() {
        #expect(AppFormatters.currency(1_250, currency: .rub).hasSuffix("₽"))
        #expect(AppFormatters.currency(1_250, currency: .usd).hasSuffix("$"))
        #expect(AppFormatters.currency(1_250, currency: .eur).hasSuffix("€"))
    }

    @Test("Cloud conflict keeps the most recently updated month")
    func cloudConflictResolution() {
        let older = IncomeEntry(year: 2026, month: 1, amount: 100, updatedAt: Date(timeIntervalSince1970: 1))
        let newer = IncomeEntry(year: 2026, month: 1, amount: 200, updatedAt: Date(timeIntervalSince1970: 2))
        let result = IncomeAnalytics.entries(for: 2026, in: [older, newer])
        #expect(result.count == 1)
        #expect(result.first?.amount == 200)
    }

    private func entry(_ year: Int, _ month: Int, _ amount: Decimal) -> IncomeEntry {
        IncomeEntry(year: year, month: month, amount: amount)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: IncomeEntry.self, configurations: configuration)
    }
}
