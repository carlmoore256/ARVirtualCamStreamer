//
//  VideoPreviewView.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import Foundation
import SwiftUI
import AVFoundation

struct VideoPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspectFill
        displayLayer.frame = view.bounds
        view.layer.addSublayer(displayLayer)

        // Update layer frame when view's bounds change
        context.coordinator.displayLayer = displayLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(uiView.bounds)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(displayLayer: nil)
    }

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        weak var displayLayer: AVSampleBufferDisplayLayer?

        init(displayLayer: AVSampleBufferDisplayLayer?) {
            self.displayLayer = displayLayer
        }

        func update(_ bounds: CGRect) {
            DispatchQueue.main.async {
                self.displayLayer?.frame = bounds
            }
        }
        
        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            // Update display layer with new video frame
            displayLayer?.enqueue(sampleBuffer)
        }
    }
}
