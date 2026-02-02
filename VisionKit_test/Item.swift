//
//  Item.swift
//  VisionKit_test
//
//  Created by 赵铭轩 on 2026/2/2.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
