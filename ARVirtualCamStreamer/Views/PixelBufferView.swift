//
//  PixelBufferView.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import SwiftUI
import UIKit

struct PixelBufferView: UIViewRepresentable { // Use UIViewRepresentable
    @ObservedObject var pixelBufferChannel: CVPixelBufferDataChannel

    func makeUIView(context: Context) -> UIImageView { // Make a UIImageView
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // Adjust content mode as needed
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        pixelBufferChannel.addBufferListener(id: "viewListener", listener: { pixelBuffer in
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                uiView.image = UIImage(cgImage: cgImage)
            }
        })
    }
}
