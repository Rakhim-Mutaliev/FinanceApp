import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query private var entries: [IncomeEntry]
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @State private var shareURL: URL?
    @State private var showsDeleteConfirmation = false
    @State private var exportError = false
    @State private var showsCurrencySettings = false
    @State private var cloudState = CloudAccountState.checking

    var body: some View {
        NavigationStack {
            List {
                Section("Оформление") {
                    Picker("Тема", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { item in
                            Label(item.title, systemImage: item.icon).tag(item.rawValue)
                        }
                    }

                    Button {
                        showsCurrencySettings = true
                    } label: {
                        HStack {
                            Label("Валюта", systemImage: "coloncurrencysign.circle")
                            Spacer()
                            Text("\(currency.flag)  \(currency.rawValue)")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("currentCurrencyCode")
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("currencySettings")
                }

                Section("iCloud") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: cloudState.systemImage)
                            .font(.title3)
                            .foregroundStyle(cloudState == .available ? AppTheme.accent : .secondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cloudState.title)
                                .font(.subheadline.weight(.semibold))
                            Text(cloudState.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Данные") {
                    Button {
                        do {
                            shareURL = try PDFReportService.makeOverviewReport(entries: entries)
                        } catch {
                            exportError = true
                        }
                    } label: {
                        Label("Экспортировать общий PDF", systemImage: "doc.richtext")
                    }
                    .disabled(entries.isEmpty)

                    LabeledContent("Записей", value: String(entries.count))
                    LabeledContent("Лет в истории", value: String(Set(entries.map(\.year)).count))
                }

                Section {
                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        Label("Удалить все данные", systemImage: "trash")
                    }
                    .disabled(entries.isEmpty)
                } footer: {
                    Text("Данные сохраняются локально и синхронизируются через приватную базу iCloud.")
                }

                Section("О приложении") {
                    LabeledContent("Версия", value: "1.0")
                    LabeledContent("Текущая валюта", value: "\(currency.shortTitle) (\(currency.symbol))")
                }
            }
            .navigationTitle("Настройки")
            .task {
                cloudState = await CloudSyncService.accountState()
            }
            .confirmationDialog("Удалить всю историю?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                Button("Удалить все данные", role: .destructive) { deleteAllData() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Записи и рассчитанная статистика будут удалены без возможности восстановления.")
            }
            .alert("Не удалось создать PDF", isPresented: $exportError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text("Попробуйте повторить экспорт.")
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )) {
                if let shareURL { ActivityView(items: [shareURL]) }
            }
            .sheet(isPresented: $showsCurrencySettings) {
                CurrencySettingsView()
            }
        }
    }

    private func deleteAllData() {
        entries.forEach(modelContext.delete)
        try? modelContext.save()
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "Системная"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
