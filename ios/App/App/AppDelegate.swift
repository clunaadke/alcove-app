import UIKit
import SwiftUI
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 0827 一个按钮管全屋：旧的“跟随系统”在这里落定成白天或黑夜，
        // 之后全 app 只认 houseInterfaceAppearance 这一个值。
        AlcoveAppearance.migrate(systemDark: UITraitCollection.current.userInterfaceStyle == .dark)

        // SwiftUI 原生聊天页接管根视图；其余页面走常驻 WebHouse WebView
        let win = UIWindow(frame: UIScreen.main.bounds)
        let host = UIHostingController(rootView: RootView())
        // 深浅由 RootView 按 PWA 主题设置，不在这里锁死
        host.view.backgroundColor = .clear
        win.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
        win.rootViewController = host
        win.makeKeyAndVisible()
        window = win
        // 显著位置变化会把已经被划掉的 app 重新拉起来，
        // 那一下必须让 SensorReporter 先活过来把 delegate 挂上，否则回调没人接
        _ = SensorReporter.shared
        if launchOptions?[.location] != nil {
            SensorReporter.shared.appActive()
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

}
