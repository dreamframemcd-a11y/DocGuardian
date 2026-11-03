//
//  ScanFlowView.swift
//  DocGuardian
//
//  Full sheet-based scan flow with 3 source options:
//  1. Camera (VisionKit DocumentCamera)
//  2. Photos library (PhotosPicker — multi-select)
//  3. Files app (FileImporter — PDF or image)
//  → Processing → Review → Save
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct ScanFlowView: View {

    @EnvironmentObject var listVM: DocumentListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .picker
    @State private var pickedImages: [Data] = []
    @State private var processedDocument: Document?
    @State private var processingError: String?

    // PhotosPicker
    @State private var photoItems: [PhotosPickerItem] = []

    // FileImporter
    @State private var showFileImporter = false

    private let pipeline = ScanPipeline()
    private let scanService = DocumentScanService()

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .picker:      sourcePicker
                case .processing:  processingView
                case .review:      if let doc = processedDocument { ReviewView(document: doc, onSave: save) }
                case .complete:    completeView
                }
            }
            .navigationTitle("New Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .complete { Button("Cancel") { dismiss() } }
                }
            }
            // Photos library — multi-select.
            .photosPicker(isPresented: Binding(
                get: { step == .photosPicker },
                set: { if !$0 { step = .picker } }
            ), selection: $photoItems, maxSelectionCount: 10, matching: .images, photoLibrary: .shared())
            .onChange(of: photoItems) { _, newItems in
                Task { await loadPhotos(newItems) }
            }
            // Files app — PDF or image import.
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.pdf, .image, UTType(filenameExtension: "pdf")].compactMap { $0 },
                allowsMultipleSelection: true
            ) { result in
                Task { await handleFileImport(result) }
            }
        }
    }

    // MARK: - Source picker

    private var sourcePicker: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.accentColor)
            Text("Choose your source")
                .font(.title2.weight(.semibold))
            Text("DocGuardian supports camera scans, photos, and PDFs from Files.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()

            VStack(spacing: 12) {
                sourceButton(systemImage: "camera.fill", title: "Scan with Camera", subtitle: "Auto-detects document edges") {
                    await scanWithCamera()
                }
                sourceButton(systemImage: "photo.on.rectangle", title: "From Photos", subtitle: "Pick images from your library") {
                    step = .photosPicker
                }
                sourceButton(systemImage: "folder.fill", title: "From Files", subtitle: "Import PDF or images") {
                    showFileImporter = true
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    @ViewBuilder
    private func sourceButton(
        systemImage: String, title: String, subtitle: String, action: @escaping () async -> Void
    ) -> some View {
        Button { Task { await action() } } label: {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Processing

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .scaleEffect(2.0)
            Text("AI is analyzing your document…")
                .font(.headline)
            Text("Recognizing text, classifying, and extracting fields.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if let err = processingError {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding()
            }
            Spacer()
        }
        .onAppear { runPipeline() }
    }

    private var completeView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Saved!")
                .font(.title2.weight(.semibold))
            Text("Your document is now in your library.")
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer()
        }
    }

    // MARK: - Actions

    private func scanWithCamera() async {
        guard let vc = topViewController() else { return }
        do {
            let result = try await scanService.presentScanner(from: vc)
            pickedImages = result.pageImages
            step = .processing
        } catch {
            if case ScanError.cancelled = error { return }
            processingError = error.localizedDescription
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        pickedImages.removeAll()
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                pickedImages.append(data)
            }
        }
        guard !pickedImages.isEmpty else {
            processingError = "No images could be loaded from Photos."
            step = .picker
            return
        }
        step = .processing
    }

    private func handleFileImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            pickedImages.removeAll()
            for url in urls {
                // Access the security-scoped URL.
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }

                let ext = url.pathExtension.lowercased()
                if ext == "pdf" {
                    // Render PDF pages to images.
                    let pdfImages = await PDFRenderer.render(pdfURL: url)
                    pickedImages.append(contentsOf: pdfImages)
                } else if let data = try? Data(contentsOf: url) {
                    pickedImages.append(data)
                }
            }
            guard !pickedImages.isEmpty else {
                processingError = "No importable files found."
                step = .picker
                return
            }
            step = .processing
        case .failure(let error):
            processingError = error.localizedDescription
            step = .picker
        }
    }

    private func runPipeline() {
        guard !pickedImages.isEmpty else { return }
        Task {
            do {
                // Process first page.
                let doc = try await pipeline.process(imageData: pickedImages[0])
                // Merge OCR from all remaining pages.
                if pickedImages.count > 1 {
                    var combinedOCR = doc.ocrText
                    for i in 1..<pickedImages.count {
                        let more = try? await VisionOCRService().recognizeText(from: pickedImages[i])
                        if let more { combinedOCR += "\n\n" + more.fullText }
                    }
                    doc.ocrText = combinedOCR
                }
                processedDocument = doc
                step = .review
            } catch {
                processingError = error.localizedDescription
                step = .picker
            }
        }
    }

    private func save(document: Document) async {
        do {
            try await listVM.add(document)
            step = .complete
        } catch {
            processingError = error.localizedDescription
        }
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var vc = root
        while let presented = vc.presentedViewController { vc = presented }
        return vc
    }
}

// MARK: - Step enum

extension ScanFlowView {
    enum Step { case picker, photosPicker, processing, review, complete }
}
