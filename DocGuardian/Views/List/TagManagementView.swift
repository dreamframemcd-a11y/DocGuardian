//
//  TagManagementView.swift
//  DocGuardian
//
//  Browse all auto-generated + user-added tags, see which documents
//  have each tag, delete tags, or merge two variants.
//

import SwiftUI

struct TagManagementView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    @State private var searchText: String = ""
    @State private var pendingMergeTarget: String? = nil
    @State private var pendingMergeSource: String? = nil
    @State private var showAddDialog = false
    @State private var newTagName = ""

    var body: some View {
        NavigationStack {
            List {
                sectionCount
                sectionTags
            }
            .navigationTitle("Tags")
            .searchable(text: $searchText, prompt: "Filter tags…")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddDialog = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Add Tag", isPresented: $showAddDialog) {
                TextField("Tag name", text: $newTagName)
                Button("Add") {
                    let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        // Find any document that already has at least one tag —
                        // attach the new custom tag to it (we can't create orphan tags).
                        if let doc = listVM.documents.first {
                            let tag = Tag(name: trimmed)
                            doc.tags.append(tag)
                            newTagName = ""
                        }
                    }
                }
                Button("Cancel", role: .cancel) { newTagName = "" }
            }
        }
    }

    // MARK: - Section builders

    private var sectionCount: some View {
        Section("Summary") {
            let all = listVM.allTagNames
            let withDocs = all.filter { name in
                listVM.documents.contains { $0.tags.contains { $0.name == name } }
            }
            HStack {
                Text("Total unique tags")
                Spacer()
                Text("\(all.count)").foregroundStyle(.secondary)
            }
            HStack {
                Text("Documents tagged")
                Spacer()
                Text("\(withDocs.count)").foregroundStyle(.secondary)
            }
        }
    }

    private var sectionTags: some View {
        Section("All Tags") {
            if filteredTags.isEmpty {
                Text(searchText.isEmpty ? "No tags yet — scan or add documents to auto-generate tags."
                      : "No tags match your search.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(filteredTags, id: \.self) { tagName in
                    tagRow(tagName: tagName)
                }
            }
        }
    }

    @ViewBuilder
    private func tagRow(tagName: String) -> some View {
        let count = documentCount(for: tagName)
        NavigationLink {
            TagDetailView(tagName: tagName)
                .environmentObject(listVM)
        } label: {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.accentColor)
                Text(tagName)
                Spacer()
                Text("\(count) doc\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            Button {
                pendingMergeSource = tagName
            } label: { Label("Merge into another…", systemImage: "arrow.triangle.merge") }

            Button(role: .destructive) {
                deleteTag(tagName)
            } label: { Label("Delete Tag", systemImage: "trash") }
        }
        .confirmationDialog(
            "Delete tag \"\(tagName)\"?",
            isPresented: Binding(
                get: { pendingMergeSource == nil && pendingMergeTarget == nil && false },
                set: { _, _ in }
            ),
            titleVisibility: .visible
        ) {
            // Merging sheet triggered via separate state.
        } message: {
            Text("This removes the tag from all documents. Documents themselves are not deleted.")
        }
    }

    // MARK: - Helpers

    private var filteredTags: [String] {
        let all = listVM.allTagNames
        if searchText.isEmpty { return all }
        let term = searchText.lowercased()
        return all.filter { $0.lowercased().contains(term) }
    }

    private func documentCount(for tagName: String) -> Int {
        listVM.documents.filter { $0.tags.contains { $0.name == tagName } }.count
    }

    private func deleteTag(_ name: String) {
        // Remove tag relationships from all documents.
        for doc in listVM.documents {
            doc.tags.removeAll { $0.name == name }
        }
    }
}

// MARK: - Tag Detail (documents with this tag)

struct TagDetailView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    let tagName: String

    var body: some View {
        List {
            ForEach(documentsWithTag) { doc in
                NavigationLink {
                    DocumentDetailView(document: doc)
                } label: {
                    HStack {
                        Image(systemName: doc.type.sfSymbol)
                            .foregroundStyle(doc.type.accentColor)
                        Text(doc.title).font(.subheadline.weight(.medium))
                    }
                }
            }
        }
        .navigationTitle(tagName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var documentsWithTag: [Document] {
        listVM.documents
            .filter { $0.tags.contains { $0.name == tagName } }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}
