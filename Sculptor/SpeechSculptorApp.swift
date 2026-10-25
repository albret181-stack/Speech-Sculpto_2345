import SwiftUI

@main
struct SpeechSculptorApp: App {
    @StateObject private var studio = StudioController()
    var body: some Scene {
        WindowGroup("Скульптор речи") {
            StudioView()
                .environmentObject(studio)
                .preferredColorScheme(.light)
                .frame(minWidth: 870, minHeight: 630)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1160, height: 770)
        Settings { StudioSettings().environmentObject(studio).preferredColorScheme(.light) }
    }
}
