//
//  PGPEmailApp.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/9/21.
//
//  Icon Source: https://macosicons.com/u/justaApplenerd
//

import SwiftUI
import UserNotifications

@main
struct PGPEmailApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var model = PGPEmailViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    let readMessage = Storage.retrieve("INBOX.data", as: [Message].self) ?? []
                    var unread = 0
                    for msg in readMessage {
                        if (msg.flags & MCOMessageFlag.seen.rawValue) == 0 {
                            unread += 1
                        }
                    }
                    UIApplication.shared.applicationIconBadgeNumber = unread
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                        UNUserNotificationCenter.current().delegate = self
                    }
                }
            }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        if let userDefaults = UserDefaults(suiteName: "group.com.kevinguan.PGPEmailGroup") {
            userDefaults.set(token, forKey: "apns")
        }
        print("Device Token: \(token)")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let userInfo = response.notification.request.content.userInfo
            if let id = userInfo["uid"] as? Int64 {
                NotificationCenter.default.post(name: Notification.Name("UserClickedNotification"), object: nil, userInfo: ["uid": UInt32(id)])
            }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        guard UIApplication.shared.applicationState == .active else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NotificationCenter.default.post(name: Notification.Name("UserClickedNotification"), object: nil)
        }
    }
}
