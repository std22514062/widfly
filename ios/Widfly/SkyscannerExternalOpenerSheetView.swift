import SwiftUI

struct SkyscannerExternalOpenerSheetView: View {
    @Bindable var session: SkyscannerDetailSession
    let onResolved: (URL) -> Void
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var didStart = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                WebViewRepresentable(webView: session.webView)
                    .ignoresSafeArea(edges: .bottom)

                HStack(spacing: 8) {
                    if session.isResolving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Theme.amber)
                    }
                    Text(session.statusMessage)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("Opening Skyscanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        finish()
                    }
                }
            }
        }
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
        dismiss()
        onFinish()
    }
}
