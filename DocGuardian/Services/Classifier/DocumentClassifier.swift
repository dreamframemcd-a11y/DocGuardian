//
//  DocumentClassifier.swift
//  DocGuardian
//
//  Classifies an OCR-text dump into one of DocumentType, with a confidence score.
//  All logic runs locally — no cloud calls required.
//

import Foundation

/// Result of document classification.
struct ClassificationResult: Equatable {
    let type: DocumentType
    let confidence: Double           // 0...1
    let matchedKeywords: [String]    // which keywords fired (for debug / transparency)
}

protocol DocumentClassifier {
    func classify(text: String) -> ClassificationResult
}

// MARK: - Rule-based implementation

/// Pure rule-based classifier using keyword matches and weighted scoring.
/// No ML model — just regex + keyword dictionaries tuned for US consumer docs.
final class RuleBasedClassifier: DocumentClassifier {

    func classify(text: String) -> ClassificationResult {
        let normalized = text.lowercased()
        var scores: [DocumentType: Double] = [:]
        var matches: [DocumentType: [String]] = [:]

        for (docType, rules) in keywordRules {
            var score = 0.0
            var fired: [String] = []
            for (keyword, weight) in rules {
                if normalized.contains(keyword) {
                    score += weight
                    fired.append(keyword)
                }
            }
            if score > 0 {
                scores[docType] = (scores[docType] ?? 0) + score
                matches[docType] = fired
            }
        }

        // Pick the highest-scoring category.
        guard let best = scores.max(by: { $0.value < $1.value }) else {
            return ClassificationResult(type: .other, confidence: 0, matchedKeywords: [])
        }

        // Normalize confidence — top score divided by a generous ceiling.
        let confidence = min(best.value / 6.0, 1.0)
        return ClassificationResult(
            type: best.key,
            confidence: confidence,
            matchedKeywords: matches[best.key] ?? []
        )
    }

    // MARK: - Keyword rules (weighted)

    // Higher weight = stronger signal. First match is authoritative,
    // secondary keywords only boost confidence.
    private let keywordRules: [DocumentType: [(keyword: String, weight: Double)]] = [
        .medical: [
            ("explanation of benefits", 3.0), ("eob", 2.5), ("patient", 1.0),
            ("diagnosis", 2.0), ("cpt code", 2.0), ("icd-10", 2.0),
            ("deductible", 1.5), ("copay", 1.5), ("co-pay", 1.5),
            ("claim number", 2.0), ("medical record", 2.0),
            ("hospital", 1.0), ("clinic", 1.0), ("physician", 1.0),
            ("lab results", 2.0), ("prescription", 1.5),
        ],
        .insurance: [
            ("insurance policy", 3.0), ("declarations page", 3.0),
            ("policy number", 2.5), ("policyholder", 2.0),
            ("coverage", 1.5), ("premium", 2.0), ("insured", 1.5),
            ("life insurance", 3.0), ("health insurance", 3.0),
            ("auto insurance", 3.0), ("homeowners", 3.0), ("renters", 2.5),
            ("beneficiary", 2.0), ("rider", 1.5), ("exclusions", 1.5),
        ],
        .tax: [
            ("form w-2", 3.5), ("w-2", 3.0), ("1099", 3.0), ("1040", 3.0),
            ("irs", 2.5), ("tax return", 3.0), ("form 941", 3.0),
            ("form ss-4", 3.0), ("schedule a", 2.5), ("schedule c", 2.5),
            ("taxpayer", 2.0), ("gross income", 2.0), ("adjusted gross", 2.0),
            ("taxable income", 2.0), ("tax liability", 2.0), ("refund", 1.5),
            ("deduction", 1.5), ("wages, tips, other comp", 2.5),
        ],
        .contract: [
            ("contract", 3.0), ("agreement", 2.5), ("lease", 3.0),
            ("terms and conditions", 2.0), ("binding agreement", 2.5),
            ("parties", 1.5), ("hereby agrees", 2.5), ("in witness whereof", 3.0),
            ("signature", 1.5), ("effective date", 1.0),
            ("landlord", 2.5), ("tenant", 2.5), ("rental", 2.0),
            ("non-disclosure", 3.0), ("nda", 2.5), ("service agreement", 2.5),
        ],
        .bill: [
            ("invoice", 3.0), ("bill", 2.0), ("statement", 1.5),
            ("amount due", 2.5), ("balance due", 2.5), ("total amount due", 3.0),
            ("due date", 2.0), ("payment due", 2.0), ("please pay", 2.0),
            ("utility", 1.5), ("electric", 1.5), ("gas", 1.0), ("water", 1.0),
            ("cable", 1.5), ("internet", 1.0), ("credit card statement", 2.5),
            ("minimum payment", 2.0), ("cardholder", 1.5),
            ("account number", 1.5), ("account ending in", 2.0),
        ],
        .identity: [
            ("driver license", 3.5), ("driver's license", 3.5),
            ("passport", 3.5), ("state id", 3.0),
            ("social security", 3.0), ("ssn", 3.0),
            ("date of birth", 2.0), ("resident", 1.5),
            ("license number", 2.5), ("identification card", 3.0),
            ("department of motor vehicles", 2.5), ("dhs", 2.0),
        ],
        .receipt: [
            ("receipt", 3.0), ("thank you for your purchase", 2.5),
            ("purchase date", 1.5), ("subtotal", 1.5), ("tax", 1.5),
            ("grand total", 1.5), ("method of payment", 1.5),
            ("store", 1.0), ("order #", 1.5), ("transaction", 1.0),
        ],
        .warranty: [
            ("warranty", 3.0), ("limited warranty", 3.0), ("product manual", 2.5),
            ("owner's manual", 3.0), ("user guide", 2.5), ("specifications", 2.0),
            ("serial number", 1.5), ("model number", 1.5),
        ],
    ]
}
