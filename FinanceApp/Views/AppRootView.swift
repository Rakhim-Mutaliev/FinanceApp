import SwiftUI
import SwiftData

struct AppRootView: View {
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppCurrency.defaultsKey) private var currencyCode = AppCurrency.rub.rawValue

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Обзор", systemImage: "chart.xyaxis.line") }
            YearsView()
                .tabItem { Label("Годы", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
        }
        .tint(AppTheme.accent)
        .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
        .environment(\.appCurrency, AppCurrency(rawValue: currencyCode) ?? .rub)
        .onAppear {
            currencyCode = CloudPreferencesService.initialCurrency(localValue: currencyCode)
        }
        .onChange(of: currencyCode) { _, newValue in
            CloudPreferencesService.setCurrency(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification
        )) { _ in
            if let cloudCurrency = CloudPreferencesService.cloudCurrency {
                currencyCode = cloudCurrency
            }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: IncomeEntry.self, inMemory: true)
}
