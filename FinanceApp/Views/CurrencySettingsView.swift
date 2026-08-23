import SwiftData
import SwiftUI

struct CurrencySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [IncomeEntry]
    @AppStorage(AppCurrency.defaultsKey) private var storedCurrency = AppCurrency.rub.rawValue

    @State private var targetCurrency = AppCurrency.rub
    @State private var mode = CurrencyChangeMode.keepValues
    @State private var exchangeRate = ""
    @State private var errorMessage: String?
    @State private var showsConversionConfirmation = false

    private var currentCurrency: AppCurrency {
        AppCurrency(rawValue: storedCurrency) ?? .rub
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Валюта приложения") {
                    ForEach(AppCurrency.allCases) { currency in
                        Button {
                            targetCurrency = currency
                        } label: {
                            HStack(spacing: 12) {
                                Text(currency.flag).font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(currency.title).foregroundStyle(.primary)
                                    Text("\(currency.rawValue) · \(currency.symbol)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if targetCurrency == currency {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                        .accessibilityIdentifier("currency_\(currency.rawValue)")
                    }
                }

                if targetCurrency != currentCurrency {
                    Section("Что сделать с историей") {
                        Picker("Режим", selection: $mode) {
                            ForEach(CurrencyChangeMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if mode == .keepValues {
                            Label {
                                Text("Числа останутся прежними, изменится только знак валюты. Например, \(AppFormatters.currency(100_000, currency: currentCurrency)) станет \(AppFormatters.currency(100_000, currency: targetCurrency)).")
                            } icon: {
                                Image(systemName: "equal.circle")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        } else {
                            rateEditor
                        }
                    }
                }
            }
            .navigationTitle("Валюта")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: saveTapped)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveCurrency")
                }
            }
            .onAppear { targetCurrency = currentCurrency }
            .confirmationDialog(
                "Пересчитать всю историю?",
                isPresented: $showsConversionConfirmation,
                titleVisibility: .visible
            ) {
                Button("Пересчитать и сохранить") { applyConversion() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все \(entries.count) записей будут пересчитаны по указанному курсу.")
            }
            .alert("Не удалось изменить валюту", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var rateEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Укажите, сколько \(currentCurrency.shortTitle.lowercased()) стоит одна единица новой валюты:")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text("1 \(targetCurrency.symbol) =")
                    .font(.headline)
                TextField("Курс", text: $exchangeRate)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("exchangeRate")
                Text(currentCurrency.symbol)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let rate = parsedRate,
               let converted = CurrencyConversionService.convertedAmount(100_000, targetToSourceRate: rate) {
                Text("Пример: \(AppFormatters.currency(100_000, currency: currentCurrency)) → \(AppFormatters.currency(converted, currency: targetCurrency))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }

    private var parsedRate: Decimal? {
        let normalized = exchangeRate
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), value > .zero else {
            return nil
        }
        return value
    }

    private var canSave: Bool {
        targetCurrency == currentCurrency || mode == .keepValues || parsedRate != nil
    }

    private func saveTapped() {
        guard targetCurrency != currentCurrency else {
            dismiss()
            return
        }
        if mode == .convertHistory && !entries.isEmpty {
            showsConversionConfirmation = true
        } else {
            storedCurrency = targetCurrency.rawValue
            dismiss()
        }
    }

    private func applyConversion() {
        guard let rate = parsedRate else {
            errorMessage = "Введите корректный курс больше нуля."
            return
        }
        do {
            try CurrencyConversionService.convertAll(entries, targetToSourceRate: rate, in: modelContext)
            storedCurrency = targetCurrency.rawValue
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum CurrencyChangeMode: String, CaseIterable, Identifiable {
    case keepValues
    case convertHistory

    var id: String { rawValue }
    var title: String {
        switch self {
        case .keepValues: "Без пересчёта"
        case .convertHistory: "По курсу"
        }
    }
}
