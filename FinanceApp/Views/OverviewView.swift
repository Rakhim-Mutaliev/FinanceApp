import SwiftData
import SwiftUI

struct OverviewView: View {
    @Environment(\.appCurrency) private var currency
    @Query private var entries: [IncomeEntry]
    @State private var showsEditor = false
    @State private var selectedYear: Int?

    private let currentYear = Calendar.current.component(.year, from: .now)
    private var currentStatistic: YearStatistic {
        IncomeAnalytics.yearStatistic(for: currentYear, entries: entries)
    }
    private var annualStatistics: [YearStatistic] {
        IncomeAnalytics.yearStatistics(from: entries)
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyIncomeView { showsEditor = true }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 22) {
                            heroCard
                            metricsGrid
                            chartCard
                            annualHistory
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Обзор")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showsEditor = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить доход")
                    .accessibilityIdentifier("addIncome")
                }
            }
            .sheet(isPresented: $showsEditor) {
                IncomeEditorView()
                    .presentationDetents([.large])
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Текущий год")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text(String(currentYear))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.14), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(AppFormatters.currency(currentStatistic.total, currency: currency))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .monospacedDigit()
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                    Text(periodDescription)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
            }

            HStack {
                Text("К прошлому году")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(AppFormatters.percent(currentStatistic.change))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: AppTheme.accent.opacity(0.22), radius: 20, y: 10)
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "Среднее в месяц",
                value: AppFormatters.currency(currentStatistic.average, currency: currency),
                icon: "equal.circle"
            )
            MetricCard(
                title: "Лучший месяц",
                value: currentStatistic.bestMonth.map { AppFormatters.monthName($0.month) } ?? "—",
                icon: "crown.fill",
                tint: .orange
            )
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Динамика по годам")
                    .font(.title3.bold())
                Text("Долгосрочная история дохода")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            AnnualIncomeChart(statistics: annualStatistics, selectedYear: $selectedYear)
        }
        .padding(20)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private var annualHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("История по годам")
                .font(.title3.bold())
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(annualStatistics.reversed().enumerated()), id: \.element.id) { index, statistic in
                    NavigationLink {
                        YearDetailView(year: statistic.year)
                    } label: {
                        HStack(spacing: 14) {
                            Text(String(statistic.year))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(width: 48, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(AppFormatters.currency(statistic.total, currency: currency))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .monospacedDigit()
                                Text("В среднем \(AppFormatters.currency(statistic.average, currency: currency))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            ChangePill(value: statistic.change, includeBackground: false)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                    }
                    if index < annualStatistics.count - 1 {
                        Divider().padding(.leading, 80)
                    }
                }
            }
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        }
    }

    private var periodDescription: String {
        guard currentStatistic.comparisonEndMonth > 0 else { return "Пока нет данных за \(currentYear)" }
        return "Январь — \(AppFormatters.monthName(currentStatistic.comparisonEndMonth))"
    }
}
