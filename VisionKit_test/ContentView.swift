//
//  ContentView.swift
//  VisionKit_test
//
//  Created by 赵铭轩 on 2026/2/2.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SubjectCutout.createdAt, order: .reverse) private var cutouts: [SubjectCutout]

    @State private var isShowingCamera = false
    @State private var isProcessing = false
    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let extractor = SubjectExtractor()
    private let fileStore = SubjectCutoutFileStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    takePhotoButton
                    gallery
                }
                .padding(24)
            }
            .navigationTitle("抠图主体")
            .alert(alertTitle, isPresented: $isShowingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    processCapturedImage(image)
                }
                .ignoresSafeArea()
            }
            .overlay {
                if isProcessing {
                    processingOverlay
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍照后自动识别主体并抠图保存")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("系统相机拍照 -> 自动取面积最大的主体 -> 透明 PNG 保存到本地。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var takePhotoButton: some View {
        Button {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                showAlert(title: "无法打开相机", message: "当前设备不支持相机（模拟器通常不可用）。")
                return
            }
            isShowingCamera = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(isProcessing ? "处理中…" : "拍照抠主体")
                    .font(.headline)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing)
    }

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("主体照片")
                    .font(.headline)
                Text("(\(cutouts.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if cutouts.isEmpty {
                ContentUnavailableView(
                    "还没有主体照片",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("点击上方按钮拍一张照片试试。")
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110), spacing: 16, alignment: .top)],
                    alignment: .leading,
                    spacing: 16
                ) {
                    ForEach(cutouts) { cutout in
                        SubjectCutoutCell(
                            fileURL: try? fileStore.fileURL(for: cutout.fileName),
                            onDelete: { deleteCutout(cutout) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var processingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.35))
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("正在识别主体并抠图…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black.opacity(0.55))
            )
            .padding(24)
        }
    }

    private func processCapturedImage(_ image: UIImage) {
        guard !isProcessing else { return }
        isProcessing = true

        // Use GCD here to avoid strict Sendable capture constraints while still keeping heavy Vision work off the main thread.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let cutoutImage = try extractor.extractLargestSubjectCutout(from: image)
                let fileName = "\(UUID().uuidString).png"
                _ = try fileStore.savePNG(cutoutImage, fileName: fileName)

                DispatchQueue.main.async {
                    modelContext.insert(SubjectCutout(fileName: fileName))
                    isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    showAlert(title: "处理失败", message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
            }
        }
    }

    private func deleteCutout(_ cutout: SubjectCutout) {
        withAnimation {
            do {
                try fileStore.deleteFileIfExists(fileName: cutout.fileName)
            } catch {
                // If the file is missing/can't be removed, still remove the DB record.
            }
            modelContext.delete(cutout)
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isShowingAlert = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SubjectCutout.self, inMemory: true)
}

private struct SubjectCutoutCell: View {
    let fileURL: URL?
    let onDelete: () -> Void

    @State private var uiImage: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .transition(.opacity)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .task(id: fileURL) {
            guard let fileURL else {
                uiImage = nil
                return
            }
            uiImage = UIImage(contentsOfFile: fileURL.path)
        }
    }
}
