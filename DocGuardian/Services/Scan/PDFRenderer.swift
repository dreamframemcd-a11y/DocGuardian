//
//  PDFRenderer.swift
//  DocGuardian
//
//  Renders each page of a PDF into a JPEG image (Data).
//  Used when importing PDFs from Files.app — Vision framework can't OCR PDFs
//  directly, so we rasterize each page first.
//

import Foundation
import PDFKit
import UIKit

enum PDFRenderer {

    /// Render all pages of a PDF to JPEG images (data).
    /// Returns empty array on failure.
    static func render(pdfURL: URL) async -> [Data] {
        await withCheckedContinuation { continuation in
            Task.detached {
                guard let doc = PDFDocument(url: pdfURL) else {
                    continuation.resume(returning: [])
                    return
                }
                var images: [Data] = []
                // Use a reasonable DPI for document OCR (2x screen ≈ good quality).
                let scale: CGFloat = 2.5

                for i in 0..<doc.pageCount {
                    guard let page = doc.page(at: i) else { continue }
                    let bounds = page.bounds(for: .mediaBox)
                    let width  = Int(bounds.width  * scale)
                    let height = Int(bounds.height * scale)
                    let size   = CGSize(width: width, height: height)

                    let renderer = UIGraphicsImageRenderer(size: size)
                    let image = renderer.image { ctx in
                        // UIGraphicsImageRendererContext exposes CGContext drawing
                        // primitives (saveGState/scaleBy/restoreGState) via .cgContext.
                        let cg = ctx.cgContext
                        UIColor.white.set()
                        cg.fill(CGRect(origin: .zero, size: size))
                        cg.saveGState()
                        cg.scaleBy(x: scale, y: scale)
                        page.draw(with: .mediaBox, to: cg)
                        cg.restoreGState()
                    }
                    if let data = image.jpegData(compressionQuality: 0.92) {
                        images.append(data)
                    }
                }
                continuation.resume(returning: images)
            }
        }
    }
}
