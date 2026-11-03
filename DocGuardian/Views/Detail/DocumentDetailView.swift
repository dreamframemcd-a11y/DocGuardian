//
//  DocumentDetailView.swift
//  DocGuardian
//
//  Shows everything known about one document: editable fields,
//  OCR transcript, and the "Mark as Paid" action.
//

import SwiftUI

struct DocumentDetailView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    @Environment(\.dismiss) private var dismiss
    // SwiftData @Model classes are NOT ObservableObject — use @Bindable.
    @Bindable var document: Document

    @State private var showDeleteConfirm = false
    @State private var shareOCR = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                actionButtons
                fieldsSection
                extractedFieldsSection
                rawOCRSection
            }
            .padding()
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this document?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await listVM.delete(document)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: document.type.sfSymbol)
                    .font(.system(size: 36))
                    .foregroundStyle(document.type.accentColor)
                    .frame(width: 64, height: 64)
                    .background(document.type.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.title3.weight(.semibold))
                    Text(document.type.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if document.isResolved {
                        Label("Resolved", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
            }

            if let issuer = document.issuer {
                detailRow(label: "Issuer", value: issuer, symbol: "building.2")
            }
            if let amount = document.amount {
                detailRow(label: "Amount", value: formatCurrency(amount), symbol: "dollarsign.circle")
            }
            if let due = document.dueDate {
                detailRow(label: "Due Date", value: Self.dueFormatter.string(from: due), symbol: "calendar")
            }
            if let account = document.accountSuffix {
                detailRow(label: "Account", value: "•••• \(account)", symbol: "creditcard")
            }
            if document.classificationConfidence > 0 {
                detailRow(label: "AI Confidence", value: "\(Int(document.classificationConfidence * 100))%", symbol: "sparkles")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    try? await listVM.markResolved(document, resolved: !document.isResolved)
                }
            } label: {
                Label(
                    document.isResolved ? "Mark as Open" : "Mark as Paid",
                    systemImage: document.isResolved ? "arrow.uturn.backward.circle" : "checkmark.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(document.isResolved ? .orange : .green)

            Button { shareOCR = true } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $shareOCR) {
            ShareSheet(items: [document.ocrText])
        }
    }

    private var fieldsSection: some View {
        SectionCard(title: "Key Details") {
            VStack(alignment: .leading, spacing: 8) {
                editableRow(label: "Title", binding: Binding(
                    get: { document.title },
                    set: { document.title = $0; document.updatedAt = Date() }
                ))
                Divider()
                editableRow(label: "Issuer", binding: Binding(
                    get: { document.issuer ?? "" },
                    set: { document.issuer = $0.isEmpty ? nil : $0; document.updatedAt = Date() }
                ))
                Divider()
                editableRow(label: "Notes", binding: Binding(
                    get: { document.tags.first?.name ?? "" },
                    set: { _ in }
                ))
            }
        }
    }

    private var extractedFieldsSection: some View {
        SectionCard(title: "Extracted Fields") {
            if document.extractedFields.isEmpty {
                Text("No additional fields detected.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(document.extractedFields) { field in
                    HStack {
                        Text(field.label).foregroundStyle(.secondary)
                        Spacer()
                        Text(field.value).multilineTextAlignment(.trailing)
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var rawOCRSection: some View {
        SectionCard(title: "OCR Transcript") {
            if document.ocrText.isEmpty {
                Text("No OCR text available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text(document.ocrText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Helpers

    private func detailRow(label: String, value: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            Text(label).foregroundStyle(.secondary).font(.callout)
            Spacer()
            Text(value).font(.callout.weight(.medium))
        }
    }

    private func editableRow(label: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField(label, text: binding)
                .multilineTextAlignment(.trailing)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale(identifier: "en_US")
        return nf.string(from: NSDecimalNumber(decimal: value)) ?? "$\(value)"
    }

    static private let dueFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .long
        return df
    }()
}

// MARK: - Supporting views

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// UIActivityViewController wrapper for SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
