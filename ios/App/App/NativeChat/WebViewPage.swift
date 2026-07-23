import SwiftUI
import WebKit

// 其余功能页第一版仍走 PWA，用 WKWebView 兜底
struct WebViewPage: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .automatic
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
