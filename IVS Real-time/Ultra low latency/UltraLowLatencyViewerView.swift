//
//  UltraLowLatencyViewerView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 10/11/2568 BE.
//

import SwiftUI
import AmazonIVSPlayer
import LiveCommerceSDK

struct UltraLowLatencyViewerView: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let channel: ChannelDetails
    @State private var player: IVSPlayer?
    @State private var playerView: IVSPlayerView?
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button
                HStack {
                    Button {
                        appModel.selectedChannel = nil
                        appModel.isReadyToGoCustomerLanding = true
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    Spacer()
                    Text("Live Stream")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left")
                        .foregroundColor(.clear)
                        .font(.title2)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Player View
                if let playerView = playerView {
                    PlayerViewRepresentable(playerView: playerView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        )
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanupPlayer()
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: channel.playbackUrl) else {
            print("Invalid playback URL for Ultra Low Latency stream")
            return
        }
        
        player = IVSPlayer()
        playerView = IVSPlayerView()
        playerView?.player = player
        
        // Hide player controls
        playerView?.isUserInteractionEnabled = false
        
        player?.load(url)
        player?.play()
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player = nil
        playerView = nil
    }
}

struct PlayerViewRepresentable: UIViewRepresentable {
    let playerView: IVSPlayerView
    
    func makeUIView(context: Context) -> IVSPlayerView {
        return playerView
    }
    
    func updateUIView(_ uiView: IVSPlayerView, context: Context) {
        // No updates needed
    }
}
