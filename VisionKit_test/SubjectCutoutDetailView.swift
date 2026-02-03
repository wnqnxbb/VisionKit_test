//
//  SubjectCutoutDetailView.swift
//  VisionKit_test
//
//  Created by Codex on 2026/2/3.
//

import SwiftUI
import UIKit

struct SubjectCutoutDetailView: View {
    let fileURL: URL?

    @Environment(\.dismiss) private var dismiss
    @State private var uiImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .navigationTitle("主体大图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
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
}

#Preview {
    SubjectCutoutDetailView(fileURL: nil)
}

