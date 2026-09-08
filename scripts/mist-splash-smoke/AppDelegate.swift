import UIKit
import SwiftUI
import WebKit

// Exercise the production wrapper in Alcove's actual legacy UIKit lifecycle.
// A JavaScript-only test cannot catch a permanently inactive scenePhase.
@UIApplicationMain
final class SmokeDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var web: WKWebView?
    private var entryCount = 0
    private var completed = false
    private var checks: [String: Any] = [:]

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = UIHostingController(rootView: SplashView(onEnter: { self.entryCount += 1 }))
        window = win
        win.makeKeyAndVisible()
        later(2) { self.findArtwork(attempt: 0) }
        later(35) { self.finish(error: "Native splash smoke test timed out") }
        return true
    }

    private func later(_ delay: Double, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }

    private func findWeb(_ view: UIView) -> WKWebView? {
        if let web = view as? WKWebView { return web }
        return view.subviews.compactMap(findWeb).first
    }

    private func findArtwork(attempt: Int) {
        guard !completed else { return }
        web = window.flatMap { findWeb($0) }
        read { state in
            guard state["renderer"] as? String == "webgl", Int(state["frame"] as? String ?? "0") ?? 0 > 2 else {
                if attempt < 15 { self.later(1) { self.findArtwork(attempt: attempt + 1) } }
                else { self.finish(error: "WebGL never started: \(state)") }
                return
            }
            guard state["active"] as? String == "true", state["quoteCount"] as? String == "7", self.entryCount == 0 else {
                self.finish(error: "Incorrect initial native state: \(state)"); return
            }
            self.checks["initial"] = state
            let frame = Int(state["frame"] as? String ?? "0") ?? 0
            self.later(1) {
                self.read { moving in
                    guard (Int(moving["frame"] as? String ?? "0") ?? 0) > frame else {
                        self.finish(error: "Visible artwork is frozen"); return
                    }
                    self.checks["nativeAnimationAdvances"] = true
                    self.swipe()
                }
            }
        }
    }

    private func read(_ completion: @escaping ([String: Any]) -> Void) {
        guard let web else { completion([:]); return }
        web.evaluateJavaScript("JSON.stringify(document.getElementById('alcove-living-water').dataset)") { value, error in
            guard error == nil, let string = value as? String, let data = string.data(using: .utf8),
                  let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion([:]); return
            }
            completion(state)
        }
    }

    private func swipe() {
        web?.evaluateJavaScript("""
        (()=>{const c=document.querySelector('canvas'),r=c.getBoundingClientRect();
        const send=(type,x,y)=>c.dispatchEvent(new PointerEvent(type,{pointerId:7,pointerType:'touch',bubbles:true,clientX:x,clientY:y,buttons:type==='pointerup'?0:1}));
        send('pointerdown',r.width*.15,r.height*.45);
        for(let i=1;i<=30;i++)send('pointermove',r.width*(.15+.7*i/30),r.height*(.45-.07*i/30));
        send('pointerup',r.width*.85,r.height*.38);return true})()
        """) { _, error in
            if let error { self.finish(error: "Swipe failed: \(error)"); return }
            self.later(0.3) {
                self.read { state in
                    guard (Int(state["swipes"] as? String ?? "0") ?? 0) == 30,
                          (Int(state["clearedPixels"] as? String ?? "0") ?? 0) > 100 else {
                        self.finish(error: "Swipe did not clear the fog: \(state)"); return
                    }
                    self.checks["swipe"] = state
                    self.snapshot()
                }
            }
        }
    }

    private func snapshot() {
        web?.takeSnapshot(with: nil) { image, error in
            if let data = image?.pngData() {
                try? data.write(to: self.documents.appendingPathComponent("mist-after-swipe.png"))
            }
            self.pauseAndResume()
        }
    }

    private func pauseAndResume() {
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: UIApplication.shared)
        later(0.2) {
            self.read { paused in
                self.later(0.3) {
                    self.read { still in
                        guard still["active"] as? String == "false", still["frame"] as? String == paused["frame"] as? String else {
                            self.finish(error: "Native inactive notification did not pause artwork"); return
                        }
                        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: UIApplication.shared)
                        self.later(0.4) {
                            self.read { resumed in
                                guard resumed["active"] as? String == "true", resumed["frame"] as? String != still["frame"] as? String else {
                                    self.finish(error: "Native activation did not resume artwork"); return
                                }
                                self.checks["nativePauseAndResume"] = true
                                self.web?.evaluateJavaScript("document.querySelector('.alw-enter').click();document.querySelector('.alw-enter').click();") { _, _ in
                                    self.later(0.2) {
                                        guard self.entryCount == 1 else { self.finish(error: "Enter did not bridge exactly once"); return }
                                        self.checks["entryOnce"] = true
                                        self.finish(error: nil)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private func finish(error: String?) {
        guard !completed else { return }
        completed = true
        checks["success"] = error == nil
        if let error { checks["error"] = error }
        if let data = try? JSONSerialization.data(withJSONObject: checks, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: documents.appendingPathComponent("result.json"), options: .atomic)
        }
    }
}
