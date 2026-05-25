import SwiftUI

struct RefreshSheetView: View {
    @Bindable var session: RefreshSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBanner
                Divider()
                WebViewRepresentable(webView: session.webView)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Fetching price")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        session.cancel()
                        dismiss()
                    }
                }
            }
        }
        .interactiveDismissDisabled(!session.isCompleted)
        .onChange(of: session.isCompleted) { _, completed in
            guard completed else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(session.hasError ? 1500 : 700))
                dismiss()
            }
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 8) {
            if !session.isCompleted {
                ProgressView()
                    .controlSize(.small)
            } else if session.hasError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Text(session.statusMessage)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
