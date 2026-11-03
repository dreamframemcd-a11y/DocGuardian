//
//  DocumentListViewModel.swift
//  DocGuardian
//
//  Extended with: batch operations, advanced filtering,
//  statistics, and tag management.
//

import Foundation
import SwiftData
import CloudKit

@MainActor
final class DocumentListViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var documents: [Document] = []
    @Published var searchText: String = ""
    @Published var selectedCategory: DocumentType? = nil
    @Published var selectedTag: String? = nil
    @Published var onlyDueSoon: Bool = false
    @Published var onlyUnresolved: Bool = false
    @Published var onlyOverdue: Bool = false
    @Published var amountMin: Decimal? = nil
    @Published var amountMax: Decimal? = nil
    @Published var sortOrder: SortOrder = .dueDateAsc
    @Published var isSyncing: Bool = false

    // Batch selection
    @Published var isMultiSelectMode: Bool = false
    @Published var selectedIDs: Set<UUID> = []

    private let cloudKit: CloudKitService
    var modelContext: ModelContext?

    init(cloudKit: CloudKitService, modelContext: ModelContext? = nil) {
        self.cloudKit = cloudKit
        self.modelContext = modelContext

        // Respond to CloudKit subscription pushes + foreground entry.
        NotificationCenter.default.addObserver(
            forName: .cloudKitDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    enum SortOrder { case dueDateAsc, dueDateDesc, createdAtDesc, amountDesc, titleAsc }

    // MARK: - Load / sync

    func load() async {
        isSyncing = true
        defer { isSyncing = false }

        let cloudDocs: [Document]
        do {
            cloudDocs = try await cloudKit.fetchAll()
        } catch {
            cloudDocs = []
        }
        documents = cloudDocs

        // Update local cache.
        if let ctx = modelContext {
            for doc in documents {
                do {
                    // SwiftData throws if trying to insert a model with a duplicate @Attribute(.unique).
                    // We simply attempt a fetch-by-id first to avoid that.
                    let existing = try ctx.fetch(.init(id: doc.id))
                    if existing.isEmpty {
                        ctx.insert(doc)
                    }
                } catch {
                    ctx.insert(doc)
                }
            }
            try? ctx.save()
        }
    }

    // MARK: - Filtered view

    var filteredDocuments: [Document] {
        var result = documents

        if let category = selectedCategory {
            result = result.filter { $0.type == category }
        }
        if let tagName = selectedTag, !tagName.isEmpty {
            result = result.filter { $0.tags.contains { $0.name == tagName } }
        }
        if onlyUnresolved {
            result = result.filter { !$0.isResolved }
        }
        if onlyDueSoon {
            let cutoff = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            result = result.filter {
                guard let due = $0.dueDate else { return false }
                return due <= cutoff && !$0.isResolved
            }
        }
        if onlyOverdue {
            result = result.filter {
                guard let due = $0.dueDate else { return false }
                return due < Date() && !$0.isResolved
            }
        }
        if let min = amountMin {
            result = result.filter { ($0.amount ?? 0) >= min }
        }
        if let max = amountMax {
            result = result.filter { ($0.amount ?? 0) <= max }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let term = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(term) ||
                ($0.issuer?.lowercased().contains(term) ?? false) ||
                $0.ocrText.lowercased().contains(term) ||
                $0.extractedFields.contains { $0.value.lowercased().contains(term) }
            }
        }

        // Sort.
        switch sortOrder {
        case .dueDateAsc:
            result.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .dueDateDesc:
            result.sort { ($0.dueDate ?? .distantPast) > ($1.dueDate ?? .distantPast) }
        case .createdAtDesc:
            result.sort { $0.createdAt > $1.createdAt }
        case .amountDesc:
            result.sort { ($0.amount ?? 0) > ($1.amount ?? 0) }
        case .titleAsc:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return result
    }

    // MARK: - Batch mode

    func enterMultiSelect() {
        isMultiSelectMode = true
        selectedIDs.removeAll()
    }

    func exitMultiSelect() {
        isMultiSelectMode = false
        selectedIDs.removeAll()
    }

    func toggleSelect(_ doc: Document) {
        if selectedIDs.contains(doc.id) {
            selectedIDs.remove(doc.id)
        } else {
            selectedIDs.insert(doc.id)
        }
    }

    var selectedDocuments: [Document] {
        documents.filter { selectedIDs.contains($0.id) }
    }

    // MARK: - Write operations

    func add(_ document: Document) async throws {
        // Auto-tags (supplement any that ScanPipeline already applied).
        let autoTags = TagService.shared.generateAutoTags(for: document)
        for tag in autoTags where !document.tags.contains(where: { $0.name == tag.name }) {
            document.tags.append(tag)
        }

        documents.insert(document, at: 0)
        let recordName = try await cloudKit.save(document)
        document.cloudKitRecordName = recordName

        if let ctx = modelContext {
            ctx.insert(document)
            try? ctx.save()
        }

        await MainActor.run {
            ReminderService.shared.scheduleReminders(
                for: document.id,
                dueDate: document.dueDate,
                title: document.title,
                issuer: document.issuer
            )
        }
    }

    func markResolved(_ document: Document, resolved: Bool) async throws {
        document.isResolved = resolved
        document.updatedAt = Date()
        try await cloudKit.save(document)
        if let ctx = modelContext { try? ctx.save() }

        if resolved {
            ReminderService.shared.cancelReminders(for: document.id)
        } else {
            ReminderService.shared.scheduleReminders(
                for: document.id,
                dueDate: document.dueDate,
                title: document.title,
                issuer: document.issuer
            )
        }
    }

    func delete(_ document: Document) async throws {
        if let name = document.cloudKitRecordName {
            try await cloudKit.delete(recordName: name)
        }
        ReminderService.shared.cancelReminders(for: document.id)
        documents.removeAll { $0.id == document.id }
        selectedIDs.remove(document.id)
    }

    // MARK: - Batch operations

    func batchMarkResolved(resolved: Bool) async throws {
        for doc in selectedDocuments {
            try await markResolved(doc, resolved: resolved)
        }
        exitMultiSelect()
    }

    func batchDelete() async throws {
        for doc in selectedDocuments {
            try await delete(doc)
        }
        exitMultiSelect()
    }

    func batchChangeType(_ type: DocumentType) async throws {
        for doc in selectedDocuments {
            doc.type = type
            doc.updatedAt = Date()
            try await cloudKit.save(doc)
            if let ctx = modelContext { try? ctx.save() }
        }
        exitMultiSelect()
    }

    // MARK: - All tag names used by documents

    var allTagNames: [String] {
        let names = documents.flatMap { $0.tags.map(\.name) }
        return Array(Set(names)).sorted()
    }

    // MARK: - Statistics

    struct MonthlyStats: Equatable {
        var totalCount: Int = 0
        var unresolvedCount: Int = 0
        var totalAmount: Decimal = 0
        var paidAmount: Decimal = 0
        var categoryBreakdown: [DocumentType: Int] = [:]
    }

    func monthlyStats(for month: Date = Date()) -> MonthlyStats {
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .month, for: month)
        let monthDocs = documents.filter {
            // Include if created this month OR has due date this month.
            let inRange = { (_ date: Date?) -> Bool in
                guard let date else { return false }
                return date >= interval.start && date < interval.end
            }
            return inRange($0.createdAt) || inRange($0.dueDate) || inRange($0.documentDate)
        }

        var stats = MonthlyStats()
        stats.totalCount = monthDocs.count
        stats.unresolvedCount = monthDocs.filter { !$0.isResolved }.count
        for doc in monthDocs {
            let amt = doc.amount ?? 0
            stats.totalAmount += amt
            if doc.isResolved { stats.paidAmount += amt }
            stats.categoryBreakdown[doc.type, default: 0] += 1
        }
        return stats
    }
}
