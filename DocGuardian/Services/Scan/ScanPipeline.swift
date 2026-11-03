//
//  ScanPipeline.swift
//  DocGuardian
//
//  Orchestrates the full "image → saved Document" pipeline:
//  OCR  →  Classify  →  Extract Fields  →  Build Document  →  Save + Schedule Reminders
//

import Foundation
import SwiftData

final class ScanPipeline {

    private let ocr: OCRService
    private let classifier: DocumentClassifier
    private let extractor: FieldExtractor

    init(
        ocr: OCRService = VisionOCRService(),
        classifier: DocumentClassifier = RuleBasedClassifier(),
        extractor: FieldExtractor = RegexFieldExtractor()
    ) {
        self.ocr = ocr
        self.classifier = classifier
        self.extractor = extractor
    }

    /// Run the full pipeline on one image.
    /// Returns a fully-populated Document (not yet saved).
    func process(imageData: Data) async throws -> Document {
        // 1. OCR
        let ocrResult = try await ocr.recognizeText(from: imageData)

        // 2. Classify
        let classification = classifier.classify(text: ocrResult.fullText)

        // 3. Extract fields
        let extractions = extractor.extract(from: ocrResult.fullText, type: classification.type)

        // 4. Build document
        var doc = Document(
            title: makeTitle(issuer: extractions.first(where: { $0.kind == .issuer })?.value,
                             type: classification.type),
            type: classification.type,
            ocrText: ocrResult.fullText,
            classificationConfidence: classification.confidence
        )

        for hit in extractions {
            switch hit.kind {
            case .amount:
                doc.amount = parseDecimal(hit.value)
            case .dueDate:
                doc.dueDate = parseDate(hit.value)
            case .documentDate:
                doc.documentDate = parseDate(hit.value)
            case .issuer:
                doc.issuer = hit.value
            case .accountNumber:
                doc.accountSuffix = hit.value
            default:
                break
            }
            // Persist extra field as well.
            let field = ExtractedField(kind: hit.kind, label: hit.label, value: hit.value, confidence: hit.confidence)
            doc.extractedFields.append(field)
        }

        // 5. Auto-generate semantic tags (issuer / category / year / family).
        doc.tags = TagService.shared.generateAutoTags(for: doc)

        return doc
    }

    // MARK: - Private helpers

    private func makeTitle(issuer: String?, type: DocumentType) -> String {
        if let issuer, !issuer.isEmpty {
            return "\(issuer) \(type.displayName)"
        }
        return "New \(type.displayName)"
    }

    private func parseDecimal(_ value: String) -> Decimal? {
        let digits = value.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return Decimal(string: digits)
    }

    private func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let formats = [
            "MM/dd/yyyy", "MM-dd-yyyy",
            "yyyy/MM/dd", "yyyy-MM-dd",
            "MM/dd/yy",   "MM-dd-yy",
        ]
        for fmt in formats {
            let df = DateFormatter()
            df.dateFormat = fmt
            df.locale = Locale(identifier: "en_US_POSIX")
            if let date = df.date(from: trimmed) { return date }
        }
        return nil
    }
}
