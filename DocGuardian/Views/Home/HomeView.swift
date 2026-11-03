//
//  HomeView.swift
//  DocGuardian
//
//  Dashboard — Today / upcoming reminders, unresolved count,
//  and a prominent "Scan New Document" button.
//

import SwiftUI

struct HomeView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    @State private var showScan = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    scanButton
                    dueSoonSection
                    statsSection
                }
                .padding()
            }
            .navigationTitle("DocGuardian")
            .sheet(isPresented: $showScan) {
                ScanFlowView()
                    .environmentObject(listVM)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Keep your docs organized.")
                .font(.title2.weight(.semibold))
        }
    }

    private var scanButton: some View {
        Button {
            showScan = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan a Document")
                        .font(.headline)
                    Text("Camera, photos, or Files app")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.accentColor.opacity(0.15), .accentColor.opacity(0.05)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var dueSoonSection: some View {
        let dueSoon = listVM.documents
            .filter { !$0.isResolved && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            .prefix(5)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Due Soon")
                    .font(.headline)
                Spacer()
                NavigationLink("See all") {
                    DocumentListView(initialFilter: .dueSoon)
                        .environmentObject(listVM)
                }
                .font(.subheadline)
            }

            if dueSoon.isEmpty {
                emptyDueSoon
            } else {
                ForEach(Array(dueSoon)) { doc in
                    DueRow(doc: doc)
                }
            }
        }
    }

    private var emptyDueSoon: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Nothing due — you're all caught up!")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statsSection: some View {
        let total = listVM.documents.count
        let unresolved = listVM.documents.filter { !$0.isResolved }.count
        let dueThisMonth = listVM.documents.filter { doc in
            guard let due = doc.dueDate, !doc.isResolved else { return false }
            let cal = Calendar.current
            return cal.isDate(due, equalTo: Date(), toGranularity: .month)
        }.count

        return VStack(alignment: .leading, spacing: 8) {
            Text("This Month")
                .font(.headline)
            HStack(spacing: 12) {
                StatCard(title: "Total", value: "\(total)", color: .blue)
                StatCard(title: "Open", value: "\(unresolved)", color: .orange)
                StatCard(title: "Due", value: "\(dueThisMonth)", color: .red)
            }
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:       return "Good evening"
        }
    }
}

// MARK: - Supporting views

struct DueRow: View {
    let doc: Document

    var body: some View {
        NavigationLink {
            DocumentDetailView(document: doc)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: doc.type.sfSymbol)
                    .foregroundStyle(doc.type.accentColor)
                    .frame(width: 32, height: 32)
                    .background(doc.type.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if let due = doc.dueDate {
                        Text("Due \(dueText(due))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let due = doc.dueDate, isPastDue(due) {
                    Text("OVERDUE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func dueText(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInTomorrow(date) { return "tomorrow" }
        return df.string(from: date)
    }

    private func isPastDue(_ date: Date) -> Bool { date < Date() }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
