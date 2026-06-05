import SwiftUI
import UIKit
import WidflyKit

@main
struct WidflyApp: App {
    @State private var model = AppModel()

    init() {
        UIWindow.appearance().backgroundColor = Theme.backgroundUIColor
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
