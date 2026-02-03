//
//  CameraCaptureService.swift
//  VisionKit_test
//
//  Created by Codex on 2026/2/3.
//

import AVFoundation
import UIKit

enum CameraCaptureServiceError: LocalizedError {
    case noCameraDevice
    case cannotAddInput
    case cannotAddOutput
    case captureInProgress
    case photoDataMissing

    var errorDescription: String? {
        switch self {
        case .noCameraDevice:
            return "未找到可用相机。"
        case .cannotAddInput:
            return "相机输入配置失败。"
        case .cannotAddOutput:
            return "相机输出配置失败。"
        case .captureInProgress:
            return "正在拍照，请稍候。"
        case .photoDataMissing:
            return "无法读取拍摄照片数据。"
        }
    }
}

final class CameraCaptureService: NSObject {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?

    private var isConfigured = false
    private var captureCompletion: ((Result<UIImage, Error>) -> Void)?

    func configureSession(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async {
            guard !self.isConfigured else {
                DispatchQueue.main.async { completion(.success(())) }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            do {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    throw CameraCaptureServiceError.noCameraDevice
                }

                let input = try AVCaptureDeviceInput(device: device)
                guard self.session.canAddInput(input) else {
                    throw CameraCaptureServiceError.cannotAddInput
                }
                self.session.addInput(input)
                self.videoInput = input

                guard self.session.canAddOutput(self.photoOutput) else {
                    throw CameraCaptureServiceError.cannotAddOutput
                }
                self.session.addOutput(self.photoOutput)

                self.session.commitConfiguration()
                self.isConfigured = true

                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func startRunning() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopRunning() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        sessionQueue.async {
            guard self.captureCompletion == nil else {
                DispatchQueue.main.async { completion(.failure(CameraCaptureServiceError.captureInProgress)) }
                return
            }

            self.captureCompletion = completion

            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraCaptureService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        sessionQueue.async {
            let completion = self.captureCompletion
            self.captureCompletion = nil

            if let error {
                DispatchQueue.main.async { completion?(.failure(error)) }
                return
            }

            guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion?(.failure(CameraCaptureServiceError.photoDataMissing)) }
                return
            }

            DispatchQueue.main.async { completion?(.success(image)) }
        }
    }
}
