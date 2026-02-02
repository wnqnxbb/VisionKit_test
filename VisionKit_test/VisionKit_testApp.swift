//
//  VisionKit_testApp.swift
//  VisionKit_test
//
//  Created by 赵铭轩 on 2026/2/2.
//

import SwiftUI
import SwiftData

@main
struct VisionKit_testApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SubjectCutout.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
