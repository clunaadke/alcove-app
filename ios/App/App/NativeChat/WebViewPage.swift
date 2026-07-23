import SwiftUI
import WebKit

// 常驻共享 WebView：app 启动就后台加载 PWA，按钮点开秒进对应页面，
// 大厅/清单/音乐/终端这些功能全部走原页面本体，一个不少
final class WebHouse: NSObject, WKNavigationDelegate {
    static let shared = WebHouse()

    let webView: WKWebView
    private var loaded = false
    private var pendingJS: [String] = []

    override private init() {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: cfg)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        super.init()
        webView.navigationDelegate = self
        webView.load(URLRequest(url: AlcoveAPI.base))
    }

    func warmUp() { _ = webView } // 触发懒加载

    func run(_ js: String) {
        if loaded {
            webView.evaluateJavaScript(js, completionHandler: nil)
        } else {
            pendingJS.append(js)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        for js in pendingJS { webView.evaluateJavaScript(js, completionHandler: nil) }
        pendingJS.removeAll()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loaded = false
    }

    func reloadIfNeeded() {
        if webView.url == nil || !loaded {
            loaded = false
            webView.load(URLRequest(url: AlcoveAPI.base))
        }
    }
}

// 把共享 WebView 挂进 SwiftUI 视图树
struct HouseWebView: UIViewRepresentable {
    let onPresentJS: String?

    func makeUIView(context: Context) -> WKWebView {
        let house = WebHouse.shared
        house.reloadIfNeeded()
        if let js = onPresentJS { house.run(js) }
        return house.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// 全屏打开某个 PWA 页面（present 时执行跳转 JS）
struct HousePage: View {
    let js: String?
    var dismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            HouseWebView(onPresentJS: js)
                .ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(red: 0.42, green: 0.40, blue: 0.41))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color(red: 210/255, green: 210/255, blue: 218/255).opacity(0.3), lineWidth: 1))
            }
            .padding(.leading, 14)
            .padding(.top, 6)
        }
    }
}
