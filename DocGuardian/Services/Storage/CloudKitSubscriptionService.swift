//
//  CloudKitSubscriptionService.swift
//  DocGuardian
//
//  Registers a CKQuerySubscription so CloudKit pushes a silent APNs
//  notification whenever a Document record is created/updated/deleted
//  by another device. On receiving the push, we reload the document
//  list to reflect the latest state from iCloud.
//

import Foundation
import Combine
import CloudKit
import UIKit

@MainActor
final class CloudKitSubscriptionService: ObservableObject {

    static let shared = CloudKitSubscriptionService()

    /// DocGuardian's dedicated CloudKit container.
    private let container = CKContainer(identifier: "iCloud.com.docguardian.app")

    private init() {}

    // MARK: - Public lifecycle

    func start() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func handleDeviceToken(_ deviceToken: Data) {
        container.registerForRemoteNotifications(withDeviceToken: deviceToken) { error in
            if let error {
                print("[CK] registerForRemoteNotifications failed: \(error.localizedDescription)")
            } else {
                Task { @MainActor in self.registerDocumentSubscription() }
            }
        }
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any],
                                   completion: @escaping (UIBackgroundFetchResult) -> Void) -> Bool {
        guard let ckInfo = userInfo["ck"] as? [AnyHashable: Any] else {
            completion(.noData)
            return false
        }
        if let subID = ckInfo["sub"] as? String, subID != "docguardian-documents" {
            completion(.noData)
            return false
        }

        NotificationCenter.default.post(name: .cloudKitDidChange, object: nil)
        completion(.newData)
        return true
    }

    // MARK: - Subscription registration

    private func registerDocumentSubscription() async {
        let database = container.privateCloudDatabase

        // 1. Clean up any stale subscriptions from previous installs.
        await unregisterAll(in: database)

        // 2. Register fresh subscription — fires on any Document CRUD.
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: "Document",
            predicate: predicate,
            subscriptionID: "docguardian-documents",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        subscription.notificationInfo = CKSubscription.NotificationInfo()
        subscription.notificationInfo?.shouldSendContentAvailable = true

        do {
            _ = try await database.save(subscription)
            print("[CK] Subscription registered for Document record changes.")
        } catch {
            // User not signed into iCloud / entitlement missing → skip silently.
            print("[CK] Subscription registration failed: \(error.localizedDescription)")
        }
    }

    /// Remove ALL existing subscriptions — ensures we start from a known state.
    private func unregisterAll(in database: CKDatabase) async {
        do {
            let subscriptions = try await database.allSubscriptions()
            for sub in subscriptions {
                try? await database.deleteSubscription(withID: sub.subscriptionID)
            }
        } catch {
            // Not fatal — we'll overwrite if possible.
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let cloudKitDidChange = Notification.Name("DocGuardian.cloudKitDidChange")
}
