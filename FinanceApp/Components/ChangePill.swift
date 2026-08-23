import SwiftUI

struct ChangePill: View {
    let value: Double?
    var includeBackground = true

    private var color: Color {
        guard let value else { return .secondary }
        return value >= 0 ? AppTheme.positive : AppTheme.negative
    }

    var body: some View {
        HStack(spacing: 4) {
            if let value {
                Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2.weight(.bold))
            }
            Text(AppFormatters.percent(value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, includeBackground ? 9 : 0)
        .padding(.vertical, includeBackground ? 6 : 0)
        .background(includeBackground ? color.opacity(0.12) : .clear, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Изменение \(AppFormatters.percent(value))")
    }
}
