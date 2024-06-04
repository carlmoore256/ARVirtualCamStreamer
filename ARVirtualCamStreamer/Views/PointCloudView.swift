//
//  PointCloudView.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/30/24.
//

import Foundation
import SwiftUI
import AVFoundation
import MetalKit


struct PointCloudView : View {
    let depthCameraSession: DepthCameraSession
    @State private var depthData: AVDepthData?
    @State private var unormTexture: CVPixelBuffer?
    let imageWidth: CGFloat = 180
    let imageHeight: CGFloat = 180
    
    var body: some View {
        VStack {
            // PointCloudRendererView(depthData: depthData, unormTexture: unormTexture)
            HStack {
                PixelBufferView(pixelBuffer: depthData?.depthDataMap, filter: { image in
                    return depthToHueRotationFilter(ciImage: image)
                })
                .frame(width: imageWidth, height: imageHeight)
                .border(Color.gray, width: 1)
                .clipped()
                PixelBufferView(pixelBuffer: unormTexture)
                    .frame(width: imageWidth, height: imageHeight)
                    .border(Color.gray, width: 1)
                    .clipped()
            }.onAppear {
                depthCameraSession.start()
                depthCameraSession.addUpdateListener(id: "pointCloudView") { depthData, unormTexture, _  in
                    DispatchQueue.main.async {
                        self.depthData = depthData
                        self.unormTexture = unormTexture
                    }
                }
            }.onDisappear {
                depthCameraSession.removeUpdateListener(id: "pointCloudView")
                depthCameraSession.stop()
            }
        }
        .padding()
    }
}



struct PointCloudRendererView : UIViewRepresentable {
    // Optional: Properties to customize or control your view
    // For example:
    var depthData: AVDepthData?
    var unormTexture: CVPixelBuffer?
    
    func makeUIView(context: Context) -> PointCloudMetalView {
        let metalView = PointCloudMetalView()
        // Additional configuration, if needed:
        // metalView.device = MTLCreateSystemDefaultDevice()
        // metalView.colorPixelFormat = .bgra8Unorm
        // ...
        return metalView
    }
    
    func updateUIView(_ uiView: PointCloudMetalView, context: Context) {
        // Update the Metal view with new data or settings:
        if let depthData = depthData, let unormTexture = unormTexture {
            uiView.setDepthFrame(depthData, withTexture: unormTexture)
        }
    }
}
