import SwiftData
import SwiftUI

struct YearsView: View {
    @Environment(\.appCurrency) private var currency
    @Query private var entries: [IncomeEntry]
    @State private var showsEditor = false

    private var statistics: [YearStatistic] {
        Array(IncomeAnalytics.yearStatistics(from: entries).reversed())
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyIncomeView { showsEditor = true }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(statistics) { statistic in
                                NavigationLink {
                                    YearDetailView(year: statistic.year)
                                } label: {
                                    yearCard(statistic)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Годы")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showsEditor = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Добавить доход")
                }
            }
            .sheet(isPresented: $showsEditor) { IncomeEditorView() }
        }
    }

    private func yearCard(_ statistic: YearStatistic) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text(String(statistic.year))
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Spacer()
                ChangePill(value: statistic.change)
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }

            Text(AppFormatters.currency(statistic.total, currency: currency))
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .monospacedDigit()

            HStack(spacing: 20) {
                Label("\(statistic.filledMonthCount) мес.", systemImage: "calendar")
                Label(AppFormatters.currency(statistic.average, currency: currency), systemImage: "equal.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }
}
