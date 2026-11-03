//
//  ExtractedField.swift
//  DocGuardian
//
//  Key-value pair representing one AI-extracted field from a document
//  (e.g. "Total Amount" = "$123.45", "Due Date" = "2026-12-01").
//

import Foundation
import SwiftData

/// Semantic label for an extracted field.
enum FieldKind: String, Codable, CaseIterable {
    case amount
    case dueDate
    case documentDate
    case issuer
    case accountNumber
    case policyNumber
    case invoiceNumber
    case minimumPayment
    case statementBalance
    case deductible
    case copay
    case coverageLimit
    case other

    var displayName: String {
        switch self {
        case .amount:           return "Total Amount"
        case .dueDate:          return "Due Date"
        case .documentDate:     return "Document Date"
        case .issuer:           return "Issuer"
        case .accountNumber:    return "Account #"
        case .policyNumber:     return "Policy #"
        case .invoiceNumber:    return "Invoice #"
        case .minimumPayment:   return "Minimum Payment"
        case .statementBalance: return "Statement Balance"
        case .deductible:       return "Deductible"
        case .copay:            return "Co-Pay"
        case .coverageLimit:    return "Coverage Limit"
        case .other:            return "Other"
        }
    }
}

@Model
final class ExtractedField {

    var id: UUID
    var kindRaw: String
    var label: String          // user-visible label, may differ from kind
    var value: String          // raw extracted value
    var confidence: Double     // 0...1
    var userEdited: Bool       // true if user modified the AI output
    var createdAt: Date

    var kind: FieldKind {
        get { FieldKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    @Relationship(inverse: \Document.extractedFields)
    var document: Document?

    init(
        id: UUID = UUID(),
        kind: FieldKind = .other,
        label: String = "",
        value: String = "",
        confidence: Double = 0,
        userEdited: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.label = label.isEmpty ? kind.displayName : label
        self.value = value
        self.confidence = confidence
        self.userEdited = userEdited
        self.createdAt = createdAt
    }
}
