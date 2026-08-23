import Charts
import SwiftUI

struct AnnualIncomeChart: View {
    @Environment(\.appCurrency) private var currency
    let statistics: [YearStatistic]
    @Binding var selectedYear: Int?

    private var selectedStatistic: YearStatistic? {
        guard let selectedYear else { return nil }
        return statistics.first { $0.year == selectedYear }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selectedStatistic {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(selectedStatistic.year))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(AppFormatters.currency(selectedStatistic.total, currency: currency))
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                    ChangePill(value: selectedStatistic.change)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("Нажмите на точку, чтобы увидеть детали")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(statistics) { item in
                AreaMark(
                    x: .value("Год", item.year),
                    y: .value("Доход", item.total.doubleValue)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.28), AppTheme.accent.opacity(0.015)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Год", item.year),
                    y: .value("Доход", item.total.doubleValue)
                )
                .foregroundStyle(AppTheme.accent)
                .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Год", item.year),
                    y: .value("Доход", item.total.doubleValue)
                )
                .foregroundStyle(selectedYear == item.year ? .white : AppTheme.accent)
                .symbolSize(selectedYear == item.year ? 90 : 35)
                .annotation(position: .overlay) {
                    if selectedYear == item.year {
                        Circle().stroke(AppTheme.accent, lineWidth: 3).frame(width: 13, height: 13)
                    }
                }

                if selectedYear == item.year {
                    RuleMark(x: .value("Выбранный год", item.year))
                        .foregroundStyle(AppTheme.accent.opacity(0.25))
                        .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedYear)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(AppFormatters.compactCurrency(Decimal(number), currency: currency))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: statistics.map(\.year)) { value in
                    AxisValueLabel()
                    AxisTick().foregroundStyle(.secondary.opacity(0.3))
                }
            }
            .frame(height: 230)
            .animation(.snappy, value: selectedYear)
        }
    }
}

struct MonthlyIncomeChart: View {
    @Environment(\.appCurrency) private var currency
    let statistics: [MonthStatistic]
    @Binding var selectedMonth: Int?

    private var presentStatistics: [MonthStatistic] { statistics.filter { $0.amount != nil } }
    private var selectedStatistic: MonthStatistic? {
        guard let selectedMonth else { return nil }
        return statistics.first { $0.month == selectedMonth }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                if let selectedStatistic, let amount = selectedStatistic.amount {
                    Text(AppFormatters.monthName(selectedStatistic.month))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(AppFormatters.currency(amount, currency: currency))
                        .font(.headline.weight(.semibold))
                        .monospacedDigit()
                    ChangePill(value: selectedStatistic.change)
                } else {
                    Text("Выберите месяц на графике")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 28)

            Chart(presentStatistics) { item in
                if let amount = item.amount {
                    AreaMark(
                        x: .value("Месяц", item.month),
                        y: .value("Доход", amount.doubleValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accentSecondary.opacity(0.25), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Месяц", item.month),
                        y: .value("Доход", amount.doubleValue)
                    )
                    .foregroundStyle(AppTheme.accentSecondary)
                    .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Месяц", item.month),
                        y: .value("Доход", amount.doubleValue)
                    )
                    .foregroundStyle(selectedMonth == item.month ? .white : AppTheme.accentSecondary)
                    .symbolSize(selectedMonth == item.month ? 90 : 34)

                    if selectedMonth == item.month {
                        RuleMark(x: .value("Выбранный месяц", item.month))
                            .foregroundStyle(AppTheme.accentSecondary.opacity(0.25))
                            .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                    }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .chartXScale(domain: 1...12)
            .chartXAxis {
                AxisMarks(values: [1, 3, 5, 7, 9, 11]) { value in
                    AxisValueLabel {
                        if let month = value.as(Int.self) {
                            Text(AppFormatters.monthName(month, short: true))
                        }
                    }
                    AxisTick().foregroundStyle(.secondary.opacity(0.3))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(AppFormatters.compactCurrency(Decimal(number), currency: currency))
                        }
                    }
                }
            }
            .frame(height: 240)
            .animation(.snappy, value: selectedMonth)
        }
    }
}
