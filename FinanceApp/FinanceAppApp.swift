//
//  FinanceAppApp.swift
//  FinanceApp
//
//  Created by Rakhim on 23.08.2026.
//

import SwiftUI
import SwiftData

@main
struct FinanceAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let isTesting = CommandLine.arguments.contains("-uiTesting")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let schema = Schema([
            IncomeEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isTesting,
            cloudKitDatabase: isTesting || AppBuildMode.isLocalOnly
                ? .none
                : .private(CloudSyncService.containerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
