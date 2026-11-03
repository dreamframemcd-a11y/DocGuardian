//
//  OnboardingView.swift
//  DocGuardian
//
//  3-step intro shown only on first launch.
//  Tap-through leads to HomeView and flips the "hasCompletedOnboarding" flag.
//

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "camera.viewfinder",
            title: "Scan anything paper",
            subtitle: "Point your iPhone at bills, receipts, IDs, contracts — DocGuardian auto-detects edges and captures crisp multi-page scans."
        ),
        OnboardingPage(
            icon: "sparkles.rectangle.stack",
            title: "AI organizes automatically",
            subtitle: "Documents are classified, key fields extracted, and filed into folders — all on device, all private."
        ),
        OnboardingPage(
            icon: "bell.badge",
            title: "Never miss a deadline",
            subtitle: "DocGuardian reads due dates and reminds you 3 days, 1 day, and the morning before. Pay, file, and move on."
        ),
    ]

    var body: some View {
        VStack {
            Spacer()
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                    pageView(page: p)
                        .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Spacer()

            HStack {
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if page < pages.count - 1 {
                    Button("Next") { withAnimation { page += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        settings.hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    private func pageView(page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .padding()
                .background(Color.accentColor.opacity(0.15), in: Circle())

            Text(page.title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}
