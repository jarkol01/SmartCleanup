# SmartCleanup

An iOS app that learns which photos *you* would delete and helps you clean up your library. The classifier is trained **on the device** from your own swipe decisions; no photo, label or model ever leaves the phone.

UI language: Polish.

## How it works

1. **Teach the model.** Swipe through photos: keep or delete. Each decision becomes a labelled training sample.
2. **Train on device.** `ClassifierTrainer` uses Create ML (`MLImageClassifier`, scenePrint features) to train a binary Keep/Delete classifier directly on the iPhone, reporting training, validation and (when there is enough data) held-out test accuracy.
3. **Review suggestions.** `ClassifierRunner` runs the compiled Core ML model through Vision over the library and surfaces delete candidates with a per-photo confidence score; low-confidence predictions get a separate review queue. Confirmed batches feed back into the training data.

Training cost is bounded on purpose: Create ML retrains from scratch, so each run uses a random subset capped at 1,000 samples per class, and a retrain only happens once the labelled set has grown by at least 20% since the last one.

## Cleanup tools

| Tool | Approach |
|------|----------|
| ML delete flow | On-device Keep/Delete classifier described above |
| Blur detection | Laplacian-variance sharpness heuristic on a downscaled grayscale image; user-adjustable threshold |
| Duplicates | Perceptual dHash with Hamming-distance grouping of time-adjacent shots (bursts), with a suggested photo to keep |
| Large videos | Lists videos by real file size and compresses selected ones to HEVC 1080p |

Plus: a storage indicator, home-screen widgets (WidgetKit), local reminder notifications with rotating copy, haptics and long-press previews. Design notes for each feature are in [`docs/features/`](docs/features).

## Privacy

No network calls, accounts, analytics or tracking. Photos are read through PhotoKit, and training data and the model are stored in the app's sandbox. See [`docs/privacy-policy.md`](docs/privacy-policy.md).

## Tech stack

Swift, SwiftUI, PhotoKit, Create ML, Core ML, Vision, AVFoundation, WidgetKit, UserNotifications, XCTest. The Xcode project is generated from `App/project.yml` ([XcodeGen](https://github.com/yonaskolb/XcodeGen)).

## Build

Requirements: Xcode with the iOS 17 SDK. Training and photo-library features are best tested on a physical device with a real library.

```bash
cd App
xcodegen generate   # optional, the generated project is committed
open SmartCleanup.xcodeproj
```

Set your own signing team in the target settings before running on a device.
