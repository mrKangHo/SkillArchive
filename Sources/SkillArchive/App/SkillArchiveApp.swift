import SwiftUI

@main
struct SkillArchiveApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
