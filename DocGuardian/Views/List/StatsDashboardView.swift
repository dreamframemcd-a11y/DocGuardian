//
//  StatsDashboardView.swift
//  DocGuardian
//
//  Monthly overview dashboard with category breakdown and totals.
//  A lightweight, all-SwiftUI implementation (no charting dependencies).
//

import SwiftUI

struct StatsDashboardView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    @State private var selectedMonth: Date = Date()

    private let df: DateFormatter = {
        let d = DateFormatter()
        d.dateFormat = "MMMM yyyy"
        return d
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthPicker
                    totalCards
                    categoryBreakdown
                }
                .padding()
            }
            .navigationTitle("Monthly Overview")
        }
    }

    // MARK: - Components

    private var stats: DocumentListViewModel.MonthlyStats {
        listVM.monthlyStats(for: selectedMonth)
    }

    private var monthPicker: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(df.string(from: selectedMonth))
                .font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var totalCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(title: "Total", value: "\(stats.totalCount)", color: .blue)
                StatCard(title: "Open", value: "\(stats.unresolvedCount)", color: .orange)
            }
            HStack(spacing: 12) {
                StatCard(title: "This month",
                         value: stats.totalAmount > 0 ? currency(stats.totalAmount) : "$0",
                         color: .accentColor)
                StatCard(title: "Paid",
                         value: stats.paidAmount > 0 ? currency(stats.paidAmount) : "$0",
                         color: .green)
            }
        }
    }

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)

            if stats.categoryBreakdown.isEmpty {
                Text("No documents this month.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                ForEach(DocumentType.allCases.filter { stats.categoryBreakdown[$0] != nil }) { type in
                    let count = stats.categoryBreakdown[type] ?? 0
                    let pct = stats.totalCount > 0 ? Double(count) / Double(stats.totalCount) : 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: type.sfSymbol)
                                .foregroundStyle(type.accentColor)
                                .frame(width: 28)
                            Text(type.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(count)").foregroundStyle(.secondary)
                        }
                        // Progress bar — fixed height 6, fills container width.
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.tertiarySystemFill))
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(type.accentColor)
                                    .frame(width: geo.size.width * pct)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Helpers

    private func shiftMonth(_ delta: Int) {
        if let new = Calendar.current.date(byAdding: .month, value: delta, to: selectedMonth) {
            selectedMonth = new
        }
    }

    private func currency(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale(identifier: "en_US")
        return nf.string(from: NSDecimalNumber(decimal: value)) ?? "$\(value)"
    }
}
