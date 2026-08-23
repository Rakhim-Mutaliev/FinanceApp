import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct FinanceBackup: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let createdAt: Date
    let currencyCode: String
    let entries: [FinanceBackupEntry]

    @MainActor
    init(entries: [IncomeEntry], currency: AppCurrency) {
        version = Self.currentVersion
        createdAt = .now
        currencyCode = currency.rawValue
        self.entries = entries.map(FinanceBackupEntry.init).sorted {
            ($0.year, $0.month) < ($1.year, $1.month)
        }
    }
}

nonisolated struct FinanceBackupEntry: Codable, Sendable {
    let id: UUID
    let year: Int
    let month: Int
    let amount: String
    let createdAt: Date
    let updatedAt: Date

    @MainActor
    init(_ entry: IncomeEntry) {
        id = entry.id
        year = entry.year
        month = entry.month
        amount = NSDecimalNumber(decimal: entry.amount).stringValue
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }

    nonisolated var decimalAmount: Decimal? {
        Decimal(string: amount, locale: Locale(identifier: "en_US_POSIX"))
    }
}

struct FinanceBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let backup: FinanceBackup

    init(backup: FinanceBackup) {
        self.backup = backup
    }

    nonisolated init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw FinanceBackupError.unreadableFile
        }
        backup = try FinanceBackupService.decode(data)
    }

    nonisolated func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try FinanceBackupService.encode(backup))
    }
}

enum FinanceBackupService {
    nonisolated static func encode(_ backup: FinanceBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    nonisolated static func decode(_ data: Data) throws -> FinanceBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(FinanceBackup.self, from: data)
        guard backup.version == FinanceBackup.currentVersion else {
            throw FinanceBackupError.unsupportedVersion
        }
        guard AppCurrency(rawValue: backup.currencyCode) != nil else {
            throw FinanceBackupError.invalidCurrency
        }
        guard backup.entries.allSatisfy({ entry in
            (1...12).contains(entry.month)
                && (1900...2200).contains(entry.year)
                && entry.decimalAmount.map { $0 >= .zero } == true
        }) else {
            throw FinanceBackupError.invalidEntry
        }
        return backup
    }

    @discardableResult
    @MainActor
    static func restore(
        _ backup: FinanceBackup,
        existingEntries: [IncomeEntry],
        in context: ModelContext
    ) throws -> Int {
        var existingByPeriod: [String: IncomeEntry] = [:]

        for entry in existingEntries.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            let key = IncomeEntry.makePeriodKey(year: entry.year, month: entry.month)
            if existingByPeriod[key] == nil {
                existingByPeriod[key] = entry
            } else {
                context.delete(entry)
            }
        }

        for item in backup.entries {
            guard let amount = item.decimalAmount else {
                throw FinanceBackupError.invalidEntry
            }
            let key = IncomeEntry.makePeriodKey(year: item.year, month: item.month)
            if let existing = existingByPeriod[key] {
                existing.id = item.id
                existing.periodKey = key
                existing.amount = amount
                existing.createdAt = item.createdAt
                existing.updatedAt = item.updatedAt
            } else {
                let entry = IncomeEntry(
                    id: item.id,
                    year: item.year,
                    month: item.month,
                    amount: amount,
                    createdAt: item.createdAt,
                    updatedAt: item.updatedAt
                )
                context.insert(entry)
                existingByPeriod[key] = entry
            }
        }

        try context.save()
        return backup.entries.count
    }

    static func defaultFilename() -> String {
        let date = Date.now.formatted(.iso8601.year().month().day())
        return "FinanceApp-Backup-\(date)"
    }
}

enum FinanceBackupError: LocalizedError {
    case unreadableFile
    case unsupportedVersion
    case invalidCurrency
    case invalidEntry

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            "Не удалось прочитать файл резервной копии."
        case .unsupportedVersion:
            "Эта версия резервной копии пока не поддерживается."
        case .invalidCurrency:
            "В резервной копии указана неизвестная валюта."
        case .invalidEntry:
            "Резервная копия содержит некорректные записи."
        }
    }
}
