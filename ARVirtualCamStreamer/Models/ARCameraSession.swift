//
//  ARCameraSession.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import Foundation
import AVFoundation
import ARKit

class ARCameraSession: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureDepthDataOutputDelegate, ObservableObject {
    @Published var colorImage: UIImage?
    @Published var depthBuffer: CVPixelBuffer?
    
    private let depthDataQueue = DispatchQueue(label: "carlmoore.ARVirtualCamStreamer.depthDataQueue", qos: .userInteractive)
    // ... other published properties as needed
    
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    
    let videoOutput = AVCaptureVideoDataOutput()
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard let device = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) else {
            print("No dual camera found")
            return
        }
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("Could not initialize camera input: \(error)")
            return
        }
        
        
//        if session.canAddOutput(videoOutput) {
//            session.addOutput(videoOutput)
//            videoOutput.setSampleBufferDelegate(videoPreviewView?.coordinator, queue: DispatchQueue(label: "videoQueue"))
//        }
        
        // Configure photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        
        // Configure depth output
        if session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            depthOutput.setDelegate(self, callbackQueue: DispatchQueue.main)
        }
    }
    
    func start() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?, Error?) -> Void) {
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        photoCaptureCompletionBlock = completion
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCaptureCompletionBlock?(nil, error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: imageData) else {
            photoCaptureCompletionBlock?(nil, NSError(domain: "ARCameraSessionErrorDomain", code: 1, userInfo: nil))
            return
        }
        
        colorImage = capturedImage
        photoCaptureCompletionBlock?(capturedImage, nil)
    }
    
    // MARK: - AVCaptureDepthDataOutputDelegate
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // depthBuffer = depthData.depthDataMap
        // Handle depth data, e.g., update a published property
        depthDataQueue.async {
            // Create a new pixel buffer to copy into
            var newPixelBuffer: CVPixelBuffer?
            let width = CVPixelBufferGetWidth(depthData.depthDataMap)
            let height = CVPixelBufferGetHeight(depthData.depthDataMap)
            let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_DepthFloat32, nil, &newPixelBuffer)
            
            guard status == kCVReturnSuccess, let newPixelBuffer = newPixelBuffer else {
                print("Error creating new pixel buffer: \(status)")
                return
            }
            
            // Lock the buffers for safe access
            CVPixelBufferLockBaseAddress(depthData.depthDataMap, CVPixelBufferLockFlags(rawValue: 0))
            CVPixelBufferLockBaseAddress(newPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            // Copy the pixel data (adjust for your specific depth format if needed)
            let sourceBaseAddress = CVPixelBufferGetBaseAddress(depthData.depthDataMap)
            let newBaseAddress = CVPixelBufferGetBaseAddress(newPixelBuffer)
            if let sourceBaseAddress = sourceBaseAddress, let newBaseAddress = newBaseAddress {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(depthData.depthDataMap)
                memcpy(newBaseAddress, sourceBaseAddress, height * bytesPerRow)
            }
            
            // Unlock the buffers
            CVPixelBufferUnlockBaseAddress(depthData.depthDataMap, CVPixelBufferLockFlags(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(newPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            // Publish the copied buffer on the main thread
            DispatchQueue.main.async {
                self.depthBuffer = newPixelBuffer
            }
        }
    }
}
