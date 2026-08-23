import SwiftData
import SwiftUI

struct IncomeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appCurrency) private var currency
    @Query private var entries: [IncomeEntry]
    @State private var viewModel: IncomeEditorViewModel
    @State private var showsDeleteConfirmation = false

    private let currentYear = Calendar.current.component(.year, from: .now)

    init(entry: IncomeEntry? = nil, defaultYear: Int? = nil, defaultMonth: Int? = nil) {
        _viewModel = State(initialValue: IncomeEditorViewModel(
            entry: entry,
            defaultYear: defaultYear,
            defaultMonth: defaultMonth
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    periodCard
                    amountCard

                    if viewModel.canDelete {
                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            Label("Удалить запись", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground)
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if viewModel.save(in: modelContext, existingEntries: entries) {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("saveIncome")
                }
            }
            .alert("Удалить доход?", isPresented: $showsDeleteConfirmation) {
                Button("Удалить", role: .destructive) {
                    if viewModel.delete(in: modelContext) { dismiss() }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Запись исчезнет из статистики и графиков. Это действие нельзя отменить.")
            }
            .alert("Не удалось сохранить", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Период", systemImage: "calendar")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Месяц", selection: $viewModel.month) {
                    ForEach(1...12, id: \.self) { month in
                        Text(AppFormatters.monthName(month)).tag(month)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 24)

                Picker("Год", selection: $viewModel.year) {
                    ForEach((currentYear - 50)...(currentYear + 20), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)
            }
            .font(.title3.weight(.semibold))
            .tint(.primary)
        }
        .padding(20)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Доход", systemImage: "rublesign.circle")
                .font(.headline)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0", text: $viewModel.amountText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("incomeAmount")
                Text(currency.symbol)
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }

            Text("Сумма вводится в \(currency.title.lowercased()). Нулевое значение не считается отсутствием данных.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color.appCard, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }
}
