//
//  ReminderService.swift
//  DocGuardian
//
//  Manages UNUserNotificationCenter reminders for document due dates.
//  Default rule: fire at 3 days, 1 day, and 0 days (morning) before due date.
//

import Foundation
import UserNotifications

final class ReminderService {

    static let shared = ReminderService()
    private init() {}

    /// Default offsets (in days before due date) when reminders fire.
    static let defaultOffsets: [Int] = [3, 1, 0]

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Schedule / cancel

    /// Schedule (or re-schedule) reminders for one document's due date.
    /// Cancels any previous reminders for this document first.
    func scheduleReminders(for documentID: UUID, dueDate: Date?, title: String, issuer: String?) {
        cancelReminders(for: documentID)
        guard let dueDate, !title.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        let issuer = issuer ?? "DocGuardian"

        for offsetDays in Self.defaultOffsets {
            let reminderDate = Calendar.current.date(byAdding: .day, value: -offsetDays, to: dueDate) ?? dueDate
            let nextMorning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: reminderDate) ?? reminderDate

            // Skip if already passed.
            guard nextMorning > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = offsetDays == 0
                ? "\(issuer) — Due Today"
                : "\(issuer) — Due in \(offsetDays) day\(offsetDays == 1 ? "" : "s")"
            content.body = title
            content.sound = .default
            content.badge = 1
            content.userInfo = ["documentID": documentID.uuidString]

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextMorning)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: reminderID(documentID: documentID, offsetDays: offsetDays),
                content: content,
                trigger: trigger
            )
            center.add(request, withCompletionHandler: nil)
        }
    }

    func cancelReminders(for documentID: UUID) {
        let center = UNUserNotificationCenter.current()
        let identifiers = Self.defaultOffsets.map { reminderID(documentID: documentID, offsetDays: $0) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Bulk resync (call after settings change / device reboot)

    /// Cancel all DocGuardian notifications and reschedule from scratch.
    func resyncAll(with documents: [Document]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for doc in documents where !doc.isResolved {
            scheduleReminders(for: doc.id, dueDate: doc.dueDate, title: doc.title, issuer: doc.issuer)
        }
    }

    // MARK: - Private

    private func reminderID(documentID: UUID, offsetDays: Int) -> String {
        "doc-\(documentID.uuidString)-\(offsetDays)"
    }
}
