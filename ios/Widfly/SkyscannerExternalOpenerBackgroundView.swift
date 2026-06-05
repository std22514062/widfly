import SwiftUI

struct SkyscannerExternalOpenerBackgroundView: View {
    @Bindable var session: SkyscannerDetailSession
    let onResolved: (URL) -> Void
    let onFailure: () -> Void
    let onFinish: () -> Void

    @Environment(\.openURL) private var openURL
    @State private var didStart = false

    var body: some View {
        WebViewRepresentable(webView: session.webView)
            .frame(width: 1, height: 1)
            .opacity(0)
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
            .onChange(of: session.didFail) { _, failed in
                guard failed else { return }
                onFailure()
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
