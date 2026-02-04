//
//  SubjectCameraView.swift
//  VisionKit_test
//
//  Created by Codex on 2026/2/3.
//

import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct SubjectCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var cameraService = CameraCaptureService()

    @State private var isCameraReady = false
    @State private var isShowingPermissionDenied = false

    @State private var capturedImage: UIImage?
    @State private var fullSizeCutout: UIImage?
    @State private var croppedCutout: UIImage?

    @State private var isExtracting = false
    @State private var isSaving = false

    @State private var blurRadius: CGFloat = 0
    @State private var dimOpacity: CGFloat = 0
    @State private var cutoutOpacity: CGFloat = 0
    @State private var cutoutScale: CGFloat = 1.08
    @State private var scanOffset: CGFloat = -0.8
    @State private var captureToken = UUID()

    @State private var isShowingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    private let extractor = SubjectExtractor()
    private let fileStore = SubjectCutoutFileStore()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backgroundLayer
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()

                Color.black
                    .opacity(dimOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if isExtracting {
                    scanOverlay
                        .allowsHitTesting(false)
                }

                if let fullSizeCutout {
                    Image(uiImage: fullSizeCutout)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .ignoresSafeArea()
                        .opacity(cutoutOpacity)
                        .scaleEffect(cutoutScale)
                        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
                }

                if isShowingPermissionDenied {
                    permissionDeniedCard
                        .padding(.horizontal, 24)
                }
            }
            .overlay(alignment: .top) {
                topChrome(safeAreaTop: proxy.safeAreaInsets.top)
            }
            .overlay(alignment: .bottom) {
                bottomChrome(safeAreaBottom: proxy.safeAreaInsets.bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .ignoresSafeArea()
        }
        .alert(alertTitle, isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            requestCameraAndStart()
        }
        .onDisappear {
            captureToken = UUID()
            cameraService.stopRunning()
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let capturedImage {
            Image(uiImage: capturedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: blurRadius)
        } else {
            CameraPreviewView(session: cameraService.session)
                .blur(radius: blurRadius)
        }
    }

    private func topChrome(safeAreaTop: CGFloat) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
            }
            Spacer()
            Text("拍照抠主体")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, safeAreaTop + 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(topGradient)
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if isExtracting || isSaving {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                Text(isSaving ? "正在保存主体…" : "正在识别主体…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.55), in: Capsule())
        }
    }

    private func bottomChrome(safeAreaBottom: CGFloat) -> some View {
        VStack(spacing: 12) {
            if !isShowingPermissionDenied {
                statusOverlay
            }

            if isShowingPermissionDenied {
                EmptyView()
            } else if capturedImage == nil {
                shutterButton
            } else {
                capturedControls
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, safeAreaBottom + 14)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(bottomGradient)
                .frame(height: 180)
        }
    }

    private var permissionDeniedCard: some View {
        VStack(spacing: 12) {
            Text("需要相机权限")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("请在系统设置中开启相机权限后重试。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("打开设置") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(18)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var topGradient: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.65),
                .black.opacity(0.35),
                .black.opacity(0.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var bottomGradient: LinearGradient {
        LinearGradient(
            colors: [
                .black.opacity(0.0),
                .black.opacity(0.25),
                .black.opacity(0.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var shutterButton: some View {
        Button {
            capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 6)
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(.white.opacity(0.95))
                    .frame(width: 64, height: 64)
            }
            .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isCameraReady || isExtracting || isSaving)
        .frame(maxWidth: .infinity)
    }

    private var capturedControls: some View {
        HStack(spacing: 12) {
            Button {
                retake()
            } label: {
                Label("重拍", systemImage: "arrow.counterclockwise")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isExtracting || isSaving)

            Button {
                saveAndDismiss()
            } label: {
                Label("保存主体", systemImage: "square.and.arrow.down")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(croppedCutout == nil || isExtracting || isSaving)
        }
    }

    private var scanOverlay: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [
                    .white.opacity(0.0),
                    .white.opacity(0.22),
                    .white.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: max(180, proxy.size.height * 0.35))
            .rotationEffect(.degrees(-12))
            .offset(y: proxy.size.height * scanOffset)
            .blendMode(.screen)
            .onAppear {
                scanOffset = -0.8
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    scanOffset = 1.2
                }
            }
        }
        .compositingGroup()
    }

    private func requestCameraAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureAndStartCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        configureAndStartCamera()
                    } else {
                        isShowingPermissionDenied = true
                    }
                }
            }
        default:
            isShowingPermissionDenied = true
        }
    }

    private func configureAndStartCamera() {
        isShowingPermissionDenied = false

        cameraService.configureSession { result in
            switch result {
            case .success:
                isCameraReady = true
                cameraService.startRunning()
            case .failure(let error):
                isCameraReady = false
                showAlert(title: "相机初始化失败", message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    private func capturePhoto() {
        guard capturedImage == nil, !isExtracting, !isSaving else { return }

        let token = UUID()
        captureToken = token

        fullSizeCutout = nil
        croppedCutout = nil
        cutoutOpacity = 0
        cutoutScale = 1.08
        blurRadius = 0
        dimOpacity = 0
        isExtracting = true

        withAnimation(.easeInOut(duration: 0.25)) {
            dimOpacity = 0.28
        }
        withAnimation(.easeInOut(duration: 0.55)) {
            blurRadius = 28
        }

        cameraService.capturePhoto { result in
            guard captureToken == token else { return }

            switch result {
            case .success(let image):
                let normalized = image.normalizedOrientation()
                capturedImage = normalized
                cameraService.stopRunning()
                extractSubject(from: normalized, token: token)
            case .failure(let error):
                isExtracting = false
                withAnimation(.easeInOut(duration: 0.25)) {
                    blurRadius = 0
                    dimOpacity = 0
                }
                showAlert(title: "拍照失败", message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    private func extractSubject(from image: UIImage, token: UUID) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try extractor.extractLargestSubject(from: image)

                DispatchQueue.main.async {
                    guard captureToken == token else { return }

                    fullSizeCutout = result.fullSizeCutout
                    croppedCutout = result.croppedCutout
                    isExtracting = false
                    withAnimation(.easeOut(duration: 0.28)) {
                        cutoutOpacity = 1
                        cutoutScale = 1
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard captureToken == token else { return }

                    isExtracting = false
                    withAnimation(.easeInOut(duration: 0.25)) {
                        blurRadius = 0
                        dimOpacity = 0
                    }
                    showAlert(title: "识别失败", message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
            }
        }
    }

    private func retake() {
        captureToken = UUID()
        capturedImage = nil
        fullSizeCutout = nil
        croppedCutout = nil
        isExtracting = false
        isSaving = false
        blurRadius = 0
        cutoutOpacity = 0
        cutoutScale = 1.08
        dimOpacity = 0
        if isCameraReady && !isShowingPermissionDenied {
            cameraService.startRunning()
        }
    }

    private func saveAndDismiss() {
        guard !isSaving, let cutoutImage = croppedCutout else { return }

        isSaving = true
        let token = captureToken
        let fileName = "\(UUID().uuidString).png"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try fileStore.savePNG(cutoutImage, fileName: fileName)

                DispatchQueue.main.async {
                    guard captureToken == token else { return }

                    modelContext.insert(SubjectCutout(fileName: fileName))
                    isSaving = false
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    guard captureToken == token else { return }

                    isSaving = false
                    showAlert(title: "保存失败", message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isShowingAlert = true
    }
}

#Preview {
    SubjectCameraView()
        .modelContainer(for: SubjectCutout.self, inMemory: true)
}
