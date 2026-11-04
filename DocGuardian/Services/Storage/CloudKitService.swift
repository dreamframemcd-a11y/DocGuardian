//
//  CloudKitService.swift
//  DocGuardian
//
//  Thin wrapper around CKContainer for syncing documents to iCloud.
//  Uses the private database — each user sees only their own documents.
//

import Foundation
import CloudKit
import SwiftData

final class CloudKitService {

    let container: CKContainer
    private let database: CKDatabase

    init(container: CKContainer) {
        self.container = container
        self.database = container.privateCloudDatabase
    }

    // MARK: - Upload

    /// Save (or update) a Document record to CloudKit. Returns the record name.
    @discardableResult
    func save(_ document: Document) async throws -> String {
        let record = document.toCKRecord()
        let saved = try await database.save(record)
        return saved.recordID.recordName
    }

    // MARK: - Delete

    func delete(recordName: String) async throws {
        try await database.deleteRecord(withID: CKRecord.ID(recordName: recordName))
    }

    // MARK: - Download all (initial sync)

    /// Fetch every Document record from the private database using the modern async API.
    /// Handles pagination automatically via cursor.
    func fetchAll() async throws -> [Document] {
        let query = CKQuery(recordType: "Document", predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        var result: [Document] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            // The first page uses `records(matching:)`; subsequent pages must use
            // `records(continuingMatchFrom:)` — there is no `cursor:` parameter.
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)],
                       queryCursor: CKQueryOperation.Cursor?)
            if let current = cursor {
                page = try await database.records(
                    continuingMatchFrom: current,
                    resultsLimit: CKQueryOperation.maximumResults
                )
            } else {
                page = try await database.records(
                    matching: query,
                    resultsLimit: CKQueryOperation.maximumResults
                )
            }
            for (_, recordResult) in page.matchResults {
                if case .success(let record) = recordResult,
                   let doc = Document(from: record) {
                    result.append(doc)
                }
            }
            cursor = page.queryCursor
        } while cursor != nil

        return result
    }

    // MARK: - Account status

    /// Returns true if the user is signed into iCloud on this device.
    func isAccountAvailable() async -> Bool {
        do {
            _ = try await container.accountStatus()
            return true
        } catch {
            return false
        }
    }
}
