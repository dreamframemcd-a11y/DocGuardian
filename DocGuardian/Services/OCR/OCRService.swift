//
//  OCRService.swift
//  DocGuardian
//
//  Protocol for text recognition — allows swapping between local Vision
//  and cloud providers (Google, Azure, AWS) in a future update.
//

import Foundation

protocol OCRService {
    /// Recognize text from image data. Returns an ordered list of recognized lines
    /// with individual confidence scores. Total OCR text concatenated.
    func recognizeText(from imageData: Data) async throws -> OCRResult
}

/// Aggregated OCR output.
struct OCRResult: Equatable {
    /// All recognized text joined with newlines.
    let fullText: String

    /// Each observed text line with its bounding confidence.
    let lines: [OCRLine]

    /// Average confidence across all recognized lines.
    var averageConfidence: Double {
        guard !lines.isEmpty else { return 0 }
        return lines.map(\.confidence).reduce(0, +) / Double(lines.count)
    }
}

struct OCRLine: Equatable {
    let text: String
    let confidence: Double        // 0...1
}
