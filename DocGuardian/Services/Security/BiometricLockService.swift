//
//  BiometricLockService.swift
//  DocGuardian
//
//  Wraps LocalAuthentication (Face ID / Touch ID) and manages the
//  "lock on background" behavior. Triggers are wired from SceneDelegate.
//

import Foundation
import LocalAuthentication

@MainActor
final class BiometricLockService: ObservableObject {

    static let shared = BiometricLockService()

    @Published private(set) var isLocked: Bool = false
    @Published var isEnabled: Bool = false {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "docguardian.lockEnabled") }
    }

    private let context = LAContext()

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "docguardian.lockEnabled")

        NotificationCenter.default.addObserver(
            forName: .appDidEnterBackground, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isEnabled else { return }
            self.isLocked = true
        }
    }

    /// Attempt to unlock via biometrics. Returns true on success.
    func unlock(reason: String = "Authenticate to access DocGuardian") async -> Bool {
        guard isLocked else { return true }

        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
                if success { isLocked = false }
                return success
            } catch {
                return false
            }
        }
        return false
    }
}
