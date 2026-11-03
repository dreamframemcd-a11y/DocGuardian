//
//  DocumentType.swift
//  DocGuardian
//
//  Enumerates the document categories DocGuardian can classify.
//  Each case carries a display name, SF Symbol, and default folder.
//

import SwiftUI
import CloudKit

enum DocumentType: String, Codable, CaseIterable, Identifiable {
    case bill           // Bills & invoices (utilities, credit card, cable, ...)
    case medical        // Medical bills, EOBs, lab results
    case insurance      // Insurance policies, declarations
    case tax            // Tax forms (W-2, 1099, 1040, receipts)
    case contract       // Contracts, agreements, leases
    case identity       // IDs, passports, driver's licenses
    case receipt        // Individual purchase receipts
    case warranty       // Product warranties & manuals
    case other

    var id: String { rawValue }

    /// Human-readable display name (US English).
    var displayName: String {
        switch self {
        case .bill:      return "Bills"
        case .medical:   return "Medical"
        case .insurance: return "Insurance"
        case .tax:       return "Taxes"
        case .contract:  return "Contracts"
        case .identity:  return "Identity"
        case .receipt:   return "Receipts"
        case .warranty:  return "Warranties"
        case .other:     return "Other"
        }
    }

    /// SF Symbol representing the category (used in lists & folders).
    var sfSymbol: String {
        switch self {
        case .bill:      return "doc.text"
        case .medical:   return "heart.text.square"
        case .insurance: return "shield.lefthalf.filled"
        case .tax:       return "dollarsign.circle"
        case .contract:  return "signature"
        case .identity:  return "person.text.rectangle"
        case .receipt:   return "ticket"
        case .warranty:  return "lock.shield"
        case .other:     return "doc"
        }
    }

    /// Tinted color for category badges.
    var accentColor: Color {
        switch self {
        case .bill:      return .orange
        case .medical:   return .pink
        case .insurance: return .blue
        case .tax:       return .green
        case .contract:  return .purple
        case .identity:  return .teal
        case .receipt:   return .yellow
        case .warranty:  return .indigo
        case .other:     return .gray
        }
    }
}
