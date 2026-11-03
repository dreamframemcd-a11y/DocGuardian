//
//  RootView.swift
//  DocGuardian
//
//  Top-level navigation — shows either Onboarding or the main TabView,
//  and overlays the biometric lock when triggered.
//

import SwiftUI
import CloudKit
import SwiftData

struct RootView: View {

    @EnvironmentObject private var settings: SettingsViewModel
    @Environment(\.cloudKitContainer) private var container
    @Environment(\.modelContext) private var modelContext

    @StateObject private var lock = BiometricLockService.shared
    @StateObject private var listVM: DocumentListViewModel

    init() {
        // Note: We use CKContainer.default() here as a placeholder.
        // The actual container is injected via environment from DocGuardianApp.
        let ck = CloudKitService(container: CKContainer(identifier: "iCloud.com.docguardian.app"))
        _listVM = StateObject(wrappedValue: DocumentListViewModel(cloudKit: ck))
    }

    var body: some View {
        Group {
            if !settings.hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(settings)
            } else {
                MainTabView()
                    .environmentObject(listVM)
            }
        }
        // Propagate the lock service to every descendant — SettingsView reads it
        // via @EnvironmentObject. Without this the app crashes on the Settings tab.
        .environmentObject(lock)
        .overlay {
            if lock.isLocked {
                LockScreenView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Sync model context into listVM for local caching.
            listVM.modelContext = modelContext
            Task { await listVM.load() }
        }
    }
}

// MARK: - Main Tab Bar

struct MainTabView: View {
    @EnvironmentObject var listVM: DocumentListViewModel
    @EnvironmentObject var settings: SettingsViewModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            DocumentListView()
                .tabItem { Label("Library", systemImage: "doc.on.doc") }

            StatsDashboardView()
                .tabItem { Label("Stats", systemImage: "chart.pie.fill") }

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.accentColor)
    }
}

// MARK: - Lock Screen Overlay

struct LockScreenView: View {
    @EnvironmentObject var lock: BiometricLockService

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)
                Text("DocGuardian is locked")
                    .font(.title2)
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
            }
        }
    }
}
