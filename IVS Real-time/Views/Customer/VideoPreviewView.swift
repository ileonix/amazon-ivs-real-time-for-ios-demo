//
//  VideoPreviewView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 17/10/2568 BE.
//

import SwiftUI
import AVFoundation

struct VideoPreview: UIViewRepresentable {
    let url: URL
    let isMuted: Bool
    @Binding var isReady: Bool

    func makeUIView(context: Context) -> PlayerUIView {
        return PlayerUIView(url: url, isMuted: isMuted, isReady: $isReady)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // No dynamic updates needed
    }
    
    class PlayerUIView: UIView {
        private var player: AVPlayer?
        private var playerLayer = AVPlayerLayer()
        private var statusObserver: NSKeyValueObservation?
        private var isReadyBinding: Binding<Bool>
        private let placeholderView = UIView()
        
        init(url: URL, isMuted: Bool, isReady: Binding<Bool>) {
            self.isReadyBinding = isReady
            super.init(frame: .zero)
            setupPlayer(url: url, isMuted: isMuted)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupPlayer(url: URL, isMuted: Bool) {
            backgroundColor = .clear
            
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            player?.isMuted = isMuted
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            
            layer.addSublayer(playerLayer)
            
            // 🔹 Add placeholder
            placeholderView.backgroundColor = UIColor.black
            placeholderView.alpha = 1.0
            placeholderView.layer.cornerRadius = 8
            placeholderView.clipsToBounds = true
            addSubview(placeholderView)
            
            // 🔹 Observe when video is ready
            statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    DispatchQueue.main.async {
                        self.isReadyBinding.wrappedValue = true
                        self.fadeOutPlaceholder()
                        self.player?.play()
                    }
                }
            }
            
            // 🔁 Loop
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.player?.seek(to: .zero)
                self?.player?.play()
            }
        }
        
        private func fadeOutPlaceholder() {
            UIView.animate(withDuration: 0.3) {
                self.placeholderView.alpha = 0
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
            placeholderView.frame = bounds
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            statusObserver?.invalidate()
            player?.pause()
            player = nil
        }
    }
}
