//
//  Document.swift
//  DocGuardian
//
//  Core model representing a scanned/imported document.
//  Persisted via CloudKit + locally cached with SwiftData.
//

import Foundation
import CloudKit
import SwiftData

@Model
final class Document {

    // MARK: Identifiers

    /// Local SwiftData ID (UUID).
    @Attribute(.unique) var id: UUID

    /// CloudKit record name (set after first save).
    var cloudKitRecordName: String?

    // MARK: Core content

    /// Display name — either user-entered or inferred from OCR.
    var title: String

    /// Auto-classified category.
    var typeRaw: String                  // stored as rawValue of DocumentType

    /// Full OCR text dump for on-device search / re-processing.
    var ocrText: String

    // MARK: Extracted fields

    /// Dollar amount found in the document (if any).
    var amount: Decimal?

    /// Due date or effective date.
    var dueDate: Date?

    /// The official document date (bill date, issue date, etc.).
    var documentDate: Date?

    /// Issuer / provider / institution name.
    var issuer: String?

    /// Last-4 of account number, policy number, etc. (PII — partial only).
    var accountSuffix: String?

    /// Confidence score of the classification (0...1).
    var classificationConfidence: Double

    // MARK: Status

    /// Whether the user has marked this as resolved (paid, filed, handled).
    var isResolved: Bool

    /// When the document was created/imported.
    var createdAt: Date

    /// When the user last edited fields or metadata.
    var updatedAt: Date

    // MARK: Relationships (SwiftData)

    @Relationship(deleteRule: .cascade, inverse: \ExtractedField.document)
    var extractedFields: [ExtractedField] = []

    // Many-to-many with Tag. No cascade: deleting a document must NOT delete
    // shared tag objects, and deleting a tag must NOT delete documents.
    @Relationship
    var tags: [Tag] = []

    // MARK: Computed helpers

    var type: DocumentType {
        get { DocumentType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var cloudKitRecordID: CKRecord.ID? {
        guard let name = cloudKitRecordName else { return nil }
        return CKRecord.ID(recordName: name)
    }

    // MARK: Initializer

    init(
        id: UUID = UUID(),
        title: String = "Untitled Document",
        type: DocumentType = .other,
        ocrText: String = "",
        amount: Decimal? = nil,
        dueDate: Date? = nil,
        documentDate: Date? = nil,
        issuer: String? = nil,
        accountSuffix: String? = nil,
        classificationConfidence: Double = 0,
        isResolved: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.typeRaw = type.rawValue
        self.ocrText = ocrText
        self.amount = amount
        self.dueDate = dueDate
        self.documentDate = documentDate
        self.issuer = issuer
        self.accountSuffix = accountSuffix
        self.classificationConfidence = classificationConfidence
        self.isResolved = isResolved
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - CloudKit conversion

extension Document {

    /// Map to a CKRecord for upload.
    func toCKRecord() -> CKRecord {
        let record: CKRecord
        if let name = cloudKitRecordName {
            record = CKRecord(recordType: "Document", recordID: CKRecord.ID(recordName: name))
        } else {
            record = CKRecord(recordType: "Document")
        }
        record["id"] = id.uuidString
        record["title"] = title
        record["type"] = typeRaw
        record["ocrText"] = ocrText
        // Decimal → NSDecimalNumber (CloudKit doesn't understand Decimal natively).
        if let amount = amount {
            record["amount"] = NSDecimalNumber(decimal: amount)
        } else {
            record["amount"] = nil
        }
        if let dueDate = dueDate { record["dueDate"] = NSDate(timeIntervalSince1970: dueDate.timeIntervalSince1970) }
        if let documentDate = documentDate { record["documentDate"] = NSDate(timeIntervalSince1970: documentDate.timeIntervalSince1970) }
        record["issuer"] = issuer
        record["accountSuffix"] = accountSuffix
        record["classificationConfidence"] = classificationConfidence
        record["isResolved"] = isResolved
        record["createdAt"] = NSDate(timeIntervalSince1970: createdAt.timeIntervalSince1970)
        record["updatedAt"] = NSDate(timeIntervalSince1970: updatedAt.timeIntervalSince1970)
        return record
    }

    /// Initialize from a CloudKit record (download).
    convenience init?(from record: CKRecord) {
        guard let idStr = record["id"] as? String,
              let uuid = UUID(uuidString: idStr) else { return nil }

        // Helper: safely convert CKRecord value to Date.
        func dateValue(_ key: String) -> Date? {
            if let ns = record[key] as? NSDate {
                return Date(timeIntervalSinceReferenceDate: ns.timeIntervalSinceReferenceDate)
            }
            return nil
        }

        self.init(
            id: uuid,
            title: record["title"] as? String ?? "Untitled",
            type: DocumentType(rawValue: record["type"] as? String ?? "") ?? .other,
            ocrText: record["ocrText"] as? String ?? "",
            amount: (record["amount"] as? NSDecimalNumber)?.decimalValue,
            dueDate: dateValue("dueDate"),
            documentDate: dateValue("documentDate"),
            issuer: record["issuer"] as? String,
            accountSuffix: record["accountSuffix"] as? String,
            classificationConfidence: record["classificationConfidence"] as? Double ?? 0,
            isResolved: record["isResolved"] as? Bool ?? false,
            createdAt: dateValue("createdAt") ?? Date(),
            updatedAt: dateValue("updatedAt") ?? Date()
        )
        self.cloudKitRecordName = record.recordID.recordName
    }
}
