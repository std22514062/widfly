import SwiftUI
import UIKit
import WidflyKit

@main
struct WidflyApp: App {
    @State private var model = AppModel()
    @State private var isShowingIntro = true

    init() {
        UIWindow.appearance().backgroundColor = Theme.backgroundUIColor
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(model)

                if isShowingIntro {
                    LaunchIntroView {
                        isShowingIntro = false
                    }
                    .zIndex(1)
                    .transition(.opacity)
                }
            }
            .background(Theme.background)
        }
    }
}
