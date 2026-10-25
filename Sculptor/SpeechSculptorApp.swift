import SwiftUI

@main
struct SpeechSculptorApp: App {
    @StateObject private var studio = StudioController()
    @StateObject private var updates = UpdateManager()
    var body: some Scene {
        WindowGroup("Скульптор речи") {
            StudioView()
                .environmentObject(studio)
                .environmentObject(updates)
                .preferredColorScheme(.light)
                .frame(minWidth: 870, minHeight: 630)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1160, height: 770)
        Settings { StudioSettings().environmentObject(studio).environmentObject(updates).preferredColorScheme(.light) }
    }
}
