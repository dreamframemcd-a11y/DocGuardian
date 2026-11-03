//
//  Tag.swift
//  DocGuardian
//
//  Simple user-assignable tags for grouping documents
//  (e.g. "Home", "Kids", "Aetna 2025", "Tax Prep").
//

import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var colorHex: String?      // optional — future use for colored badges
    var createdAt: Date

    // Inverse declared here (and NOT on Document.tags) to keep the
    // many-to-many relationship unambiguous without triggering the
    // "circular reference resolving attached macro 'Relationship'" error.
    @Relationship(inverse: \Document.tags)
    var documents: [Document] = []

    init(id: UUID = UUID(), name: String, colorHex: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
