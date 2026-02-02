# Progress Log

## 2026-02-02
- Bootstrapped superpowers skills; loaded `brainstorming`, `planning-with-files`, `superpowers:test-driven-development`.
- Reviewed existing project files and build settings.
- Captured agreed requirements:
  - system camera UI
  - auto pick largest subject
  - same screen shows take-photo button + grid gallery
- Created planning files and began design doc workflow.
- Created feature branch `subject-cutout`.
- Implemented end-to-end v1 flow:
  - SwiftData model `SubjectCutout` + updated app schema
  - system camera via `UIImagePickerController` wrapped in SwiftUI
  - Vision foreground instance mask extraction, selecting largest instance, generating cutout
  - saving PNG to Documents and showing a grid gallery with delete
  - added camera usage description key to generated Info.plist build settings
