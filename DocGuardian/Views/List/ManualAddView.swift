//
//  ManualAddView.swift
//  DocGuardian
//
//  Quick-add a document without scanning — for electronic files,
//  already-digitized records, or any case where OCR isn't needed.
//

import SwiftUI

struct ManualAddView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var selectedType: DocumentType = .bill
    @State private var issuer = ""
    @State private var amount: String = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var documentDate = Date()
    @State private var hasDocumentDate = false
    @State private var accountSuffix = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Title (required)", text: $title)
                    Picker("Category", selection: $selectedType) {
                        ForEach(DocumentType.allCases) { t in
                            Label(t.displayName, systemImage: t.sfSymbol).tag(t)
                        }
                    }
                }

                Section("Details") {
                    TextField("Issuer / Provider", text: $issuer)
                    TextField("Total Amount", text: $amount).keyboardType(.decimalPad)
                    Toggle("Has Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }
                    Toggle("Has Document Date", isOn: $hasDocumentDate)
                    if hasDocumentDate {
                        DatePicker("Document Date", selection: $documentDate, displayedComponents: .date)
                    }
                    TextField("Account (last 4)", text: $accountSuffix).keyboardType(.numberPad)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section {
                    Button("Save Document") {
                        Task { await save() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() async {
        var doc = Document(
            title: title.trimmingCharacters(in: .whitespaces),
            type: selectedType,
            ocrText: notes,
            issuer: issuer.isEmpty ? nil : issuer,
            accountSuffix: accountSuffix.isEmpty ? nil : accountSuffix,
            classificationConfidence: 1.0
        )
        if let d = Decimal(string: amount) { doc.amount = d }
        if hasDueDate { doc.dueDate = dueDate }
        if hasDocumentDate { doc.documentDate = documentDate }

        do {
            try await listVM.add(doc)
            dismiss()
        } catch {
            // Surface error inline.
        }
    }
}
