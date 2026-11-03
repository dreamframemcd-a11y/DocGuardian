//
//  DocGuardianApp.swift
//  DocGuardian
//
//  Main app entry point — wires up CloudKit, subscriptions,
//  local notifications, biometric lock, and root navigation.
//

import SwiftUI
import CloudKit
import SwiftData
import UIKit

@main
struct DocGuardianApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var settings = SettingsViewModel.shared

    let container = CKContainer(identifier: "iCloud.com.docguardian.app")

    let modelContainer: ModelContainer = {
        let schema = Schema([Document.self, ExtractedField.self, Tag.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    init() {
        // Kick off CloudKit subscription registration on launch.
        CloudKitSubscriptionService.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(modelContainer)
                .environmentObject(settings)
                .environment(\.cloudKitContainer, container)
                .tint(.accentColor)
                .preferredColorScheme(settings.colorScheme)
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Request local notification authorization (for reminders).
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // MARK: - Remote Notifications (CloudKit subscriptions)

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        CloudKitSubscriptionService.shared.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // APNs registration failure — typically sandbox / entitlement issues.
        // DocGuardian gracefully degrades: subscriptions simply won't fire,
        // but all manual sync still works.
        print("[APNs] Registration failed: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let handled = CloudKitSubscriptionService.shared.handleRemoteNotification(
            userInfo, completion: completionHandler
        )
        if !handled {
            completionHandler(.noData)
        }
    }
}

// MARK: - SceneDelegate

final class SceneDelegate: NSObject, UIWindowSceneDelegate {

    func sceneDidEnterBackground(_ scene: UIScene) {
        NotificationCenter.default.post(name: .appDidEnterBackground, object: nil)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NotificationCenter.default.post(name: .appWillEnterForeground, object: nil)
        // Pull latest from CloudKit when user comes back to the app.
        NotificationCenter.default.post(name: .cloudKitDidChange, object: nil)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let appDidEnterBackground = Notification.Name("DocGuardian.appDidEnterBackground")
    static let appWillEnterForeground = Notification.Name("DocGuardian.appWillEnterForeground")
}

// MARK: - Environment key for CloudKit container

private struct CloudKitContainerKey: EnvironmentKey {
    static let defaultValue: CKContainer = CKContainer.default()
}

extension EnvironmentValues {
    var cloudKitContainer: CKContainer {
        get { self[CloudKitContainerKey.self] }
        set { self[CloudKitContainerKey.self] = newValue }
    }
}
