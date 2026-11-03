//
//  HelpFeedbackView.swift
//  DocGuardian
//
//  In-app FAQ and feedback form.
//

import SwiftUI
import MessageUI

struct HelpFeedbackView: View {

    var body: some View {
        NavigationStack {
            List {
                Section("Frequently Asked") {
                    faqRow(q: "How does DocGuardian recognize my documents?",
                           a: "Everything runs on your device using Apple's Vision framework — no third-party AI sees your data. After OCR, DocGuardian applies a set of rules (keywords, patterns) to classify each document and extract fields like amount and due date.")
                    faqRow(q: "Where are my documents stored?",
                           a: "Documents are stored in iCloud via CloudKit, encrypted in transit and at rest by Apple. They're also cached locally via SwiftData for offline access. Only you can see them.")
                    faqRow(q: "Can I use DocGuardian without iCloud?",
                           a: "DocGuardian requires an iCloud account for sync. If you're not signed into iCloud on your device, CloudKit will prompt you the first time you try to save a document.")
                    faqRow(q: "What document types do you recognize?",
                           a: "Bills & invoices, medical EOBs, insurance policies, tax forms (W-2, 1099, 1040), contracts, IDs, receipts, and product warranties. The classifier is fully local and you can manually change the category on any document.")
                    faqRow(q: "How do I stop reminders?",
                           a: "Open a document → tap 'Mark as Paid' on the detail screen. Resolved documents won't trigger reminders. You can also disable notifications in Settings.")
                    faqRow(q: "Is my Face ID stored anywhere?",
                           a: "No. DocGuardian uses Apple's LocalAuthentication framework which never shares biometric data with apps. The biometric check is handled entirely by Secure Enclave.")
                }

                Section("Send Feedback") {
                    Link(destination: URL(string: "mailto:support@docguardian.app")!) {
                        Label("Email support@docguardian.app", systemImage: "envelope")
                    }
                    Link(destination: URL(string: "https://example.com/docguardian/support")!) {
                        Label("Visit our support site", systemImage: "globe")
                    }
                }

                Section("Privacy") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Read our privacy policy", systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle("Help & Feedback")
        }
    }

    @ViewBuilder
    private func faqRow(q: String, a: String) -> some View {
        DisclosureGroup(q) {
            Text(a)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }
}
