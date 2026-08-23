import Foundation

enum AppFormatters {
    static let russianLocale = Locale(identifier: "ru_RU")

    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = russianLocale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        formatter.groupingSeparator = "\u{00A0}"
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    static func currency(_ value: Decimal, currency: AppCurrency = .current) -> String {
        let number = NSDecimalNumber(decimal: value)
        return "\(decimal.string(from: number) ?? number.stringValue)\u{00A0}\(currency.symbol)"
    }

    static func compactCurrency(_ value: Decimal, currency: AppCurrency = .current) -> String {
        let number = NSDecimalNumber(decimal: value).doubleValue
        let formatter = NumberFormatter()
        formatter.locale = russianLocale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        if abs(number) >= 1_000_000 {
            return "\(formatter.string(from: NSNumber(value: number / 1_000_000)) ?? "0") млн \(currency.symbol)"
        }
        if abs(number) >= 1_000 {
            return "\(formatter.string(from: NSNumber(value: number / 1_000)) ?? "0") тыс. \(currency.symbol)"
        }
        return self.currency(value, currency: currency)
    }

    static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = russianLocale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let prefix = value > 0 ? "+" : ""
        return "\(prefix)\(formatter.string(from: NSNumber(value: value)) ?? "0")%"
    }

    static func monthName(_ month: Int, short: Bool = false) -> String {
        let full = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
        let abbreviated = ["Янв", "Фев", "Мар", "Апр", "Май", "Июн", "Июл", "Авг", "Сен", "Окт", "Ноя", "Дек"]
        let symbols = short ? abbreviated : full
        guard (1...12).contains(month), symbols.indices.contains(month - 1) else { return "" }
        return symbols[month - 1]
    }
}

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
