import SwiftUI

struct SkyscannerExternalOpenerBackgroundView: View {
    @Bindable var session: SkyscannerDetailSession
    let onResolved: (URL) -> Void
    let onFinish: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var didStart = false

    var body: some View {
        WebViewRepresentable(webView: session.webView)
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard !didStart else { return }
                didStart = true
                session.start()
            }
            .onChange(of: session.resolvedURL) { _, url in
                guard let url else { return }
                onResolved(url)
                openURL(url)
                finish()
            }
            .onDisappear {
                session.stop()
            }
    }

    private func finish() {
        session.stop()
        onFinish()
    }
}
