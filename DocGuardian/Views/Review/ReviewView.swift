//
//  ReviewView.swift
//  DocGuardian
//
//  After AI processing — user reviews extracted fields, edits any mistakes,
//  confirms the document type, then saves.
//

import SwiftUI

struct ReviewView: View {

    @ObservedObject var document: Document
    let onSave: (Document) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                // Type + confidence
                Section("Document Type") {
                    Picker("Category", selection: $document.typeRaw) {
                        ForEach(DocumentType.allCases) { t in
                            Label(t.displayName, systemImage: t.sfSymbol).tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    if document.classificationConfidence < 0.6 {
                        Label(
                            "Low confidence — please verify the category is correct.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        .font(.callout)
                    }
                }

                // Editable fields
                Section("Detected Fields") {
                    fieldRow(title: "Title", text: Binding(
                        get: { document.title }, set: { document.title = $0 }))
                    fieldRow(title: "Issuer / Provider", text: Binding(
                        get: { document.issuer ?? "" }, set: { document.issuer = $0 }))
                    fieldRow(title: "Total Amount", text: Binding(
                        get: { document.amount.flatMap { String(describing: $0) } ?? "" },
                        set: { document.amount = Decimal(string: $0) }))
                    fieldRow(title: "Due Date", text: Binding(
                        get: { document.dueDate.map { Self.dateFormatter.string(from: $0) } ?? "" },
                        set: { document.dueDate = Self.dateFormatter.date(from: $0) }))
                    fieldRow(title: "Account (last 4)", text: Binding(
                        get: { document.accountSuffix ?? "" }, set: { document.accountSuffix = $0 }))
                }

                // AI confidence note
                Section {
                    Text("AI extracted these values automatically. You can edit anything before saving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await save() } } label: {
                        if isSaving { ProgressView() } else { Text("Save") }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    // MARK: - Helpers

    private func fieldRow(title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func save() async {
        isSaving = true
        await onSave(document)
        isSaving = false
    }

    static private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM/dd/yyyy"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
}
