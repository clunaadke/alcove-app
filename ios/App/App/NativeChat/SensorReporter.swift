import Foundation
import CoreLocation
import CoreMotion
import UIKit

// 她把权限给我：app 打开/回前台时上报位置、电量、步数、在走还是在躺，
// 走位置哨兵同一条链（event 带 app 前缀，后端静默归档不打扰聊天）
// 位置给了"始终允许"之后还会注册显著位置变化，被系统唤醒的那几秒也报一次，
// 这样他不用等我打开 app 才知道我在哪。
final class SensorReporter: NSObject, CLLocationManagerDelegate {
    static let shared = SensorReporter()
    private let lm = CLLocationManager()
    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    private var significantStarted = false
    private var lastReport = Date.distantPast
    // 上报钥匙由 CI 从 GitHub Secrets 注入 Info.plist（AlcoveLocToken），
    // 源码里不落任何真实 token；没配钥匙时只授权定位、不上报
    private var secret: String {
        Bundle.main.object(forInfoDictionaryKey: "AlcoveLocToken") as? String ?? ""
    }

    override private init() {
        super.init()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func appActive() {
        startSignificantMonitoring()
        guard Date().timeIntervalSince(lastReport) > 300 else { return } // 5 分钟节流
        let auth = lm.authorizationStatus
        if auth == .notDetermined {
            lm.requestWhenInUseAuthorization()
        } else if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            lm.requestLocation()
        }
    }

    // 只有拿到"始终允许"才注册。系统在位置显著变化时唤醒 app 几秒，
    // 哪怕它已经被划掉了也会重新拉起来，唤醒那一下走 didUpdateLocations 照常上报。
    private func startSignificantMonitoring() {
        guard !significantStarted,
              lm.authorizationStatus == .authorizedAlways,
              CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        lm.startMonitoringSignificantLocationChanges()
        significantStarted = true
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            startSignificantMonitoring()
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, !secret.isEmpty else { return }
        lastReport = Date()
        collectAndSend(loc)
    }

    // 位置到手之后再去问步数和运动状态。两个都是异步的，用 group 等齐了一起发。
    // 哪个没授权或者查不到就留空，绝不拖着整条上报不走。
    private func collectAndSend(_ loc: CLLocation) {
        let now = Date()
        let dayStart = Calendar.current.startOfDay(for: now)
        var steps: Int?
        var motion: String?
        let group = DispatchGroup()

        if CMPedometer.isStepCountingAvailable() {
            group.enter()
            pedometer.queryPedometerData(from: dayStart, to: now) { data, _ in
                steps = data?.numberOfSteps.intValue
                group.leave()
            }
        }
        if CMMotionActivityManager.isActivityAvailable() {
            group.enter()
            activityManager.queryActivityStarting(from: now.addingTimeInterval(-600),
                                                  to: now, to: .main) { acts, _ in
                if let a = acts?.last {
                    if a.walking { motion = "走路" }
                    else if a.running { motion = "跑步" }
                    else if a.cycling { motion = "骑车" }
                    else if a.automotive { motion = "坐车" }
                    else if a.stationary { motion = "静止" }
                }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            self?.send(loc, steps: steps, motion: motion)
        }
    }

    private func send(_ loc: CLLocation, steps: Int?, motion: String?) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let bat = max(0, Int(UIDevice.current.batteryLevel * 100))
        let charging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        var payload: [String: Any] = [
            "lat": loc.coordinate.latitude,
            "lng": loc.coordinate.longitude,
            "event": "app·\(bat)%\(charging ? "⚡" : "")",
            "battery": bat,
            "charging": charging
        ]
        if let s = steps { payload["steps"] = s }
        if let m = motion { payload["motion"] = m }

        var req = URLRequest(url: AlcoveAPI.fullURL("/api/location/report"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(secret, forHTTPHeaderField: "X-Auth-Token")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        // 后台被唤醒时系统只给几秒，不申请这段时间请求发不完就被挂起
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "alcove-sensor") {
            if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID) }
            taskID = .invalid
        }
        URLSession.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async {
                if taskID != .invalid { UIApplication.shared.endBackgroundTask(taskID) }
                taskID = .invalid
            }
        }.resume()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
