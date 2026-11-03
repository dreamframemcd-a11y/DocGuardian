//
//  DocumentScanService.swift
//  DocGuardian
//
//  Wraps Apple's VisionKit VNDocumentCameraViewController for paper scanning.
//  Handles multi-page capture and image export.
//
//  Note: VisionKit is available on iOS 13+.
//  The delegate pattern bridges UIKit's VNDocumentCameraViewController
//  with SwiftUI via a completion handler.
//

import Foundation
import UIKit
import VisionKit

/// Result of a scan session — 0 or more page images as Data (JPEG, highest quality).
struct ScanResult: Equatable {
    let pageImages: [Data]
}

final class DocumentScanService: NSObject, VNDocumentCameraViewControllerDelegate {

    private var completionHandler: ((Result<ScanResult, Error>) -> Void)?
    private weak var presentingViewController: UIViewController?

    func presentScanner(from viewController: UIViewController) async throws -> ScanResult {
        return try await withCheckedThrowingContinuation { continuation in
            completionHandler = { result in continuation.resume(with: result) }
            presentingViewController = viewController

            guard VNDocumentCameraViewController.isSupported else {
                continuation.resume(throwing: ScanError.notSupported)
                return
            }

            let scanner = VNDocumentCameraViewController()
            scanner.delegate = self
            viewController.present(scanner, animated: true)
        }
    }

    // MARK: - Delegate

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        controller.dismiss(animated: true)
        var images: [Data] = []
        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            if let data = image.jpegData(compressionQuality: 0.95) {
                images.append(data)
            }
        }
        let result = ScanResult(pageImages: images)
        completionHandler?(.success(result))
        completionHandler = nil
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        completionHandler?(.failure(ScanError.cancelled))
        completionHandler = nil
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        controller.dismiss(animated: true)
        completionHandler?(.failure(error))
        completionHandler = nil
    }
}

enum ScanError: LocalizedError {
    case notSupported
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notSupported: return "Document scanning is not supported on this device."
        case .cancelled:    return "Scanning was cancelled."
        }
    }
}
