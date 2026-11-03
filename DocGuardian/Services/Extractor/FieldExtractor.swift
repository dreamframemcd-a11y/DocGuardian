//
//  FieldExtractor.swift
//  DocGuardian
//
//  Extracts structured fields (amount, due date, issuer, account suffix, ...)
//  from OCR text using targeted regex patterns.
//

import Foundation

/// One extracted field with context.
struct ExtractionHit: Equatable {
    let kind: FieldKind
    let label: String
    let value: String
    let confidence: Double
}

protocol FieldExtractor {
    /// Given OCR text + classified doc type, extract all candidate fields.
    func extract(from text: String, type: DocumentType) -> [ExtractionHit]
}

// MARK: - Regex-based implementation

final class RegexFieldExtractor: FieldExtractor {

    func extract(from text: String, type: DocumentType) -> [ExtractionHit] {
        let normalized = text
        var hits: [ExtractionHit] = []

        hits.append(contentsOf: extractAmounts(from: normalized))
        hits.append(contentsOf: extractDates(from: normalized))
        hits.append(contentsOf: extractIssuer(from: normalized, type: type))
        hits.append(contentsOf: extractAccountSuffix(from: normalized))
        hits.append(contentsOf: extractInvoiceNumber(from: normalized))
        hits.append(contentsOf: extractPolicyNumber(from: normalized, type: type))

        // Deduplicate by kind+value (keep highest confidence).
        var seen: Set<String> = []
        return hits.filter { seen.insert("\($0.kind.rawValue)|\($0.value.lowercased())").inserted }
    }

    // MARK: - Individual extractors

    /// Find monetary amounts — dollar signs with up to 2 decimal places,
    /// optionally with thousand separators.
    private func extractAmounts(from text: String) -> [ExtractionHit] {
        // Pattern 1: "Total: $123.45" or "Amount Due $1,234.56"
        // Pattern 2: Just "$123.45" anywhere in the text (lower confidence).
        var hits: [ExtractionHit] = []
        let labelAmount = [
            "(?i)total amount due[:\\s]*\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
            "(?i)amount due[:\\s]*\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
            "(?i)total[:\\s]*\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
            "(?i)balance due[:\\s]*\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
            "(?i)please pay[:\\s]*\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
            "(?i)statement balance[:\\s]*\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
            "(?i)minimum payment[:\\s]*\\$?([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2})?)",
        ]
        // Pattern 2: Standalone dollar figure as a fallback.
        let standalone = "(?<!\\w)\\$([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{1,2}))"

        for pattern in labelAmount {
            if let match = firstMatch(in: text, pattern: pattern) {
                hits.append(ExtractionHit(kind: .amount, label: "Total Amount", value: match, confidence: 0.9))
            }
        }
        if hits.isEmpty, let match = firstMatch(in: text, pattern: standalone) {
            hits.append(ExtractionHit(kind: .amount, label: "Amount", value: match, confidence: 0.6))
        }
        return hits
    }

    /// Find any dates — MM/DD/YYYY, MM-DD-YYYY, Month DD, YYYY.
    private func extractDates(from text: String) -> [ExtractionHit] {
        var hits: [ExtractionHit] = []
        let datePatterns: [(String, String, Double)] = [
            ("(?i)due date[:\\s]*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})",    "Due Date",       0.95),
            ("(?i)payment due[:\\s]*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})", "Due Date",       0.95),
            ("(?i)due[:\\s]*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})",         "Due Date",       0.85),
            ("(?i)statement date[:\\s]*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})","Document Date", 0.9),
            ("(?i)bill date[:\\s]*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})",   "Document Date", 0.9),
            ("(?i)invoice date[:\\s]*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})","Document Date", 0.9),
            ("(?i)issue date[:\\s]*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})",  "Document Date", 0.9),
            ("(?i)effective date[:\\s]*([0-9]{1,2}[-/][0-9]{1,2}[-/][0-9]{2,4})","Document Date", 0.9),
        ]

        for (pattern, label, conf) in datePatterns {
            if let match = firstMatch(in: text, pattern: pattern) {
                let kind: FieldKind = label == "Due Date" ? .dueDate : .documentDate
                hits.append(ExtractionHit(kind: kind, label: label, value: match, confidence: conf))
            }
        }
        return hits
    }

    /// Issuer name — heuristic: first line that looks like a company name
    /// (all caps, LLC/Inc/Co suffix, or common telecom/utility keywords).
    private func extractIssuer(from text: String, type: DocumentType) -> [ExtractionHit] {
        // Strategy 1: Look for specific "from:" or "issuer:" labels.
        if let match = firstMatch(in: text, pattern: "(?i)(?:from|issuer|provider|company|carrier|insurer)[:\\s]+([A-Z][A-Za-z0-9 .,&]{2,40})") {
            return [ExtractionHit(kind: .issuer, label: "Issuer", value: match.trimmingCharacters(in: .whitespaces), confidence: 0.85)]
        }

        // Strategy 2: For bills, try to find a common US provider name.
        let knownProviders = [
            "comcast", "verizon", "at&t", "t-mobile", "sprint", "xfinity",
            "geico", "state farm", "allstate", "progressive", "liberty mutual",
            "blue cross", "aetna", "cigna", "humana", "unitedhealth",
            "bank of america", "chase", "wells fargo", "citibank",
            "american express", "visa", "mastercard", "discover",
            "pg&e", "sempra", "dominion", "duke energy", "exelon",
            "irs", "united states department of the treasury",
        ]
        let lower = text.lowercased()
        if let match = knownProviders.first(where: { lower.contains($0) }) {
            return [ExtractionHit(kind: .issuer, label: "Issuer", value: match.capitalized, confidence: 0.8)]
        }
        return []
    }

    /// Account number — keep only the LAST 4 digits (privacy).
    private func extractAccountSuffix(from text: String) -> [ExtractionHit] {
        let patterns = [
            "(?i)account number[:\\s]*([0-9\\-]{4,20})",
            "(?i)account[:\\s]*([0-9\\-]{4,20})",
            "(?i)account ending in[:\\s]*([0-9]{4})",
            "(?i)card number[:\\s]*[0-9\\-]+.*?([0-9]{4})(?!.*[0-9])",
        ]
        for pattern in patterns {
            if let match = firstMatch(in: text, pattern: pattern) {
                let digits = match.filter { $0.isNumber }
                let suffix = String(digits.suffix(4))
                if suffix.count == 4 {
                    return [ExtractionHit(kind: .accountNumber, label: "Account (last 4)", value: suffix, confidence: 0.9)]
                }
            }
        }
        return []
    }

    private func extractInvoiceNumber(from text: String) -> [ExtractionHit] {
        let patterns = [
            "(?i)invoice number[:\\s]*([A-Za-z0-9\\-]{4,20})",
            "(?i)inv[:\\s]*([A-Za-z0-9\\-]{4,20})",
            "(?i)order number[:\\s]*([A-Za-z0-9\\-]{4,20})",
            "(?i)order[:\\s]*#?([A-Za-z0-9\\-]{4,20})",
        ]
        for pattern in patterns {
            if let match = firstMatch(in: text, pattern: pattern) {
                return [ExtractionHit(kind: .invoiceNumber, label: "Invoice #", value: match, confidence: 0.9)]
            }
        }
        return []
    }

    private func extractPolicyNumber(from text: String, type: DocumentType) -> [ExtractionHit] {
        guard type == .insurance else { return [] }
        let patterns = [
            "(?i)policy number[:\\s]*([A-Za-z0-9\\-]{4,20})",
            "(?i)policy[:\\s]*([A-Za-z0-9\\-]{4,20})",
        ]
        for pattern in patterns {
            if let match = firstMatch(in: text, pattern: pattern) {
                return [ExtractionHit(kind: .policyNumber, label: "Policy #", value: match, confidence: 0.9)]
            }
        }
        return []
    }

    // MARK: - Regex helpers

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges >= 2,
              let capture = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[capture])
    }
}
