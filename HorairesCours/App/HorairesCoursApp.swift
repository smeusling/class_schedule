// App/HorairesInfirmiereApp.swift

import SwiftUI
import SwiftData

@main
struct HorairesCoursApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CourseSchedule.self)
    }
}
