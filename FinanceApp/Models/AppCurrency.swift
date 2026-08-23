import Foundation
import SwiftUI

enum AppCurrency: String, CaseIterable, Identifiable, Sendable {
    case rub = "RUB"
    case usd = "USD"
    case eur = "EUR"

    static let defaultsKey = "displayCurrency"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rub: "Российский рубль"
        case .usd: "Доллар США"
        case .eur: "Евро"
        }
    }

    var shortTitle: String {
        switch self {
        case .rub: "Рубль"
        case .usd: "Доллар"
        case .eur: "Евро"
        }
    }

    var symbol: String {
        switch self {
        case .rub: "₽"
        case .usd: "$"
        case .eur: "€"
        }
    }

    var flag: String {
        switch self {
        case .rub: "🇷🇺"
        case .usd: "🇺🇸"
        case .eur: "🇪🇺"
        }
    }

    static var current: AppCurrency {
        let value = UserDefaults.standard.string(forKey: defaultsKey)
        return AppCurrency(rawValue: value ?? "") ?? .rub
    }
}

private struct AppCurrencyKey: EnvironmentKey {
    static let defaultValue = AppCurrency.rub
}

extension EnvironmentValues {
    var appCurrency: AppCurrency {
        get { self[AppCurrencyKey.self] }
        set { self[AppCurrencyKey.self] = newValue }
    }
}
