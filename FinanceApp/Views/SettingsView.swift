import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query private var entries: [IncomeEntry]
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppCurrency.defaultsKey) private var storedCurrency = AppCurrency.rub.rawValue
    @State private var shareURL: URL?
    @State private var showsDeleteConfirmation = false
    @State private var exportError = false
    @State private var showsCurrencySettings = false
    @State private var cloudState = CloudAccountState.checking
    @State private var backupDocument: FinanceBackupDocument?
    @State private var pendingBackup: FinanceBackup?
    @State private var showsBackupExporter = false
    @State private var showsBackupImporter = false
    @State private var showsBackupRestoreConfirmation = false
    @State private var backupStatusMessage: String?
    @State private var backupErrorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                storageSection
                dataSection
                backupSection
                deleteSection
                aboutSection
            }
            .navigationTitle("Настройки")
            .task {
                if !AppBuildMode.isLocalOnly {
                    cloudState = await CloudSyncService.accountState()
                }
            }
            .confirmationDialog("Удалить всю историю?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
                Button("Удалить все данные", role: .destructive) { deleteAllData() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Записи и рассчитанная статистика будут удалены без возможности восстановления.")
            }
            .confirmationDialog(
                "Восстановить резервную копию?",
                isPresented: $showsBackupRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("Восстановить") { restorePendingBackup() }
                Button("Отмена", role: .cancel) { pendingBackup = nil }
            } message: {
                Text("Периоды из копии будут добавлены или заменят совпадающие записи. Остальные записи сохранятся.")
            }
            .alert("Не удалось создать PDF", isPresented: $exportError) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text("Попробуйте повторить экспорт.")
            }
            .alert("Резервная копия", isPresented: Binding(
                get: { backupStatusMessage != nil },
                set: { if !$0 { backupStatusMessage = nil } }
            )) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(backupStatusMessage ?? "")
            }
            .alert("Ошибка резервной копии", isPresented: Binding(
                get: { backupErrorMessage != nil },
                set: { if !$0 { backupErrorMessage = nil } }
            )) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(backupErrorMessage ?? "")
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
            .fileExporter(
                isPresented: $showsBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: FinanceBackupService.defaultFilename()
            ) { result in
                switch result {
                case .success:
                    backupStatusMessage = "Резервная копия сохранена в приложении «Файлы»."
                case .failure(let error):
                    backupErrorMessage = error.localizedDescription
                }
                backupDocument = nil
            }
            .fileImporter(
                isPresented: $showsBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleBackupImport(result)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Оформление") {
            Picker("Тема", selection: $appearance) {
                ForEach(AppAppearance.allCases) { item in
                    Label(item.title, systemImage: item.icon)
                        .tag(item.rawValue)
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
    }

    @ViewBuilder
    private var storageSection: some View {
        if AppBuildMode.isLocalOnly {
            Section("Хранение") {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Только на этом iPhone")
                            .font(.subheadline.weight(.semibold))
                        Text("iCloud временно отключён для бесплатной подписи Personal Team.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "iphone")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        } else {
            Section("iCloud") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: cloudState.systemImage)
                        .font(.title3)
                        .foregroundStyle(cloudStatusColor)
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
        }
    }

    private var cloudStatusColor: Color {
        cloudState == .available ? AppTheme.accent : .secondary
    }

    private var dataSection: some View {
        Section("Данные") {
            Button(action: exportPDF) {
                Label("Экспортировать общий PDF", systemImage: "doc.richtext")
            }
            .disabled(entries.isEmpty)

            LabeledContent("Записей", value: String(entries.count))
            LabeledContent("Лет в истории", value: String(Set(entries.map(\.year)).count))
        }
    }

    private var backupSection: some View {
        Section {
            Button(action: prepareBackup) {
                Label("Сохранить копию в Файлы", systemImage: "square.and.arrow.down")
            }
            .disabled(entries.isEmpty)

            Button {
                showsBackupImporter = true
            } label: {
                Label("Восстановить из копии", systemImage: "arrow.clockwise.icloud")
            }
        } header: {
            Text("Резервная копия")
        } footer: {
            Text("Копия содержит все суммы, даты и выбранную валюту. Храните её в приложении «Файлы» до перехода на iCloud-версию.")
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Label("Удалить все данные", systemImage: "trash")
            }
            .disabled(entries.isEmpty)
        } footer: {
            Text(storageFooter)
        }
    }

    private var aboutSection: some View {
        Section("О приложении") {
            LabeledContent("Версия", value: AppBuildMode.isLocalOnly ? "1.0 Local" : "1.0")
            LabeledContent("Текущая валюта", value: "\(currency.shortTitle) (\(currency.symbol))")
        }
    }

    private var storageFooter: String {
        if AppBuildMode.isLocalOnly {
            return "Удаление приложения с iPhone удалит локальные данные. Перед удалением создайте резервную копию."
        }
        return "Данные сохраняются локально и синхронизируются через приватную базу iCloud."
    }

    private func exportPDF() {
        do {
            shareURL = try PDFReportService.makeOverviewReport(entries: entries)
        } catch {
            exportError = true
        }
    }

    private func prepareBackup() {
        let selectedCurrency = AppCurrency(rawValue: storedCurrency) ?? .rub
        backupDocument = FinanceBackupDocument(
            backup: FinanceBackup(entries: entries, currency: selectedCurrency)
        )
        showsBackupExporter = true
    }

    private func handleBackupImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                throw FinanceBackupError.unreadableFile
            }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            pendingBackup = try FinanceBackupService.decode(Data(contentsOf: url))
            showsBackupRestoreConfirmation = true
        } catch {
            backupErrorMessage = error.localizedDescription
        }
    }

    private func restorePendingBackup() {
        guard let backup = pendingBackup else { return }
        do {
            let restoredCount = try FinanceBackupService.restore(
                backup,
                existingEntries: entries,
                in: modelContext
            )
            storedCurrency = backup.currencyCode
            backupStatusMessage = "Восстановлено записей: \(restoredCount)."
            pendingBackup = nil
        } catch {
            backupErrorMessage = error.localizedDescription
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
