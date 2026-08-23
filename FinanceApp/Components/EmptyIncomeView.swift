import SwiftUI

struct EmptyIncomeView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.18), AppTheme.accentSecondary.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 116, height: 116)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 43, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(spacing: 8) {
                Text("Начните историю дохода")
                    .font(.title2.bold())
                Text("Добавьте первый месяц — статистика и графики появятся автоматически.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 310)
            }

            Button(action: action) {
                Label("Добавить первый доход", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: 290)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(AppTheme.accent)
            .accessibilityIdentifier("addFirstIncome")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
    }
}
