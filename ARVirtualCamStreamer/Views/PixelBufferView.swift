//
//  PixelBufferView.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import SwiftUI
import UIKit
import SwiftUI

struct PixelBufferView: UIViewRepresentable {
    var pixelBuffer: CVPixelBuffer?
    var scale: CGFloat = 1.0
    var orientation: UIImage.Orientation = .right
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var backgroundColor: UIColor = .black
    var filter: ((CIImage) -> CIImage?)?
    let context = CIContext()
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.backgroundColor = self.backgroundColor
        imageView.contentMode = self.contentMode
        imageView.clipsToBounds = true // Ensure the image doesn't overflow
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard let pixelBuffer = pixelBuffer else { return }
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let filterFunc = filter {
            ciImage = filterFunc(ciImage) ?? ciImage
        }
        if let cgImage = self.context.createCGImage(ciImage, from: ciImage.extent) {
            let rotatedImage = UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
            uiView.image = rotatedImage
        }
    }
}
