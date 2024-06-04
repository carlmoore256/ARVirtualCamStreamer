//
//  ConnectionView.swift
//  ARVirtualCamStreamer
//
//  Created by Carl Moore on 5/29/24.
//

import SwiftUI
import WebRTC

struct ConnectionView : View {
    @EnvironmentObject private var webRTCSession: WebRTCSession
    @EnvironmentObject private var signalingClientSession: SignalingClientSession
    
    var rtcSessionDidConnect: (RTCSessionDescription?) -> Void
    
    // @StateObject var depthPixelBufferChannel = CVPixelBufferDataChannel()
    // @StateObject var colorPixelBufferChannel = CVPixelBufferDataChannel()
    
    var body: some View {
        VStack(spacing: 20) {
            Divider()
            Text("Available WebRTC Streams:")
//            ForEach(webRTC.remoteTracks) { track in
//                TrackInfoItem(track: track)
//                VideoView(rtcVideoTrack: track.track).frame(maxWidth: 400, maxHeight: 240)
//            }
            Text("Available WebRTC Channels:")
//            ForEach(webRTC.dataChannels) { dataChannel in
//                ChannelDataItem(dataChannel: dataChannel)
//            }
            Divider()
            StatusIndicator(title: "Signaling Server Connected", status: self.signalingClientSession.isConnected)
            StatusIndicator(title: "Local SDP", status: self.signalingClientSession.localSdp != nil)
            StatusIndicator(title: "Remote SDP", status: self.signalingClientSession.remoteSdp != nil).onChange(of: signalingClientSession.remoteSdp, perform: rtcSessionDidConnect)
            Divider()
            VStack(alignment: .leading) {
                Text("Local Candidate Count: \(self.signalingClientSession.localCandidates.count)")
                Text("Remote Candidate Count: \(self.signalingClientSession.remoteCandidates.count)")
                Text("Connection State: \(self.webRTCSession.connectionState.description.capitalized)")
                Text(self.webRTCSession.peerConnectionStatus)
            }
            Divider()
            HStack(spacing: 10) {
                Button("Send Offer", action: self.signalingClientSession.createOffer)
                    .buttonStyle(RoundedButtonStyle())
                Button("Send Answer", action: self.signalingClientSession.createAnswer)
                    .buttonStyle(RoundedButtonStyle())
            }
        }
        .padding([.all], 20)
        
    }
}

struct ChannelDataItem: View {
    let dataChannel: ActiveRTCDataChannel
    var body: some View {
        HStack {
            Text("Channel: \(dataChannel.channel.label)")
            Spacer()
            Text(dataChannel.isLocal ? "Local" : "Remote")
        }
    }
}

struct TrackInfoItem: View {
    let track: any ActiveRTCVideoTrack
    var body: some View {
        HStack {
            Text(track.isLocal ? "Local Stream: \(track.id)" : "Remote Stream: \(track.id)")
            Spacer()
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let status: Bool
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: status ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status ? .green : .red)
        }
    }
}
