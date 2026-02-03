# VisionKit_test

一个 iOS SwiftUI Demo：拍照后自动识别照片中的前景主体（取面积最大的主体），生成透明背景 PNG，并在本地“主体相册”中浏览/删除。

## 功能
- 自定义相机全屏拍照（AVFoundation）
- Vision 前景实例分割自动抠图（`VNGenerateForegroundInstanceMaskRequest`）
- 保存透明背景 PNG 到本地沙盒
- SwiftData 持久化主体元数据（时间、文件名）
- 网格浏览、预览大图、长按删除

## 技术栈
- UI：SwiftUI
- 相机：AVFoundation（`VisionKit_test/CameraCaptureService.swift`, `VisionKit_test/CameraPreviewView.swift`）
- 抠图：Vision（前景实例 mask）+ Core Image（像素缓冲转 `UIImage`）
- 存储：SwiftData（`VisionKit_test/SubjectCutout.swift`）+ 文件系统（`VisionKit_test/SubjectCutoutFileStore.swift`）

> 备注：项目名里有 VisionKit，但核心抠图能力来自 Vision 框架。

## 环境要求
- Xcode（建议使用最新稳定版）
- iOS 17+（使用 SwiftData；相机能力建议真机验证）

## 运行方式
1. 用 Xcode 打开：`open VisionKit_test.xcodeproj`
2. 选择真机运行（推荐）：模拟器通常没有可用相机或能力受限
3. 首次启动授予相机权限（已配置 `NSCameraUsageDescription`）

命令行构建（可选）：
`xcodebuild -project VisionKit_test.xcodeproj -scheme VisionKit_test -configuration Debug -destination 'generic/platform=iOS Simulator' build`

## 数据存储
- 图片：`Documents/subject_cutouts/<uuid>.png`
- 元数据：SwiftData `SubjectCutout`（`id`, `createdAt`, `fileName`）
- 清空数据：删除 App（或清理沙盒 Documents）

## 隐私与权限
- 权限：仅使用相机权限用于拍照抠主体。
- 数据：图片与元数据仅保存在本地沙盒；项目不包含网络上传逻辑。

## 代码导览
- 入口与首页：`VisionKit_test/VisionKit_testApp.swift`, `VisionKit_test/ContentView.swift`
- 拍照页：`VisionKit_test/SubjectCameraView.swift`
- 抠图实现：`VisionKit_test/SubjectExtractor.swift`
- 设计文档：`docs/plans/`

## 常见问题
- “无法打开相机”：请在真机运行，并检查系统设置中的相机权限。
- “未识别到主体”：换更清晰、主体更明显的照片；当前策略只取面积最大的主体。

## 贡献
请先阅读 `AGENTS.md`（目录结构、命令、代码风格与 PR 要求）。
