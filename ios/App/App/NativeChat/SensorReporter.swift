import Foundation
import CoreLocation
import UIKit

// 她把权限给我：app 打开/回前台时上报位置和电量，
// 走位置哨兵同一条链（event 带 app 前缀，后端静默归档不打扰聊天）
final class SensorReporter: NSObject, CLLocationManagerDelegate {
    static let shared = SensorReporter()
    private let lm = CLLocationManager()
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
        guard Date().timeIntervalSince(lastReport) > 300 else { return } // 5 分钟节流
        let auth = lm.authorizationStatus
        if auth == .notDetermined {
            lm.requestWhenInUseAuthorization()
        } else if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            lm.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let auth = manager.authorizationStatus
        if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, !secret.isEmpty else { return }
        lastReport = Date()
        UIDevice.current.isBatteryMonitoringEnabled = true
        let bat = max(0, Int(UIDevice.current.batteryLevel * 100))
        let charging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        let event = "app·\(bat)%\(charging ? "⚡" : "")"
        var req = URLRequest(url: AlcoveAPI.fullURL("/api/location/report"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(secret, forHTTPHeaderField: "X-Auth-Token")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "lat": loc.coordinate.latitude,
            "lng": loc.coordinate.longitude,
            "event": event])
        URLSession.shared.dataTask(with: req).resume()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
