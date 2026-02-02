//
//  SubjectCutoutFileStore.swift
//  VisionKit_test
//
//  Created by Codex on 2026/2/2.
//

import Foundation
import UIKit

enum SubjectCutoutFileStoreError: LocalizedError {
    case documentsDirectoryUnavailable
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "Could not access the Documents directory."
        case .pngEncodingFailed:
            return "Could not encode the cutout as PNG."
        }
    }
}

struct SubjectCutoutFileStore {
    private let fileManager: FileManager
    private let directoryName = "subject_cutouts"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func directoryURL() throws -> URL {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw SubjectCutoutFileStoreError.documentsDirectoryUnavailable
        }

        let dirURL = documentsURL.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: dirURL.path) {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }

        return dirURL
    }

    func fileURL(for fileName: String) throws -> URL {
        try directoryURL().appendingPathComponent(fileName)
    }

    @discardableResult
    func savePNG(_ image: UIImage, fileName: String) throws -> URL {
        guard let data = image.pngData() else {
            throw SubjectCutoutFileStoreError.pngEncodingFailed
        }

        let url = try fileURL(for: fileName)
        try data.write(to: url, options: [.atomic])
        return url
    }

    func deleteFileIfExists(fileName: String) throws {
        let url = try fileURL(for: fileName)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}

