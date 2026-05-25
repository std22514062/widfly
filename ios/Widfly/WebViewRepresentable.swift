import SwiftUI
import WebKit

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView.isHidden = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
