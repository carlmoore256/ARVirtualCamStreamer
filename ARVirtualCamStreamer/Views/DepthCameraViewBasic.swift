//
//  DepthCameraView.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import Foundation
import SwiftUI
import AVFoundation

struct DepthCameraViewBasic : View {
    
    @StateObject var depthCameraSession: DepthCameraSessionBasic = DepthCameraSessionBasic()
    @State var pixelBuffer: CVPixelBuffer?
    var webRTCClient: WebRTCClient
    
    init(webRTClient: WebRTCClient) {
        self.webRTCClient = webRTClient
    }
    
    var body: some View {
        VStack {
            Text(depthCameraSession.isRunning ? "Depth Streaming" : "Depth Not Started")
            Text("Quality: \(depthCameraSession.depthQuality != nil ? (depthCameraSession.depthQuality == .low ? "Low" : "High") : "None")")
            Text("Width: \(depthCameraSession.dimensions?.width ?? 0) Height: \(depthCameraSession.dimensions?.height ?? 0)")
            HStack {
                Button("Start Depth", action: depthCameraSession.start).buttonStyle(RoundedButtonStyle())
                Button("Stop Depth", action: depthCameraSession.stop).buttonStyle(RoundedButtonStyle())

            }
            PixelBufferView(pixelBuffer: self.pixelBuffer)
                .onAppear { depthCameraSession.start() }
                .onDisappear { depthCameraSession.stop() } 
                .onChange(of: depthCameraSession.depthBuffer) { newBuffer in
                    if let newBuffer = newBuffer {
                        // webRTCClient.feedFrameToVideoTrack
                        DispatchQueue.main.async {
                            self.pixelBuffer = newBuffer
                        }
                    }
                }
        }
        .padding()
    }
}
