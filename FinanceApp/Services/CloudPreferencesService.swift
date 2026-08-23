import Foundation

enum CloudPreferencesService {
    private static let store = NSUbiquitousKeyValueStore.default

    static func initialCurrency(localValue: String) -> String {
        guard !CommandLine.arguments.contains("-uiTesting") else { return localValue }
        store.synchronize()
        if let cloudValue = store.string(forKey: AppCurrency.defaultsKey),
           AppCurrency(rawValue: cloudValue) != nil {
            return cloudValue
        }
        setCurrency(localValue)
        return localValue
    }

    static func setCurrency(_ value: String) {
        guard !CommandLine.arguments.contains("-uiTesting") else { return }
        guard AppCurrency(rawValue: value) != nil else { return }
        store.set(value, forKey: AppCurrency.defaultsKey)
        store.synchronize()
    }

    static var cloudCurrency: String? {
        guard let value = store.string(forKey: AppCurrency.defaultsKey),
              AppCurrency(rawValue: value) != nil else { return nil }
        return value
    }
}
