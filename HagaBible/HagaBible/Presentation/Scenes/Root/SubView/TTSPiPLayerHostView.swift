//
//  TTSPiPLayerHostView.swift
//  HagaBible
//
//  Created by 양시준 on 8/19/26.
//

import AVFoundation
import SwiftUI

/// Hosts the `AVSampleBufferDisplayLayer` behind the TTS Picture-in-Picture window.
/// AVKit only allows PiP to start from a layer that is installed in the app's view
/// hierarchy, so RootView embeds this view at 1×1pt (near-invisible, non-interactive)
/// while a TTS session is active. All rendering and PiP control lives in
/// `TTSPictureInPictureService`; this view only supplies the layer.
struct TTSPiPLayerHostView: UIViewRepresentable {
    let service: TTSPictureInPictureService

    func makeUIView(context: Context) -> DisplayLayerView {
        let view = DisplayLayerView()
        view.service = service
        service.attach(layer: view.displayLayer)
        return view
    }

    func updateUIView(_ uiView: DisplayLayerView, context: Context) {
        // Re-attach after a detach that outlived this view (attach no-ops while the
        // same layer is already connected).
        service.attach(layer: uiView.displayLayer)
    }

    static func dismantleUIView(_ uiView: DisplayLayerView, coordinator: ()) {
        // RootView dropped the host (session ended / TTS disabled): tear down PiP so
        // the controller never outlives its off-hierarchy layer.
        uiView.service?.detach()
    }

    final class DisplayLayerView: UIView {
        override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

        var displayLayer: AVSampleBufferDisplayLayer {
            layer as! AVSampleBufferDisplayLayer
        }

        weak var service: TTSPictureInPictureService?
    }
}
