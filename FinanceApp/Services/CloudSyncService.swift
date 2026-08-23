import CloudKit
import Foundation

enum CloudSyncService {
    static let containerIdentifier = "iCloud.Rakhim-Mutaliev.FinanceApp"

    static func accountState() async -> CloudAccountState {
        if CommandLine.arguments.contains("-uiTesting") { return .available }
        return await withCheckedContinuation { (continuation: CheckedContinuation<CloudAccountState, Never>) in
            CKContainer(identifier: containerIdentifier).accountStatus { status, error in
                if error != nil {
                    continuation.resume(returning: .unknown)
                    return
                }
                switch status {
                case .available:
                    continuation.resume(returning: .available)
                case .noAccount:
                    continuation.resume(returning: .noAccount)
                case .restricted:
                    continuation.resume(returning: .restricted)
                case .temporarilyUnavailable:
                    continuation.resume(returning: .temporarilyUnavailable)
                case .couldNotDetermine:
                    continuation.resume(returning: .unknown)
                @unknown default:
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }
}

enum CloudAccountState: Sendable, Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case unknown

    var title: String {
        switch self {
        case .checking: "Проверка iCloud…"
        case .available: "Синхронизация включена"
        case .noAccount: "Войдите в iCloud"
        case .restricted: "Доступ к iCloud ограничен"
        case .temporarilyUnavailable: "iCloud временно недоступен"
        case .unknown: "Не удалось проверить iCloud"
        }
    }

    var detail: String {
        switch self {
        case .checking: "Проверяем состояние учётной записи"
        case .available: "История доходов автоматически обновляется на ваших устройствах"
        case .noAccount: "Добавленные данные останутся на устройстве до входа в iCloud"
        case .restricted: "Проверьте ограничения устройства или настройки организации"
        case .temporarilyUnavailable: "Локальные изменения синхронизируются позже автоматически"
        case .unknown: "Проверьте подключение и настройки iCloud"
        }
    }

    var systemImage: String {
        switch self {
        case .checking: "icloud"
        case .available: "icloud.fill"
        case .temporarilyUnavailable: "icloud.and.arrow.up"
        default: "icloud.slash"
        }
    }
}
