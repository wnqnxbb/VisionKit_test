# Findings

## Project State (2026-02-02)
- App is the default SwiftUI + SwiftData template (`VisionKit_test/ContentView.swift`, `VisionKit_test/Item.swift`).
- Deployment target is set to `IPHONEOS_DEPLOYMENT_TARGET = 26.2` in `VisionKit_test.xcodeproj/project.pbxproj`.
- `GENERATE_INFOPLIST_FILE = YES` and no `NSCameraUsageDescription` key is currently set in build settings.
- No test target or test files exist in the repo.

## Technical Notes
- "Subject lifting"/foreground instance segmentation is available via Vision (foreground instance mask request). This supports multiple instances, enabling "pick the largest subject" behavior.
- Saving cutouts as PNG in Documents avoids Photos permissions and keeps persistence simple; SwiftData can store filenames and timestamps.

