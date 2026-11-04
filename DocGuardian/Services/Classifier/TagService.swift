//
//  TagService.swift
//  DocGuardian
//
//  Rule-based auto-tagging engine. Generates semantic tags for every
//  document so users can group/filter by provider, year, category, etc.
//
//  Hierarchy:
//    • Issuer tag       → "Comcast", "Aetna" (canonicalized)
//    • Category tag     → "Bills", "Insurance" (from DocumentType)
//    • Year tag         → "2026" (from dueDate / documentDate / createdAt)
//    • Group tag        → "Family Insurance", "Health", "Home" (composite)
//
//  Tags are additive — users can always add more custom tags later.
//

import Foundation
import SwiftData

final class TagService {

    static let shared = TagService()
    private init() {}

    // MARK: - Public API

    /// Compute all auto-tags for a document. Does not persist them —
    /// the caller (ScanPipeline, DocumentListViewModel.add) is responsible
    /// for attaching and saving.
    func generateAutoTags(for document: Document) -> [Tag] {
        var tags: [String] = []

        // 1. Issuer tag (canonicalized).
        if let issuer = document.issuer, !issuer.isEmpty {
            let canonical = canonicalizeIssuer(issuer)
            tags.append(canonical)
        }

        // 2. Category tag.
        tags.append("Category: \(document.type.displayName)")

        // 3. Year tag — prefer dueDate, then documentDate, then createdAt.
        let dateForYear = document.dueDate ?? document.documentDate ?? document.createdAt
        let year = Calendar.current.component(.year, from: dateForYear)
        tags.append(String(year))

        // 4. Composite "group" tags — based on type + issuer combinations.
        tags.append(contentsOf: compositeTags(for: document))

        // Deduplicate, preserving order.
        var seen = Set<String>()
        let uniqueNames = tags.filter { seen.insert($0).inserted }

        return uniqueNames.map { Tag(name: $0) }
    }

    // MARK: - Canonicalization

    /// Map a messy issuer string to a clean, canonical form so variants
    /// ("Aetna Inc.", "Aetna Insurance") collapse into one tag.
    /// Uses a precomputed canonical table; unknown issuers are returned trimmed.
    func canonicalizeIssuer(_ raw: String) -> String {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[.,]", with: "", options: .regularExpression)
            .lowercased()

        // Look up canonical name.
        if let entry = issuerCanonicalMap.first(where: { cleaned.contains($0.key) }) {
            return entry.canonical
        }

        // Fallback: clean up minor suffixes.
        let suffixes = [" inc", " inc.", " llc", " ltd", " corporation", " corp", " company", " co"]
        var result = cleaned
        for suffix in suffixes {
            if result.hasSuffix(suffix) {
                result = String(result.dropLast(suffix.count))
                break
            }
        }
        return result.trimmingCharacters(in: .whitespaces).capitalized
    }

    // MARK: - Composite tags (provider families)

    private func compositeTags(for doc: Document) -> [String] {
        var result: [String] = []

        // "Health Insurance" family.
        if doc.type == .insurance || doc.type == .medical {
            if let issuer = doc.issuer?.lowercased() {
                if issuer.contains("blue cross") || issuer.contains("blue shield") || issuer.contains("bcbs") {
                    result.append("Blue Cross Family")
                }
                if issuer.contains("aetna") || issuer.contains("cigna") || issuer.contains("humana") || issuer.contains("unitedhealth") {
                    result.append("Major Health Insurers")
                }
            }
            if doc.type == .insurance {
                result.append("Family Insurance")
            }
        }

        // "Auto & Home" family.
        if doc.type == .insurance {
            if let issuer = doc.issuer?.lowercased() {
                if issuer.contains("geico") || issuer.contains("state farm") || issuer.contains("allstate") ||
                   issuer.contains("progressive") || issuer.contains("liberty mutual") ||
                   issuer.contains("usaa") || issuer.contains("farmers") {
                    result.append("Property & Casualty")
                }
            }
        }

        // Telecom bills.
        if doc.type == .bill {
            if let issuer = doc.issuer?.lowercased() {
                if issuer.contains("comcast") || issuer.contains("xfinity") ||
                   issuer.contains("verizon") || issuer.contains("at&t") ||
                   issuer.contains("t-mobile") || issuer.contains("sprint") {
                    result.append("Telecom")
                }
                if issuer.contains("pg&e") || issuer.contains("sempra") ||
                   issuer.contains("dominion") || issuer.contains("duke") ||
                   issuer.contains("exelon") || issuer.contains("coned") {
                    result.append("Utilities")
                }
                if issuer.contains("bank of america") || issuer.contains("chase") ||
                   issuer.contains("wells fargo") || issuer.contains("citibank") ||
                   issuer.contains("american express") || issuer.contains("visa") ||
                   issuer.contains("mastercard") {
                    result.append("Financial")
                }
            }
        }

        return result
    }

    // MARK: - Canonical issuer map

    // Each key is a lowercase substring that triggers the canonical name.
    // Order matters — more specific keys should come first so they match first.
    private let issuerCanonicalMap: [(key: String, canonical: String)] = [
        // Blue Cross family
        ("blue cross blue shield", "Blue Cross"),
        ("bluecross", "Blue Cross"),
        ("blue shield", "Blue Cross"),
        ("bcbs", "Blue Cross"),
        ("blueadvantage", "Blue Cross"),

        // Healthcare
        ("aetna", "Aetna"),
        ("cigna", "Cigna"),
        ("humana", "Humana"),
        ("unitedhealth", "UnitedHealth"),
        ("united health", "UnitedHealth"),
        ("kaiser", "Kaiser Permanente"),

        // Property & Casualty
        ("state farm", "State Farm"),
        ("allstate", "Allstate"),
        ("geico", "GEICO"),
        ("progressive", "Progressive"),
        ("liberty mutual", "Liberty Mutual"),
        ("usaa", "USAA"),
        ("farmers", "Farmers Insurance"),
        ("nationwide", "Nationwide"),
        ("travelers", "Travelers"),

        // Telecom
        ("comcast", "Comcast"),
        ("xfinity", "Xfinity"),
        ("verizon", "Verizon"),
        ("at&t", "AT&T"),
        ("att", "AT&T"),
        ("t-mobile", "T-Mobile"),
        ("tmobile", "T-Mobile"),
        ("sprint", "Sprint"),
        ("cox", "Cox"),
        ("charter", "Spectrum"),
        ("spectrum", "Spectrum"),

        // Utilities
        ("pg&e", "PG&E"),
        ("pge", "PG&E"),
        ("sempra", "Sempra"),
        ("dominion", "Dominion Energy"),
        ("duke energy", "Duke Energy"),
        ("exelon", "Exelon"),
        ("coned", "Con Edison"),
        ("pepco", "Pepco"),
        ("texas instruments", "Texas Instruments"),

        // Financial
        ("bank of america", "Bank of America"),
        ("chase", "JPMorgan Chase"),
        ("jpmorgan", "JPMorgan Chase"),
        ("wells fargo", "Wells Fargo"),
        ("citibank", "Citi"),
        ("american express", "American Express"),
        ("mastercard", "Mastercard"),
        ("visa", "Visa"),
        ("capital one", "Capital One"),
        ("discover", "Discover"),
        ("fidelity", "Fidelity"),
        ("vanguard", "Vanguard"),
        ("charles schwab", "Schwab"),

        // Government
        ("irs", "IRS"),
        ("department of the treasury", "IRS"),
        ("social security", "Social Security"),
        ("medicare", "Medicare"),
        ("medicaid", "Medicaid"),
        ("dmv", "DMV"),
        ("motor vehicle", "DMV"),

        // Retail / tech
        ("amazon", "Amazon"),
        ("apple", "Apple"),
        ("google", "Google"),
        ("microsoft", "Microsoft"),
        ("samsung", "Samsung"),
        ("target", "Target"),
        ("walmart", "Walmart"),
        ("costco", "Costco"),
    ]
}
