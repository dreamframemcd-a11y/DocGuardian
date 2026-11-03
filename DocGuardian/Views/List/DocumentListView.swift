//
//  DocumentListView.swift
//  DocGuardian
//
//  Browse + search + filter + multi-select batch operations.
//

import SwiftUI

struct DocumentListView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    @State private var showScan = false
    @State private var showManualAdd = false
    @State private var showFilters = false
    @State private var showExport = false
    @State private var pendingExportFormat: ExportFormat = .pdfReport
    @State private var exportResultURL: URL? = nil
    @State private var showExportConfirm = false

    var initialFilter: DocumentListViewModel.FilterPreset? = nil

    var body: some View {
        NavigationStack {
            Group {
                if listVM.isMultiSelectMode {
                    multiSelectList
                } else if listVM.filteredDocuments.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle(listVM.isMultiSelectMode
                ? "\(listVM.selectedIDs.count) selected"
                : "Library")
            .searchable(text: $listVM.searchText, prompt: "Search documents, issuers, content…")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if listVM.isMultiSelectMode {
                        Menu {
                            Button { Task { try? await listVM.batchMarkResolved(resolved: true) } }
                                label: { Label("Mark as Paid", systemImage: "checkmark.circle") }
                            Button { Task { try? await listVM.batchMarkResolved(resolved: false) } }
                                label: { Label("Mark as Open", systemImage: "arrow.uturn.backward.circle") }
                            Menu("Change Category") {
                                ForEach(DocumentType.allCases) { t in
                                    Button { Task { try? await listVM.batchChangeType(t) } }
                                        label: { Label(t.displayName, systemImage: t.sfSymbol) }
                                }
                            }
                            Button(role: .destructive) { Task { try? await listVM.batchDelete() } }
                                label: { Label("Delete", systemImage: "trash") }
                        } label: { Image(systemName: "ellipsis.circle") }
                    } else {
                        Menu {
                            Button { showScan = true }
                                label: { Label("Scan with Camera", systemImage: "camera") }
                            Button { showManualAdd = true }
                                label: { Label("Add Manually", systemImage: "square.and.pencil") }
                        } label: { Image(systemName: "plus") }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    if listVM.isMultiSelectMode {
                        Button("Done") { listVM.exitMultiSelect() }
                    }
                }
                ToolbarItemGroup(placement: .secondaryAction) {
                    if !listVM.isMultiSelectMode {
                        Button { showFilters = true }
                            label: { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
                        Button { listVM.enterMultiSelect() }
                            label: { Label("Select", systemImage: "checkmark.circle.badge.plus") }
                        Menu {
                            Button { prepareExport(.pdfReport) }
                                label: { Label("Export as PDF", systemImage: "doc.pdf") }
                            Button { prepareExport(.csvSummary) }
                                label: { Label("Export as CSV", systemImage: "tablecells") }
                        } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    }
                }
                ToolbarItem(placement: .principal) { categoryPicker }
            }
            .sheet(isPresented: $showScan) {
                ScanFlowView().environmentObject(listVM)
            }
            .sheet(isPresented: $showManualAdd) {
                ManualAddView().environmentObject(listVM)
            }
            .sheet(isPresented: $showFilters) {
                FilterPanelView().environmentObject(listVM)
            }
            .sheet(isPresented: Binding(
                get: { exportResultURL != nil },
                set: { if !$0 { exportResultURL = nil } }
            )) {
                if let url = exportResultURL {
                    ActivityViewController(items: [url])
                }
            }
            .alert("Export all documents?", isPresented: $showExportConfirm) {
                Button("Export", role: .none) { doExport(pendingExportFormat) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will create a \(pendingExportFormat == .pdfReport ? "PDF report" : "CSV spreadsheet") of all your documents.")
            }
            .task {
                if initialFilter == .dueSoon { listVM.onlyDueSoon = true }
                await listVM.load()
            }
        }
    }

    // MARK: - Components

    private var categoryPicker: some View {
        Picker("Category", selection: $listVM.selectedCategory) {
            Text("All").tag(Optional<DocumentType>.none)
            ForEach(DocumentType.allCases) { type in
                Label(type.displayName, systemImage: type.sfSymbol).tag(Optional<DocumentType>.some(type))
            }
        }
        .pickerStyle(.menu)
    }

    private var listContent: some View {
        List {
            ForEach(listVM.filteredDocuments) { doc in
                row(for: doc)
            }
            .onDelete(perform: delete)
        }
        .listStyle(.inset)
    }

    private var multiSelectList: some View {
        List {
            ForEach(listVM.filteredDocuments) { doc in
                multiSelectRow(for: doc)
            }
        }
        .listStyle(.inset)
    }

    private func row(for doc: Document) -> some View {
        NavigationLink {
            DocumentDetailView(document: doc)
        } label: {
            docContent(doc)
        }
        .contextMenu {
            Button { listVM.enterMultiSelect(); listVM.toggleSelect(doc) }
                label: { Label("Select", systemImage: "checkmark.circle") }
            Button { Task { try? await listVM.markResolved(doc, resolved: !doc.isResolved) } }
                label: { Label(doc.isResolved ? "Mark as Open" : "Mark as Paid", systemImage: "checkmark.circle.fill") }
            Button(role: .destructive) { Task { try? await listVM.delete(doc) } }
                label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func multiSelectRow(for doc: Document) -> some View {
        Button { listVM.toggleSelect(doc) } label: {
            HStack {
                Image(systemName: listVM.selectedIDs.contains(doc.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(listVM.selectedIDs.contains(doc.id) ? .accentColor : .tertiary)
                docContent(doc)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func docContent(_ doc: Document) -> some View {
        HStack(spacing: 12) {
            Image(systemName: doc.type.sfSymbol)
                .foregroundStyle(doc.type.accentColor)
                .frame(width: 36, height: 36)
                .background(doc.type.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(doc.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(doc.type.displayName)
                    if let due = doc.dueDate {
                        Text("·")
                        Text("Due \(Self.shortDate.string(from: due))")
                    }
                    if doc.isResolved {
                        Text("· Paid").foregroundStyle(.green)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.on.doc")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No documents yet")
                .font(.title3.weight(.semibold))
            Text("Scan or add your first document.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            HStack(spacing: 12) {
                Button { showScan = true } label: {
                    Label("Scan", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)

                Button { showManualAdd = true } label: {
                    Label("Add Manually", systemImage: "square.and.pencil")
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let doc = listVM.filteredDocuments[index]
            Task { try? await listVM.delete(doc) }
        }
    }

    private func prepareExport(_ format: ExportFormat) {
        guard !listVM.documents.isEmpty else { return }
        pendingExportFormat = format
        showExportConfirm = true
    }

    private func doExport(_ format: ExportFormat) {
        do {
            let result = try ExportService.export(listVM.documents, format: format)
            exportResultURL = result.url
        } catch {
            // In production we'd surface this. For now, silently ignore.
        }
    }

    static private let shortDate: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        return df
    }()
}

// MARK: - UIActivityViewController wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Filter preset extension

extension DocumentListViewModel {
    enum FilterPreset { case dueSoon }
}
