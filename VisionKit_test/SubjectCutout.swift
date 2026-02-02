//
//  SubjectCutout.swift
//  VisionKit_test
//
//  Created by Codex on 2026/2/2.
//

import Foundation
import SwiftData

@Model
final class SubjectCutout {
    var id: UUID
    var createdAt: Date
    var fileName: String

    init(id: UUID = UUID(), createdAt: Date = Date(), fileName: String) {
        self.id = id
        self.createdAt = createdAt
        self.fileName = fileName
    }
}

