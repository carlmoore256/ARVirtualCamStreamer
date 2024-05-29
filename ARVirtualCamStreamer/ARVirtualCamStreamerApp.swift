//
//  ARVirtualCamStreamerApp.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import SwiftUI

@main
struct ARVirtualCamStreamerApp: App {
    
    let webRTCClient: WebRTCClient
    let signalingClient: SignalingClient
    
    @StateObject private var webRTCSession: WebRTCSessionModel
    @StateObject private var signalingClientSession: SignalingClientSessionModel
    
    init() {
        self.webRTCClient = WebRTCClient(iceServers: WebRTCConfig.default.iceServers, streamId: WebRTCConfig.default.streamId)
        self.signalingClient = SignalingClient(serverUrl: WebRTCConfig.default.signalingServerUrl)
        
        let webRTCSession = WebRTCSessionModel(webRTCClient: webRTCClient, signalingClient: signalingClient)
        self._webRTCSession = StateObject(wrappedValue: webRTCSession)
        
        let signalingClientSession = SignalingClientSessionModel(webRTCClient: webRTCClient, signalingClient: signalingClient)
        self._signalingClientSession = StateObject(wrappedValue: signalingClientSession)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
            ConnectionView()
                .environmentObject(webRTCSession)
                .environmentObject(signalingClientSession)
                .onAppear() {
                    print("Connecting signaling client")
                    self.signalingClient.connect()
                }
        }
    }
}
