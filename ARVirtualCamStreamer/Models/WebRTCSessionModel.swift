//
//  WebRTCStateManager.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import Foundation
import WebRTC
import Combine

class WebRTCSessionModel: WebRTCClientDelegate, ObservableObject {
    let webRTCClient: WebRTCClient
    let signalingClient: SignalingClient
    
    @Published var connectionState: RTCIceConnectionState = .new
    @Published var receivedData: Data?
    @Published var peerConnectionStatus: String = ""
    
    private var cancellables = Set<AnyCancellable>()

    var remoteVideoTracks: Published<[String: RemoteRTCVideoTrack]>.Publisher { webRTCClient.$remoteVideoTracks }
    var localVideoTracks: Published<[String: LocalRTCVideoTrack]>.Publisher { webRTCClient.$localVideoTracks }
    
    var remoteDataChannels: Published<[String: ActiveRTCDataChannel]>.Publisher { webRTCClient.$remoteDataChannels }
    var localDataChannels: Published<[String: ActiveRTCDataChannel]>.Publisher { webRTCClient.$localDataChannels }
    
    init(webRTCClient: WebRTCClient, signalingClient: SignalingClient) {
        self.signalingClient = signalingClient
        self.webRTCClient = webRTCClient
        webRTCClient.delegate = self
    }
    
    
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        self.signalingClient.sendCandidate(candidate: candidate)
    }
    
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = state
            // self.connectionStatusLabel = state.description.capitalized
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        DispatchQueue.main.async {
            let message = String(data: data, encoding: .utf8) ?? "(Binary: \(data.count) bytes)"
            print("Received message: \(message)")
            self.receivedData = data
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didAddStream stream: RTCMediaStream) {
        DispatchQueue.main.async {
            for _ in stream.videoTracks {
                //self.remoteTracks.append(RemoteRTCVideoTrack(track: track))
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, didRemoveStream stream: RTCMediaStream) {
        DispatchQueue.main.async {
            for _ in stream.videoTracks {
//                if let index = self.remoteTracks.firstIndex(of: stream) {
//                    self.remoteStreams.remove(at: index)
//                }
            }
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, peerConnectionUpdate update: String) {
        DispatchQueue.main.async {
            self.peerConnectionStatus = update
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, remoteDataChannelAdded dataChannel: ActiveRTCDataChannel) {
        print("Remote data channel added: \(dataChannel)")
        DispatchQueue.main.async {
             //self.dataChannels.append(dataChannel)
        }
    }
    
    func webRTCClient(_ client: WebRTCClient, dataChannelDidChangeState dataChannel: RTCDataChannel) {
        print("Data channel state changed: \(dataChannel.label) -> \(dataChannel.readyState)")
    }

    func startCaptureLocalVideo(renderer: RTCVideoRenderer) {
        self.webRTCClient.startCaptureLocalVideo(renderer: renderer, trackId: "video0")
    }
}
