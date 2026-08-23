import SwiftData
import SwiftUI

struct YearDetailView: View {
    let year: Int

    @Environment(\.appCurrency) private var currency
    @Query private var entries: [IncomeEntry]
    @State private var selectedMonth: Int?
    @State private var editorSelection: EditorSelection?
    @State private var shareURL: URL?

    private var statistic: YearStatistic {
        IncomeAnalytics.yearStatistic(for: year, entries: entries)
    }
    private var months: [MonthStatistic] {
        IncomeAnalytics.monthStatistics(for: year, entries: entries)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                summaryCard
                metricsGrid
                chartCard
                monthList
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color.appBackground)
        .navigationTitle(String(year))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    shareURL = try? PDFReportService.makeYearReport(year: year, entries: entries)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Экспортировать отчёт")

                Button {
                    editorSelection = EditorSelection(entry: nil, month: defaultMonth)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Добавить доход")
            }
        }
        .sheet(item: $editorSelection) { selection in
            IncomeEditorView(entry: selection.entry, defaultYear: year, defaultMonth: selection.month)
        }
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL { ActivityView(items: [shareURL]) }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Доход за год", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                ChangePillOnColor(value: statistic.change)
            }
            Text(AppFormatters.currency(statistic.total, currency: currency))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [AppTheme.accentSecondary, AppTheme.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "Среднее в месяц",
                value: AppFormatters.currency(statistic.average, currency: currency),
                icon: "equal.circle"
            )
            MetricCard(
                title: "Лучший месяц",
                value: statistic.bestMonth.map { AppFormatters.monthName($0.month) } ?? "—",
                icon: "crown.fill",
                tint: .orange
            )
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("По месяцам")
                    .font(.title3.bold())
                Text("Нажмите на точку для подробностей")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            MonthlyIncomeChart(statistics: months, selectedMonth: $selectedMonth)
        }
        .padding(20)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private var monthList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Все месяцы")
                .font(.title3.bold())
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                    Button {
                        let entry = entries.first { $0.year == year && $0.month == month.month }
                        editorSelection = EditorSelection(entry: entry, month: month.month)
                    } label: {
                        HStack(spacing: 14) {
                            Text(AppFormatters.monthName(month.month, short: true))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 42, alignment: .leading)

                            if let amount = month.amount {
                                Text(AppFormatters.currency(amount, currency: currency))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                                Spacer()
                                ChangePill(value: month.change, includeBackground: false)
                            } else {
                                Text("Нет данных")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 15)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < months.count - 1 { Divider().padding(.leading, 74) }
                }
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        }
    }

    private var defaultMonth: Int {
        let currentMonth = Calendar.current.component(.month, from: .now)
        return year == Calendar.current.component(.year, from: .now) ? currentMonth : 1
    }
}

private struct EditorSelection: Identifiable {
    let id = UUID()
    let entry: IncomeEntry?
    let month: Int
}

private struct ChangePillOnColor: View {
    let value: Double?

    var body: some View {
        HStack(spacing: 4) {
            if let value {
                Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
            }
            Text(AppFormatters.percent(value))
                .monospacedDigit()
        }
        .font(.caption.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.15), in: Capsule())
    }
}
