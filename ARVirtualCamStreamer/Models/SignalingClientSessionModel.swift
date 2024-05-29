//
//  SignalingClientStateModel.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import Foundation
import WebRTC

class SignalingClientSessionModel: SignalingClientDelegate, ObservableObject {
    let webRTCClient: WebRTCClient
    let signalingClient: SignalingClient
    
    @Published var isConnected = false
    @Published var localCandidates: [RTCIceCandidate] = []
    @Published var remoteCandidates: [RTCIceCandidate] = []
    @Published var localSdp: RTCSessionDescription?
    @Published var remoteSdp: RTCSessionDescription?

    init(webRTCClient: WebRTCClient, signalingClient: SignalingClient) {
        self.signalingClient = signalingClient
        self.webRTCClient = webRTCClient
        signalingClient.delegate = self
    }
    
    func connect() {
        self.signalingClient.connect()
    }
    
    func signalingClientDidConnect(_ signalClient: SignalingClient) {
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    func signalingClientDidDisconnect(_ signalClient: SignalingClient) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
    
    func signalingClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        self.webRTCClient.set(remoteSdp: sdp) { error in
            if error != nil {
                print("Error setting remote SDP: \(String(describing: error))")
                return
            }
            DispatchQueue.main.async {
                print("Received remote sdp")
                self.remoteSdp = sdp
            }
        }
    }
    
    func signalingClient(_ signalClient: SignalingClient, didSendCandidate candidate: RTCIceCandidate) {
        DispatchQueue.main.async {
            self.localCandidates.append(candidate)
        }
    }
    
    func signalingClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        self.webRTCClient.set(remoteCandidate: candidate) { error in
            if error != nil {
                print("Error setting remote SDP: \(String(describing: error))")
                return
            }
            DispatchQueue.main.async {
                self.remoteCandidates.append(candidate)
            }
        }
    }
    
    func createOffer() {
        self.webRTCClient.offer { (sdp) in
            self.signalingClient.sendSdp(sdp: sdp) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.localSdp = sdp
                    }
                    break
                case .failure(let error):
                    print("Error sending SDP: \(error)")
                    break
                }
            }
        }
    }
    
    func createAnswer() {
        self.webRTCClient.answer { localSdp in
            self.signalingClient.sendSdp(sdp: localSdp) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        self.localSdp = localSdp
                    }
                    break
                case .failure(let error):
                    print("Error sending SDP: \(error)")
                    break
                }
            }
        }
    }
}
