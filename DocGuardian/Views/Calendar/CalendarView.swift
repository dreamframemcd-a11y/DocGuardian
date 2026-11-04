//
//  CalendarView.swift
//  DocGuardian
//
//  Month-calendar overview of all documents with due dates.
//  Click a day → see what's due that day.
//

import SwiftUI

struct CalendarView: View {

    @EnvironmentObject var listVM: DocumentListViewModel

    @State private var selectedDate = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                weekdayHeader
                calendarGrid
                Divider()
                dayDetail
            }
            .navigationTitle("Calendar")
            .task { await listVM.load() }
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left").font(.title3)
            }
            Spacer()
            Text(monthYearString)
                .font(.headline)
            Spacer()
            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right").font(.title3)
            }
        }
        .padding(.horizontal).padding(.vertical, 8)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Grid

    private var calendarGrid: some View {
        let days = generateDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { date in
                cell(for: date)
            }
        }
        .padding(8)
    }

    private func cell(for date: Date?) -> some View {
        let hasDue = date.flatMap { hasDueOn($0) } ?? false
        let isToday = date.map { calendar.isDateInToday($0) } ?? false
        let isSelected = date.map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false

        return Button {
            if let date { selectedDate = date }
        } label: {
            ZStack {
                if let date {
                    let day = calendar.component(.day, from: date)
                    Text("\(day)")
                        .font(.callout)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            Group {
                                if isSelected {
                                    Circle().fill(Color.accentColor)
                                } else if isToday {
                                    Circle().fill(Color.accentColor.opacity(0.2))
                                }
                            }
                        )
                        .foregroundStyle(isSelected ? .white : .primary)

                    if hasDue {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)
                            .offset(y: 12)
                    }
                }
            }
        }
        .disabled(date == nil)
        .buttonStyle(.plain)
    }

    private var dayDetail: some View {
        let docs = documentsOn(selectedDate)
        return VStack(alignment: .leading, spacing: 8) {
            Text(Self.dayFormatter.string(from: selectedDate))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 12)

            if docs.isEmpty {
                Text("Nothing due this day.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                ForEach(docs) { doc in
                    NavigationLink {
                        DocumentDetailView(document: doc)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: doc.type.sfSymbol)
                                .foregroundStyle(doc.type.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.title).font(.subheadline.weight(.medium))
                                Text(doc.type.displayName).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if doc.isResolved {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func shiftMonth(by delta: Int) {
        if let new = calendar.date(byAdding: .month, value: delta, to: selectedDate) {
            selectedDate = new
        }
    }

    private var monthYearString: String {
        let df = DateFormatter()
        df.dateFormat = "MMMM yyyy"
        return df.string(from: selectedDate)
    }

    private func generateDays() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        var current = firstDay
        while current < monthInterval.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }

    private func hasDueOn(_ date: Date) -> Bool {
        listVM.documents.contains { doc in
            guard let due = doc.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: date) && !doc.isResolved
        }
    }

    private func documentsOn(_ date: Date) -> [Document] {
        listVM.documents.filter { doc in
            guard let due = doc.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: date)
        }
        .sorted { ($0.isResolved ? 1 : 0) < ($1.isResolved ? 1 : 0) }
    }

    static private let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .full
        return df
    }()
}
