//
//  ActivityView.swift
//  HagaBible
//
//  Created by 양시준 on 5/25/26.
//

import SwiftUI
import UIKit

/// Lightweight `UIActivityViewController` wrapper for presenting the system share
/// sheet programmatically — used when the shared text is decided after a dialog
/// (e.g. the 역본 선택 copy/share flow) so a static `ShareLink` is not enough.
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    // No updates needed — the controller is fully configured at creation.
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
