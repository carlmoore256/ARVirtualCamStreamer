//
//  CVPixelBufferDataChannel.swift
//  ARVirtualCam
//
//  Created by Carl Moore on 5/26/24.
//

import Foundation
import WebRTC
import DataCompression
import Accelerate


// A delegate for an RTCDataChannel which converts an incoming data buffer from RTCDataBuffer into a CVPixelBuffer
class CVPixelBufferDataChannel: NSObject, RTCDataChannelDelegate, ObservableObject  {
    var pixelBuffer: CVPixelBuffer?
    @Published var pixelBufferMetadata: PixelBufferMetadata?
    @Published var averageDataRate: Double = 0
    @Published var averageFrameRate: Int = 0
    
    private var dataReceivedThisSecond: Int = 0
    private var framesReceivedThisSecond: Int = 0
    private var dataRateTimer: Timer?
    var bufferUpdateListeners: [String: ((CVPixelBuffer) -> Void)] = [:]

    override init() {
        super.init()
        dataRateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.averageDataRate = Double(self.dataReceivedThisSecond)
                self.averageFrameRate = self.framesReceivedThisSecond
                self.dataReceivedThisSecond = 0 // Reset for the next second
                self.framesReceivedThisSecond = 0
            }
        }
    }
    
    deinit {
        dataRateTimer?.invalidate()
    }
    
    func addBufferListener(id: String, listener: @escaping (CVPixelBuffer) -> Void) {
        bufferUpdateListeners[id] = listener
    }
    
    func removeBufferListener(id: String) {
        let res = self.bufferUpdateListeners.removeValue(forKey: id)
        if res == nil {
            print("CVPixelBufferDataChannel tried to remove listener with id: \(id) when it didn't yet exist")
        }
    }
    
    
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("Pixel buffer channel changed state: \(dataChannel.readyState)")
    }
    
    func setupPixelBuffer(with metadata: PixelBufferMetadata) {
        var newPixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: metadata.width,
            kCVPixelBufferHeightKey as String: metadata.height,
            kCVPixelBufferPixelFormatTypeKey as String: metadata.pixelFormat,
            kCVPixelBufferBytesPerRowAlignmentKey as String: metadata.bytesPerRow
        ]
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            metadata.width,
            metadata.height,
            metadata.pixelFormat,
            attrs as CFDictionary,
            &newPixelBuffer
        )
        
        if newPixelBuffer == nil {
            print("New pixel buffer is nil!")
            return
        }
        
        DispatchQueue.main.async {
            self.pixelBuffer = newPixelBuffer
        }
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        self.dataReceivedThisSecond += buffer.data.count
        self.framesReceivedThisSecond += 1
        guard let data = buffer.data.decompress(withAlgorithm: .zlib) else {
            print("Failed to decompress data")
            return
        }
        
        if self.pixelBufferMetadata == nil {
            guard let pixelBufferMetadata = PixelBufferMetadata.fromWebRTCDataBuffer(data: data) else {
                print("Error deserializing pixel buffer metadata, unexpected format")
                return
            }
            // Setup the pixel buffer if not already done
            if self.pixelBuffer == nil {
                print("SElf.pixelBuffer is nil, CREATING IT NOW")
                setupPixelBuffer(with: pixelBufferMetadata)
            }
            
            DispatchQueue.main.async {
                self.pixelBufferMetadata = pixelBufferMetadata
            }
        }
        
        guard let pixelBufferMetadata = self.pixelBufferMetadata else {
            print("Pixel buffer metadata is null")
            return
        }
        
        guard let pixelBuffer = self.pixelBuffer else {
            print("Pixel buffer is not initialized")
            return
        }
        
        // Update the pixel buffer with the new data
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        data.suffix(from: 16).withUnsafeBytes { rawBufferPointer in
            guard let rawPointer = rawBufferPointer.baseAddress else {
                return
            }
            memcpy(baseAddress, rawPointer, pixelBufferMetadata.bytesPerRow * pixelBufferMetadata.height)
        }
        
        DispatchQueue.main.async {
            if let pixelBuffer = self.pixelBuffer {
                self.bufferUpdateListeners.values.forEach({ listener in
                    listener(pixelBuffer)
                })
            }
        }
    }
}


struct PixelBufferMetadata {
    var width: Int
    var height: Int
    var pixelFormat: OSType
    var bytesPerRow: Int
    
    static func fromWebRTCDataBuffer(data: Data) -> PixelBufferMetadata? {
        guard data.count >= 16 else {
            return nil // Ensure data has enough bytes for the metadata
        }
        
        let metadata = data.prefix(16)
        return metadata.withUnsafeBytes { pointer in
            let width = Int(pointer.load(as: Int32.self))
            let height = Int(pointer.load(fromByteOffset: 4, as: Int32.self))
            let pixelFormat = pointer.load(fromByteOffset: 8, as: OSType.self)
            let bytesPerRow = Int(pointer.load(fromByteOffset: 12, as: Int32.self))
            
            return PixelBufferMetadata(width: width, height: height,
                                       pixelFormat: pixelFormat,
                                       bytesPerRow: bytesPerRow)
        }
    }
    
    func description() -> String {
        return """
        PixelBufferMetadata:
          Width: \(width)
          Height: \(height)
          Pixel Format: \(fourCCString(from: pixelFormat)) (\(pixelFormat))
          Bytes Per Row: \(bytesPerRow)
        """
    }
    
    private func fourCCString(from ostype: OSType) -> String {
        return String(format: "%c%c%c%c",
                      (ostype >> 24) & 255,
                      (ostype >> 16) & 255,
                      (ostype >> 8) & 255,
                      ostype & 255)
    }
}

