# Repository Guidelines

## Project Structure & Module Organization
- `VisionKit_test/`: SwiftUI app source (camera capture, Vision subject extraction, SwiftData models).
- `VisionKit_test/Assets.xcassets/`: Image/color assets.
- `VisionKit_test.xcodeproj/`: Xcode project and build settings.
- `docs/plans/`: Design notes (dated files like `YYYY-MM-DD-*-design.md`).
- Root `progress.md`, `task_plan.md`, `findings.md`: Working notes for ongoing changes.

## Build, Test, and Development Commands
- Open in Xcode: `open VisionKit_test.xcodeproj`
- List targets/schemes: `xcodebuild -list -project VisionKit_test.xcodeproj`
- Build (simulator):
  `xcodebuild -project VisionKit_test.xcodeproj -scheme VisionKit_test -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Clean build: add `clean` before `build` (e.g., `... clean build`).
- Run locally: use Xcode Run. Camera behavior is best validated on a real device (simulators may be limited).

## Coding Style & Naming Conventions
- Follow Xcode's default Swift formatting (4-space indentation, braces on the same line).
- Types/Views use `PascalCase` (`SubjectCameraView`); properties/functions use `camelCase`.
- Extensions use `Type+Feature.swift` (e.g., `UIImage+Orientation.swift`).
- Keep `VisionKit_test.xcodeproj/project.pbxproj` diffs minimal; avoid drive-by project reformatting.

## Testing Guidelines
- No XCTest target is checked in currently. If you add tests, prefer XCTest in a `VisionKit_testTests/` target.
- Test naming: files `*Tests.swift`, methods `test...()`; cover pure logic first (mask selection, cropping, file I/O).
- For camera/Vision changes, include a short manual test note in the PR (device + steps).

## Commit & Pull Request Guidelines
- Commit messages follow Conventional Commits: `feat: ...`, `fix: ...`, `docs: ...`, optional scope like `feat(camera): ...`.
- PRs should include: what/why, steps to test, and screenshots/screen recordings for UI changes.
- Privacy/config: camera permission text is set via build settings (e.g., `INFOPLIST_KEY_NSCameraUsageDescription`); add/keep required keys when introducing new capabilities.
