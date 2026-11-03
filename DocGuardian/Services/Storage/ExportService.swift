//
//  ExportService.swift
//  DocGuardian
//
//  Exports selected documents as a single PDF report or a
//  CSV summary spreadsheet. ZIP packaging for offline backup
//  is planned for a later iteration.
//

import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers

enum ExportFormat {
    case pdfReport     // Human-readable PDF with all document summaries
    case csvSummary    // Machine-readable CSV for spreadsheets
}

enum ExportError: LocalizedError {
    case noDocuments
    case renderFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noDocuments:  return "No documents to export."
        case .renderFailed: return "Failed to render export."
        case .writeFailed:  return "Could not save export file."
        }
    }
}

struct ExportResult {
    let url: URL            // Temp file URL — caller is responsible for presenting via ShareLink/UIActivityViewController
    let filename: String
}

final class ExportService {

    /// Export one or more documents. Returns a temp URL.
    static func export(_ documents: [Document], format: ExportFormat) throws -> ExportResult {
        guard !documents.isEmpty else { throw ExportError.noDocuments }

        switch format {
        case .pdfReport: return try makePDFReport(documents)
        case .csvSummary: return try makeCSVSummary(documents)
        }
    }

    // MARK: - PDF Report

    private static func makePDFReport(_ docs: [Document]) throws -> ExportResult {
        let doc = PDFDocument()
        let df = DateFormatter()
        df.dateStyle = .long
        df.timeStyle = .short

        for (i, item) in docs.enumerated() {
            let page = makePage(for: item, index: i + 1, total: docs.count)
            doc.insert(page, at: i)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DocGuardian-Export-\(UUID().uuidString).pdf")
        guard doc.write(to: url) else { throw ExportError.writeFailed }
        return ExportResult(url: url, filename: url.lastPathComponent)
    }

    private static func makePage(for doc: Document, index: Int, total: Int) -> PDFPage {
        let page = PDFPage()
        let bounds = page.bounds(for: .mediaBox)

        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { ctx in
            var y: CGFloat = 30

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.black
            ]
            let title = "\(index). \(doc.title)" as NSString
            title.draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 34

            // Category + status
            let typeAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.gray
            ]
            let status = doc.isResolved ? "✓ Paid / Resolved" : "⏳ Open"
            let line1 = "\(doc.type.displayName)  ·  \(status)" as NSString
            line1.draw(at: CGPoint(x: 40, y: y), withAttributes: typeAttrs)
            y += 20

            // Key fields
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.darkText
            ]
            if let issuer = doc.issuer {
                fieldLine("Issuer:", value: issuer, y: &y, attrs: bodyAttrs)
            }
            if let amt = doc.amount {
                fieldLine("Amount:", value: "$\(amt)", y: &y, attrs: bodyAttrs)
            }
            if let due = doc.dueDate {
                let df = DateFormatter(); df.dateStyle = .long
                fieldLine("Due:", value: df.string(from: due), y: &y, attrs: bodyAttrs)
            }
            if let account = doc.accountSuffix {
                fieldLine("Account:", value: "•••• \(account)", y: &y, attrs: bodyAttrs)
            }

            // OCR transcript (truncated to keep PDF readable)
            y += 16
            let transcriptHeading = "Transcript:" as NSString
            transcriptHeading.draw(at: CGPoint(x: 40, y: y), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 14)
            ])
            y += 20

            let ocr = doc.ocrText.prefix(2000)
            let textRect = CGRect(x: 40, y: y, width: bounds.width - 80, height: bounds.height - y - 40)
            (String(ocr) as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin],
                                           attributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray
            ], context: nil)
        }
        // NOTE: page.doc is intentionally left nil here — makePDFReport attaches
        // the page to the target PDFDocument via insert(_:at:).
        return page
    }

    private static func fieldLine(_ label: String, value: String, y: inout CGFloat,
                                  attrs: [NSAttributedString.Key: Any]) {
        let line = "\(label)  \(value)" as NSString
        line.draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
        y += 18
    }

    // MARK: - CSV Summary

    private static func makeCSVSummary(_ docs: [Document]) throws -> ExportResult {
        let headers = ["Title", "Category", "Status", "Issuer", "Amount", "Due Date", "Document Date", "Account Last 4", "Created"]
        var csv = [headers.joined(separator: ",")]

        let df = DateFormatter(); df.dateStyle = .short
        let nf = NumberFormatter(); nf.numberStyle = .decimal

        for doc in docs {
            let row = [
                csvEscape(doc.title),
                csvEscape(doc.type.displayName),
                doc.isResolved ? "Paid" : "Open",
                csvEscape(doc.issuer ?? ""),
                doc.amount.map { nf.string(from: NSDecimalNumber(decimal: $0)) ?? "" } ?? "",
                doc.dueDate.map { df.string(from: $0) } ?? "",
                doc.documentDate.map { df.string(from: $0) } ?? "",
                doc.accountSuffix ?? "",
                df.string(from: doc.createdAt),
            ]
            csv.append(row.joined(separator: ","))
        }

        let content = csv.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("DocGuardian-Summary-\(UUID().uuidString).csv")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return ExportResult(url: url, filename: url.lastPathComponent)
    }

    private static func csvEscape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}
