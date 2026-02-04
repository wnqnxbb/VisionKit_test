//
//  ContentView.swift
//  VisionKit_test
//
//  Created by 赵铭轩 on 2026/2/2.
//

import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SubjectCutout.createdAt, order: .reverse) private var cutouts: [SubjectCutout]

    @State private var isShowingCamera = false

    @State private var selectedCutout: SubjectCutout?

    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let fileStore = SubjectCutoutFileStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    HStack {
                        Spacer()
                        takePhotoButton
                        Spacer()
                    }
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
            .fullScreenCover(isPresented: $isShowingCamera) {
                SubjectCameraView()
            }
            .sheet(item: $selectedCutout) { cutout in
                SubjectCutoutDetailView(fileURL: try? fileStore.fileURL(for: cutout.fileName))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍照后自动识别主体并保存")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("相机拍照 -> 自动取面积最大的主体 -> 透明 PNG 保存到本地。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var takePhotoButton: some View {
        Button {
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            guard device != nil else {
                showAlert(title: "无法打开相机", message: "当前设备不支持相机（模拟器通常不可用）。")
                return
            }
            isShowingCamera = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.accentColor)

                VStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22, weight: .semibold))
                    Text("拍照抠主体")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            }
            .frame(width: 132, height: 132)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
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
                            onTap: { selectedCutout = cutout },
                            onDelete: { deleteCutout(cutout) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var uiImage: UIImage?

    var body: some View {
        Button(action: onTap) {
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
        }
        .buttonStyle(.plain)
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
