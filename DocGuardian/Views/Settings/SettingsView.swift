//
//  SettingsView.swift
//  DocGuardian
//
//  User-facing preferences: appearance, notifications, biometric lock,
//  data management, and about/help.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var settings: SettingsViewModel
    @EnvironmentObject var listVM: DocumentListViewModel
    @EnvironmentObject private var lock: BiometricLockService
    @State private var showDeleteAll = false

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                notificationsSection
                securitySection
                dataSection
                organizationSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $settings.colorSchemeMode) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable reminders", isOn: $settings.notificationsEnabled)
                .onChange(of: settings.notificationsEnabled) { newValue in
                    if newValue { settings.requestNotificationPermission() }
                }
            if settings.notificationsEnabled {
                HStack {
                    Text("Reminder timing")
                    Spacer()
                    Text("3d · 1d · day of")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section("Privacy & Security") {
            Toggle("Face ID / Touch ID lock", isOn: $settings.lockEnabled)
                .onChange(of: settings.lockEnabled) { newValue in
                    lock.isEnabled = newValue
                }
            if settings.lockEnabled {
                Text("DocGuardian will require authentication after you switch away.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            HStack {
                Text("Documents synced")
                Spacer()
                Text("\(listVM.documents.count)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("iCloud status")
                Spacer()
                Label("Syncing", systemImage: "icloud.and.arrow.up.fill")
                    .foregroundStyle(.secondary)
            }
            Button { showDeleteAll = true } label: {
                Text("Delete all documents")
                    .foregroundStyle(.red)
            }
        }
        .confirmationDialog("Delete ALL documents?", isPresented: $showDeleteAll, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) {
                // Iterate copy to avoid mutation-during-iteration.
                let copy = listVM.documents
                Task {
                    for doc in copy { try? await listVM.delete(doc) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every document from your device and iCloud. This cannot be undone.")
        }
    }

    // MARK: - Organization

    private var organizationSection: some View {
        Section("Organization") {
            NavigationLink {
                TagManagementView().environmentObject(listVM)
            } label: {
                Label("Manage Tags", systemImage: "tag.fill")
            }
            NavigationLink {
                StatsDashboardView().environmentObject(listVM)
            } label: {
                Label("Monthly Overview", systemImage: "chart.pie")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0 (1)").foregroundStyle(.secondary)
            }
            NavigationLink {
                HelpFeedbackView()
            } label: {
                Label("Help & Feedback", systemImage: "questionmark.circle")
            }
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Text("Privacy Policy")
            }
            Link("Support", destination: URL(string: "https://example.com/docguardian/support")!)
                .foregroundStyle(.accentColor)
        }
    }
}

// MARK: - Privacy (minimal)

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("DocGuardian Privacy Policy")
                    .font(.title2.weight(.semibold))
                Text("Last updated: November 3, 2026")
                    .font(.caption).foregroundStyle(.secondary)

                Text("""
                DocGuardian processes your documents primarily on-device. \
                Text recognition, classification, and field extraction all happen locally \
                using Apple's Vision framework — nothing is sent to a third-party AI service.

                Your documents are stored in iCloud using CloudKit, encrypted in transit \
                and at rest by Apple. Only you can access them using your Apple ID.

                DocGuardian does not collect analytics, sell your data, or share your \
                documents with any partner services.

                For questions, contact: support@docguardian.app
                """)
                .font(.body)
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
