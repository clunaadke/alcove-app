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
        later(90) { self.finish(error: "Native splash smoke test timed out") }
        return true
    }

    private func later(_ delay: Double, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }

    // 0909: CI runners have no GPU, so the splash falls back to repainting every
    // pixel on the CPU and one frame can take a few hundred milliseconds. Judging
    // the page once after a fixed sleep makes the whole gate a coin flip, so keep
    // looking until it actually reaches the expected state (or the deadline).
    private func poll(_ timeout: Double, every interval: Double = 0.2,
                      until check: @escaping ([String: Any]) -> Bool,
                      pass: @escaping ([String: Any]) -> Void,
                      fail: @escaping ([String: Any]) -> Void) {
        pollPage(deadline: Date().addingTimeInterval(timeout), interval: interval,
                 check: check, pass: pass, fail: fail)
    }

    private func pollPage(deadline: Date, interval: Double,
                          check: @escaping ([String: Any]) -> Bool,
                          pass: @escaping ([String: Any]) -> Void,
                          fail: @escaping ([String: Any]) -> Void) {
        guard !completed else { return }
        read { state in
            if check(state) { pass(state); return }
            guard Date() < deadline else { fail(state); return }
            self.later(interval) {
                self.pollPage(deadline: deadline, interval: interval,
                              check: check, pass: pass, fail: fail)
            }
        }
    }

    private func pollNative(_ timeout: Double, every interval: Double = 0.2,
                            until check: @escaping () -> Bool,
                            pass: @escaping () -> Void,
                            fail: @escaping () -> Void) {
        pollSelf(deadline: Date().addingTimeInterval(timeout), interval: interval,
                 check: check, pass: pass, fail: fail)
    }

    private func pollSelf(deadline: Date, interval: Double,
                          check: @escaping () -> Bool,
                          pass: @escaping () -> Void,
                          fail: @escaping () -> Void) {
        guard !completed else { return }
        if check() { pass(); return }
        guard Date() < deadline else { fail(); return }
        later(interval) {
            self.pollSelf(deadline: deadline, interval: interval,
                          check: check, pass: pass, fail: fail)
        }
    }

    private func findWeb(_ view: UIView) -> WKWebView? {
        if let web = view as? WKWebView { return web }
        return view.subviews.compactMap(findWeb).first
    }

    private func findArtwork(attempt: Int) {
        guard !completed else { return }
        web = window.flatMap { findWeb($0) }
        read { state in
            // 0909: GitHub's macOS runner has no display, so the simulator cannot
            // hand WebKit a WebGL context and the page drops to its 2D canvas
            // fallback on purpose. The animation still runs, so accept any renderer
            // the page actually settled on and record which one CI used.
            let renderer = state["renderer"] as? String ?? ""
            guard ["webgl", "canvas", "fallback"].contains(renderer),
                  Int(state["frame"] as? String ?? "0") ?? 0 > 2 else {
                if attempt < 25 { self.later(1) { self.findArtwork(attempt: attempt + 1) } }
                else { self.finish(error: "Artwork never started: \(state)") }
                return
            }
            self.checks["renderer"] = renderer
            guard state["active"] as? String == "true", state["quoteCount"] as? String == "7", self.entryCount == 0 else {
                self.finish(error: "Incorrect initial native state: \(state)"); return
            }
            self.checks["initial"] = state
            let frame = Int(state["frame"] as? String ?? "0") ?? 0
            self.poll(8, until: { (Int($0["frame"] as? String ?? "0") ?? 0) > frame }, pass: { _ in
                self.checks["nativeAnimationAdvances"] = true
                self.swipe()
            }, fail: { last in
                self.finish(error: "Visible artwork is frozen: \(last)")
            })
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
            self.poll(8, until: {
                (Int($0["swipes"] as? String ?? "0") ?? 0) == 30
                    && (Int($0["clearedPixels"] as? String ?? "0") ?? 0) > 100
            }, pass: { state in
                self.checks["swipe"] = state
                self.snapshot()
            }, fail: { state in
                self.finish(error: "Swipe did not clear the fog: \(state)")
            })
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
        // Wait for the page to acknowledge the pause instead of assuming 0.2s is enough.
        poll(5, until: { $0["active"] as? String == "false" }, pass: { paused in
            // Proving the artwork is *stopped* needs a real gap, so this one wait stays fixed.
            self.later(0.5) {
                self.read { still in
                    guard still["active"] as? String == "false",
                          still["frame"] as? String == paused["frame"] as? String else {
                        self.finish(error: "Native inactive notification did not pause artwork: \(still)"); return
                    }
                    self.resumeArtwork(from: still)
                }
            }
        }, fail: { state in
            self.finish(error: "Native inactive notification did not pause artwork: \(state)")
        })
    }

    private func resumeArtwork(from still: [String: Any]) {
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: UIApplication.shared)
        poll(10, until: {
            $0["active"] as? String == "true" && $0["frame"] as? String != still["frame"] as? String
        }, pass: { _ in
            self.checks["nativePauseAndResume"] = true
            self.pressEnterTwice()
        }, fail: { state in
            self.finish(error: "Native activation did not resume artwork: \(state)")
        })
    }

    private func pressEnterTwice() {
        web?.evaluateJavaScript("document.querySelector('.alw-enter').click();document.querySelector('.alw-enter').click();") { _, error in
            if let error { self.finish(error: "Enter click failed: \(error)"); return }
            self.pollNative(5, until: { self.entryCount >= 1 }, pass: {
                // Both clicks were dispatched together; hold briefly to catch a second bridge.
                self.later(0.5) {
                    guard self.entryCount == 1 else {
                        self.finish(error: "Enter did not bridge exactly once: \(self.entryCount)"); return
                    }
                    self.checks["entryOnce"] = true
                    self.finish(error: nil)
                }
            }, fail: {
                self.finish(error: "Enter never bridged to native")
            })
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
