import SwiftUI

@main
struct VortexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup — this is a menu bar-only app (LSUIElement = true)
        Settings {
            EmptyView()
        }
    }
}
