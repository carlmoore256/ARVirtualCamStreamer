//
//  DepthCameraSession.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import Foundation
import ARKit

struct Dimensions {
    var width: Int
    var height: Int
}

class DepthCameraSessionBasic : NSObject, AVCaptureDepthDataOutputDelegate, ObservableObject {
    @Published var isRunning: Bool = false
    @Published var depthBuffer: CVPixelBuffer?
    @Published var timestamp: CMTime?
    @Published var depthQuality: AVDepthData.Quality?
    @Published var depthAccuracy: AVDepthData.Accuracy?
    @Published var calibrationData: AVCameraCalibrationData?
    @Published var depthDataType: OSType?
    @Published var dimensions: Dimensions?
    
    var captureSession: AVCaptureSession
    
//    var onGetDepthFrame: (depth) -> Void
    
    init(position: AVCaptureDevice.Position = .back) {
        self.captureSession = AVCaptureSession()
        super.init()
        initCaptureSession(position: position)
    }
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        
        print("Received depth capture in delegate!")
        if self.dimensions == nil {
            let width = CVPixelBufferGetWidth(depthData.depthDataMap)
            let height = CVPixelBufferGetHeight(depthData.depthDataMap)
            self.dimensions = Dimensions(width: width, height: height)
        }
        self.depthBuffer = depthData.depthDataMap
        self.depthQuality = depthData.depthDataQuality
        self.depthAccuracy = depthData.depthDataAccuracy
        self.calibrationData = depthData.cameraCalibrationData
        self.depthDataType = depthData.depthDataType
        self.timestamp = timestamp
    }
    
    func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            DispatchQueue.main.async { // Update UI on the main thread
                self.isRunning = true
            }
        }
    }
    
    func stop() {
        // Stop on the background thread as well
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
            DispatchQueue.main.async { // Update UI on the main thread
                self.isRunning = false
            }
        }
    }
    
    private func initCaptureSession(position: AVCaptureDevice.Position) {
        let depthDataOutput = AVCaptureDepthDataOutput()
        depthDataOutput.setDelegate(self, callbackQueue: DispatchQueue.main)
        let deviceType: AVCaptureDevice.DeviceType = position == .front ? .builtInTrueDepthCamera : .builtInLiDARDepthCamera
        if let device = AVCaptureDevice.default(deviceType, for: .video, position: position) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                self.captureSession.addInput(input)
                self.captureSession.addOutput(depthDataOutput)
            } catch {
                print("Error setting up depth data output: \(error)")
            }
        }
    }
}
