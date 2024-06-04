//
//  DepthCameraSessionNew.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import Foundation
import AVFoundation

class DepthCameraSession : NSObject, AVCaptureDataOutputSynchronizerDelegate {
    // private var cloudView: PointCloudMetalView
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
   
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem) // Communicate with the session and other session objects on this queue
    private let dataOutputQueue = DispatchQueue(label: "video data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private let videoDevice: AVCaptureDevice
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera],
                                                                               mediaType: .video,
                                                                               position: .front)
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    private var setupResult: SessionSetupResult = .success

    
    private var updateListeners : [String : (AVDepthData, CVPixelBuffer, CMTime) -> Void] = [:]
    
    init(videoDevice: AVCaptureDevice = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .unspecified)!) {
        
        self.videoDevice = videoDevice
        super.init()
        
        self.videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice)
        
        guard self.videoDeviceInput != nil, session.canAddInput(videoDeviceInput) else {
            print("Configuration failed!")
            setupResult = .configurationFailed
            return
        }
        
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    deinit {
        //dataOutputQueue.async {
        //self.renderingEnabled = false
        //}
        sessionQueue.async {
            self.session.stopRunning()
        }
    }
    
    func addUpdateListener(id: String, listener: @escaping (AVDepthData, CVPixelBuffer, CMTime) -> Void) {
        updateListeners[id] = listener
    }
    
    func removeUpdateListener(id: String) {
        let res = self.updateListeners.removeValue(forKey: id)
        if res == nil {
            print("DepthCameraSession tried to remove listener with id: \(id) when it didn't yet exist")
        }
    }
    
    private func configureSession() {
        
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        session.sessionPreset = AVCaptureSession.Preset.vga640x480
        
        guard session.canAddInput(videoDeviceInput), session.canAddOutput(videoDataOutput), session.canAddOutput(depthDataOutput) else {
            print("Could not add video device input to the session")
            self.setupResult = .configurationFailed
            return
        }
        
        session.addInput(videoDeviceInput)
        session.addOutput(videoDataOutput)
        session.addOutput(depthDataOutput)
        
        depthDataOutput.isFilteringEnabled = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        
        if let connection = depthDataOutput.connection(with: .depthData) {
            connection.isEnabled = true
        } else {
            print("No AVCaptureConnection")
        }
        
        // Search for highest resolution with half-point depth values
        print("Video device: \(self.videoDevice)")
        let depthFormats = self.videoDevice.activeFormat.supportedDepthDataFormats
        print("Number of depthFormats: \(depthFormats.count) \(depthFormats.description)")
        let filtered = depthFormats.filter({
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
        })
        let selectedFormat = filtered.max(by: {
            first, second in CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
        })
        
        do {
            try self.videoDevice.lockForConfiguration()
            
            self.videoDevice.activeDepthDataFormat = selectedFormat
            self.videoDevice.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
            self.setupResult = .configurationFailed
            return
        }
        
        // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
        // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        outputSynchronizer!.setDelegate(self, queue: dataOutputQueue)
    }
    
    func start() {
        guard self.setupResult == .success else {
            print("Cannot start running, setup of session was not successful!")
            return
        }
        sessionQueue.async {
            self.session.startRunning()
        }
    }
    
    func stop() {
        guard self.setupResult == .success, self.session.isRunning else {
            print("Cannot stop running DepthCameraSession")
            return
        }
        sessionQueue.async {
            self.session.stopRunning()
        }
    }
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard let syncedDepthData: AVCaptureSynchronizedDepthData =
            synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
            let syncedVideoData: AVCaptureSynchronizedSampleBufferData =
            synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else {
                // only work on synced pairs
                return
        }
        
        if syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped {
            return
        }
        
        
        let syncData = synchronizedDataCollection.synchronizedData(for: videoDataOutput)
        let timestamp = syncData?.timestamp ?? CMTime()
        
        let depthData = syncedDepthData.depthData
        let videoSampleBuffer = syncedVideoData.sampleBuffer
        // let formatDescription = CMSampleBufferGetFormatDescription(videoSampleBuffer)
        
        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(videoSampleBuffer) else {
            print("Error getting video pixel buffer")
            return
        }
        
        self.updateListeners.values.forEach({ listener in
            listener(depthData, videoPixelBuffer, timestamp)
        })
    }
    
}
                                                                     
