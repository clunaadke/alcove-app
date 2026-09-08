import SwiftUI
import WebKit

/// Runs the approved artwork itself, including its fonts and water renderer.
/// The local page only emits `enter`; it has no access to chat or network APIs.
struct SplashView: View {
    let onEnter: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadFailed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                Image("MistLaunch")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                MistSplashWebView(
                    isActive: scenePhase == .active,
                    onEnter: onEnter,
                    onFailure: { loadFailed = true }
                )
                if loadFailed {
                    // Never auto-dismiss, even when WebKit cannot load the artwork.
                    Button(action: onEnter) {
                        Text("Enter")
                            .font(.system(size: 10, weight: .light, design: .serif))
                            .foregroundStyle(.white)
                            .frame(width: 62, height: 48)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("进入 Alcove")
                    .padding(.trailing, 24)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 34) + 12)
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct MistSplashWebView: UIViewRepresentable {
    let isActive: Bool
    let onEnter: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onEnter: onEnter, onFailure: onFailure)
    }

    func makeUIView(context: Context) -> MistWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "alcoveSplash")
        let webView = MistWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.underPageBackgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        webView.isArtworkActive = isActive
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "MistSplash") {
            context.coordinator.resourceDirectory = url.deletingLastPathComponent()
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            DispatchQueue.main.async { onFailure() }
        }
        return webView
    }

    func updateUIView(_ webView: MistWebView, context: Context) {
        context.coordinator.onEnter = onEnter
        context.coordinator.onFailure = onFailure
        if webView.isArtworkActive != isActive {
            webView.isArtworkActive = isActive
            webView.updateArtworkEnvironment()
        }
    }

    static func dismantleUIView(_ webView: MistWebView, coordinator: Coordinator) {
        webView.evaluateJavaScript("window.alcoveSplashStop && window.alcoveSplashStop()", completionHandler: nil)
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "alcoveSplash")
        webView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onEnter: () -> Void
        var onFailure: () -> Void
        var resourceDirectory: URL?
        private var didEnter = false
        private var recoveredProcess = false

        init(onEnter: @escaping () -> Void, onFailure: @escaping () -> Void) {
            self.onEnter = onEnter
            self.onFailure = onFailure
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "alcoveSplash", message.frameInfo.isMainFrame,
                  let action = message.body as? String else { return }
            if action == "failed" { onFailure(); return }
            guard action == "enter", !didEnter else { return }
            didEnter = true
            onEnter()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            (webView as? MistWebView)?.updateArtworkEnvironment()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, url.isFileURL,
                  let directory = resourceDirectory,
                  url.standardizedFileURL.path.hasPrefix(directory.standardizedFileURL.path + "/") else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { onFailure() }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { onFailure() }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard !didEnter else { return }
            if !recoveredProcess {
                recoveredProcess = true
                webView.reload()
            } else {
                onFailure()
            }
        }
    }
}

private final class MistWebView: WKWebView {
    var isArtworkActive = true

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        updateArtworkEnvironment()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateArtworkEnvironment()
    }

    func updateArtworkEnvironment() {
        let insets = window?.safeAreaInsets ?? safeAreaInsets
        let payload: [String: Any] = [
            "active": isArtworkActive,
            "top": insets.top, "bottom": insets.bottom,
            "left": insets.left, "right": insets.right
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        evaluateJavaScript("window.alcoveSplashEnvironment && window.alcoveSplashEnvironment(\(json))", completionHandler: nil)
    }
}
