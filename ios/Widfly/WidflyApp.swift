import SwiftUI
import UIKit
import WidflyKit

@main
struct WidflyApp: App {
    @State private var model = AppModel()

    init() {
        // Paint the underlying UIWindow navy so the status bar and home
        // indicator safe-area regions show navy instead of the system's
        // default black. SwiftUI's `.ignoresSafeArea()` does not reach
        // down to the UIWindow layer, so we set it via appearance proxy.
        UIWindow.appearance().backgroundColor = Theme.backgroundUIColor
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.background.ignoresSafeArea()
                ContentView().environment(model)
            }
        }
    }
}
