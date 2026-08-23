import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.18, green: 0.49, blue: 0.96)
    static let accentSecondary = Color(red: 0.40, green: 0.30, blue: 0.92)
    static let positive = Color(red: 0.12, green: 0.63, blue: 0.39)
    static let negative = Color(red: 0.92, green: 0.28, blue: 0.31)
    static let cardRadius: CGFloat = 24
}

extension Color {
    static let appBackground = Color(uiColor: .systemGroupedBackground)
    static let appCard = Color(uiColor: .secondarySystemGroupedBackground)
}
