# 拍照 -> 自动识别主体 -> 抠图保存 -> 主体相册（v1 设计）

## 目标
实现一个最小可用的“拍照抠主体”流程：
1. 首页一个“拍照”按钮，点击后打开系统相机界面。
2. 拍照完成后自动识别照片中的前景主体（若有多个主体，取面积最大的那个）。
3. 对选中的主体进行抠图（透明背景 PNG），保存到 App 沙盒本地。
4. 同一页面下方以网格展示所有已保存的主体抠图，App 重启后仍可看到。

## 非目标（v1 不做）
- 多主体选择 UI
- 手动修边/替换背景/分享/同步到照片库
- 云端同步

## 技术方案概览
- **相机**：SwiftUI 中通过 `UIViewControllerRepresentable` 封装 `UIImagePickerController`（sourceType = `.camera`）。
- **主体识别与抠图**：使用 **Vision** 的前景实例分割生成 mask（多实例），按 mask 面积选最大主体；再用 Core Image 将 mask 应用到原图得到透明背景 cutout，导出为 PNG（保留 alpha）。
- **存储**：
  - 图片文件：`Documents/subject_cutouts/<uuid>.png`
  - 元数据：SwiftData `@Model`（`id` / `createdAt` / `fileName`）
- **展示**：SwiftUI `LazyVGrid` 读取本地 PNG 展示缩略图。

> 说明：用户口头提到 “VisionKit”，但公开 API 中用于前景实例 mask 的核心能力来自 **Vision**。本方案以 Vision 为主实现“自动抠主体”。

## 组件与职责
1. `CameraPicker`（SwiftUI wrapper）
   - 弹出系统相机
   - 返回 `UIImage` 或取消

2. `SubjectExtractor`
   - 输入：`UIImage`
   - 输出：`CGImage/UIImage`（透明背景主体图）+ 可选 metadata（bounding box）
   - 内部流程：
     - Vision 生成 foreground instance mask observation
     - 选取最大实例 id
     - 生成二值/灰度 mask（按需要缩放）
     - CoreImage 合成 alpha：`output = input * mask`
     - 对 bounding box 做裁切（可留少量 padding）

3. `SubjectCutoutStore`
   - 管理文件保存/删除（Documents 子目录）
   - 负责 PNG 编码与写入

4. SwiftData `SubjectCutout`
   - `id: UUID`
   - `createdAt: Date`
   - `fileName: String`（或相对路径）

5. `ContentView`
   - 一个主按钮（拍照）
   - 处理状态（processing overlay）
   - 网格展示（已保存 cutouts）
   - 删除（可选，长按/编辑模式）

## 数据流
1. 用户点击“拍照” -> 展示 `CameraPicker`。
2. 相机返回 `UIImage`：
   - UI 进入 processing 状态
   - 调用 `SubjectExtractor` 生成 cutout
3. 成功：
   - `SubjectCutoutStore` 写入 PNG 到 Documents
   - SwiftData 插入一条 `SubjectCutout` 记录
   - processing 结束，网格自动刷新
4. 失败：
   - processing 结束
   - 弹出 Alert（例如：未识别到主体/权限/相机不可用/生成失败）

## 错误处理与兜底
- 相机不可用（模拟器或无权限）：提示并引导用户到系统设置开启相机权限。
- Vision 无返回或无实例：提示“未识别到主体，请换一张更清晰的照片”。
- 文件写入失败：提示“保存失败”，不写入 SwiftData 记录。

## 性能与质量策略
- 处理在后台执行；UI 显示清晰的“处理中”状态，避免阻塞主线程。
- 如遇超大图导致耗时，可在生成 mask 时对输入图做下采样（v1 先不做复杂优化，保留扩展点）。

## 测试策略（可自动化部分）
- 纯逻辑：最大实例选择、裁切 rect 计算（padding + clamp）、文件路径生成、文件保存/删除（临时目录）。
- 集成验证：在真机上拍照，观察 processing 与保存结果；验证 PNG alpha（背景透明）与重启持久化。

