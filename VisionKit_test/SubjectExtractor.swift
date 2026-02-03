//
//  SubjectExtractor.swift
//  VisionKit_test
//
//  Created by Codex on 2026/2/2.
//

import CoreImage
import ImageIO
import UIKit
import Vision

struct SubjectExtractionResult {
    let fullSizeCutout: UIImage
    let croppedCutout: UIImage
}

enum SubjectExtractorError: LocalizedError {
    case invalidImage
    case noForegroundInstances
    case maskImageGenerationFailed(underlying: Error)
    case outputImageCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "图片无效，无法处理。"
        case .noForegroundInstances:
            return "未识别到主体，请换一张更清晰的照片。"
        case .maskImageGenerationFailed:
            return "生成主体抠图失败。"
        case .outputImageCreationFailed:
            return "输出图片创建失败。"
        }
    }
}

struct SubjectExtractor {
    private let ciContext: CIContext

    init(ciContext: CIContext = CIContext()) {
        self.ciContext = ciContext
    }

    func extractLargestSubject(from image: UIImage) throws -> SubjectExtractionResult {
        guard let cgImage = image.cgImage else {
            throw SubjectExtractorError.invalidImage
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw SubjectExtractorError.noForegroundInstances
        }

        guard let largestInstanceId = Self.largestInstanceId(in: observation) else {
            throw SubjectExtractorError.noForegroundInstances
        }

        let instances = IndexSet(integer: largestInstanceId)

        do {
            let fullSizePixelBuffer = try observation.generateMaskedImage(
                ofInstances: instances,
                from: handler,
                croppedToInstancesExtent: false
            )

            let croppedPixelBuffer = try observation.generateMaskedImage(
                ofInstances: instances,
                from: handler,
                croppedToInstancesExtent: true
            )

            let fullSizeCutout = try makeUIImage(from: fullSizePixelBuffer, scale: image.scale)
            let croppedCutout = try makeUIImage(from: croppedPixelBuffer, scale: image.scale)

            return SubjectExtractionResult(fullSizeCutout: fullSizeCutout, croppedCutout: croppedCutout)
        } catch {
            throw SubjectExtractorError.maskImageGenerationFailed(underlying: error)
        }
    }

    private func makeUIImage(from pixelBuffer: CVPixelBuffer, scale: CGFloat) throws -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let outputCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw SubjectExtractorError.outputImageCreationFailed
        }
        return UIImage(cgImage: outputCGImage, scale: scale, orientation: .up)
    }

    private static func largestInstanceId(in observation: VNInstanceMaskObservation) -> Int? {
        let allInstances = observation.allInstances
        guard !allInstances.isEmpty else { return nil }

        let pixelBuffer = observation.instanceMask
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return allInstances.first
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        var counts: [Int: Int] = [:]
        counts.reserveCapacity(min(16, allInstances.count))

        func bump(_ value: Int) {
            guard value > 0 else { return } // 0 == background
            counts[value, default: 0] += 1
        }

        switch pixelFormat {
        case kCVPixelFormatType_OneComponent8:
            for y in 0..<height {
                let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
                for x in 0..<width {
                    bump(Int(row[x]))
                }
            }
        case kCVPixelFormatType_OneComponent16:
            for y in 0..<height {
                let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt16.self)
                for x in 0..<width {
                    bump(Int(row[x]))
                }
            }
        case kCVPixelFormatType_OneComponent32Float:
            for y in 0..<height {
                let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float.self)
                for x in 0..<width {
                    bump(Int(row[x].rounded()))
                }
            }
        default:
            // Fallback to first instance if we can't inspect the mask format.
            return allInstances.first
        }

        if let (id, _) = counts.max(by: { $0.value < $1.value }) {
            return id
        }

        return allInstances.first
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
