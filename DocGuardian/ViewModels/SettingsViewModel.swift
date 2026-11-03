//
//  SettingsViewModel.swift
//  DocGuardian
//
//  App-wide settings shared via @EnvironmentObject.
//  Uses UserDefaults for persistence — perfect for lightweight preferences.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    static let shared = SettingsViewModel()

    // MARK: - Appearance

    @Published var colorSchemeMode: Int = 0 {   // 0 = system, 1 = light, 2 = dark
        didSet {
            UserDefaults.standard.set(colorSchemeMode, forKey: "docguardian.colorScheme")
            objectWillChange.send()
        }
    }

    var colorScheme: ColorScheme? {
        switch colorSchemeMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    // MARK: - Notifications

    @Published var notificationsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "docguardian.notificationsEnabled") }
    }

    // MARK: - Lock

    @Published var lockEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(lockEnabled, forKey: "docguardian.lockEnabled")
            Task { @MainActor in BiometricLockService.shared.isEnabled = lockEnabled }
        }
    }

    // MARK: - Onboarding

    @Published var hasCompletedOnboarding: Bool = false {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "docguardian.onboardingDone") }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard
        self.colorSchemeMode      = defaults.object(forKey: "docguardian.colorScheme") as? Int ?? 0
        self.notificationsEnabled = defaults.object(forKey: "docguardian.notificationsEnabled") as? Bool ?? true
        self.lockEnabled          = defaults.object(forKey: "docguardian.lockEnabled") as? Bool ?? false
        self.hasCompletedOnboarding = defaults.object(forKey: "docguardian.onboardingDone") as? Bool ?? false
    }

    // MARK: - Convenience

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.notificationsEnabled = granted
            }
        }
    }
}
