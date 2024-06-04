//
//  ARVirtualCamStreamerApp.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import SwiftUI
import WebRTC
import DataCompression

@main
struct ARVirtualCamStreamerApp: App {
    
    let webRTCClient: WebRTCClient
    let signalingClient: SignalingClient
    
    @StateObject private var webRTCSession: WebRTCSession
    @StateObject private var signalingClientSession: SignalingClientSession
    private var depthCameraSession: DepthCameraSession
    
    private var colorRTCChannel: LocalRTCVideoTrack?
    private var depthRTCChannel: ActiveRTCDataChannel?
    
    init() {
        self.webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers, streamId: WebRTCConfig.default.streamId)
        self.signalingClient = SignalingClient(serverUrl: WebRTCConfig.default.signalingServerUrl)
        
        let webRTCSession = WebRTCSession(webRTCClient: webRTCClient, signalingClient: signalingClient)
        self._webRTCSession = StateObject(wrappedValue: webRTCSession)
        
        let signalingClientSession = SignalingClientSession(webRTCClient: webRTCClient, signalingClient: signalingClient)
        self._signalingClientSession = StateObject(wrappedValue: signalingClientSession)
        
        self.depthCameraSession = DepthCameraSession()
        
        self.colorRTCChannel = webRTCClient.createLocalVideoTrack(trackId: "color")
        self.depthRTCChannel = webRTCClient.createDataChannel(label: "depth")
        
        if self.colorRTCChannel == nil || self.depthRTCChannel == nil {
            print("Error creating channels for WebRTC Client")
            return
        }
        
        // self.depthCameraSession.addUpdateListener(id: "rtcUpdate", listener: depthCameraDidUpdate)
        // TODO: removeUpdateListener when unmounting
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            Divider()
            PointCloudView(depthCameraSession: self.depthCameraSession)
            //DepthCameraViewBasic(webRTClient: webRTCClient)
            ConnectionView(rtcSessionDidConnect: self.rtcSessionDidConnect)
                .environmentObject(webRTCSession)
                .environmentObject(signalingClientSession)
                .onAppear() {
                    print("Connecting signaling client")
                    self.signalingClient.connect()
                    UIApplication.shared.isIdleTimerDisabled = true // Prevent sleep
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false // Allow sleep again
                }
        }
    }
    
    func rtcSessionDidConnect(session: RTCSessionDescription?) {
        guard
            let colorChannel = self.colorRTCChannel,
            let depthChannel = self.depthRTCChannel
        else {
            print("Color or depth RTC data channels are nil")
            return
        }
        
        depthCameraSession.addUpdateListener(id: "rtc") {
            depthData, videoBuffer, timestamp in
            
            let depthBuffer = depthData.depthDataMap
            // depthBuffer.normalize(from: 0.0, to: 8.0, targetMin: 0.0, targetMax: 1.0)
            let depthPayload = depthBuffer.packageWithMetadata()
            guard let compressedDepth = depthPayload.compress(withAlgorithm: .zlib) else {
                print("Error compressing depth data!")
                return
            }
            colorChannel.feedFrame(pixelBuffer: videoBuffer, timeStamp: timestamp)
            depthChannel.sendData(compressedDepth)
        }
    }
    
    // TODO: Remove update listener when session has disconnectedthChannel.sendData(depthData.depthDataMap.packageWithMetadata())
}
