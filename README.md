# DocGuardian

An iOS app that turns paper clutter into an organized, searchable, reminder-driven digital archive.

Scan a document with your camera → on-device OCR → automatic classification and field extraction → organized library with due-date reminders. Fully private: all processing happens on device.

## Features

- **Scan** — VisionKit document camera, multi-page capture, photo library and Files import (PDF supported)
- **On-device OCR** — Vision text recognition, 26 languages, no network required
- **Auto classification** — 9 document types: Bills, Medical, Insurance, Tax, Contracts, Identity, Receipts, Warranties, Other
- **Field extraction** — amount, due date, statement date, issuer, account suffix, invoice/policy numbers
- **Auto tagging** — issuer normalization (50+ US institutions), category, year, and household grouping
- **Organized library** — grouped by year/month, global search, advanced filters, batch operations
- **Reminders** — local notifications 3 / 1 / 0 days before a due date
- **Monthly dashboard** — totals, paid vs unpaid, category breakdown
- **Export** — PDF report and CSV
- **Privacy first** — Face ID / Touch ID app lock, on-device processing only
- **iCloud sync** — CloudKit private database with push subscriptions (requires Apple Developer Program)

## Tech stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Persistence | SwiftData (local) + CloudKit (sync) |
| Scanning | VisionKit `VNDocumentCameraViewController` |
| OCR | Vision `VNRecognizeTextRequest` |
| Classification | On-device rule engine |
| Field extraction | Regex + heuristics |
| Reminders | UserNotifications |
| Security | LocalAuthentication |
| PDF | PDFKit + UIGraphicsPDFRenderer |

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Build

The `.xcodeproj` is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open DocGuardian.xcodeproj
```

Then in Xcode set your **Team** under *Signing & Capabilities*.

## Cloud build (no Mac required)

Push to this repository and GitHub Actions compiles an unsigned `.ipa` you can sideload with Sideloadly on Windows.

## Project layout

```
DocGuardian/
├── project.yml                 # XcodeGen configuration
├── DocGuardian/
│   ├── DocGuardianApp.swift    # App entry, CloudKit, SwiftData, notifications
│   ├── Models/                 # Document, DocumentType, ExtractedField, Tag
│   ├── Services/               # Scan, OCR, Classifier, Extractor, Storage, Reminder, Security
│   ├── ViewModels/
│   ├── Views/                  # Home, Scan, Review, List, Detail, Calendar, Settings, Onboarding
│   └── Resources/
└── .github/workflows/build.yml # CI: builds unsigned IPA
```
