import SwiftUI
import LiveCommerceSDK
import AmazonIVSBroadcast

struct LiveRealtimeStageView: View {
    @EnvironmentObject var appModel: AppModel
    @StateObject private var realtimeManager = LiveCommerceSDK.createRealtimeManager()
    
    let stage: Stage
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Use SDK's Real-time functionality
            RealtimeStreamView(manager: realtimeManager)
            
            // Overlay with stage-specific UI
            StageOverlayView(stage: stage)
        }
        .onAppear {
            joinStage()
        }
        .onDisappear {
            realtimeManager.leaveStage()
        }
    }
    
    private func joinStage() {
        if appModel.user.isHost {
            // Host joins with host token
            if let hostToken = appModel.user.hostParticipantToken?.tokenData.token {
                realtimeManager.joinStage(token: hostToken)
            }
        } else {
            // Participant joins with participant token
            if let participantToken = appModel.user.participantToken {
                realtimeManager.joinStage(token: participantToken)
            }
        }
    }
}

/// Custom Real-time stream view using SDK manager
private struct RealtimeStreamView: View {
    @ObservedObject var manager: RealtimeManager
    
    var body: some View {
        ZStack {
            // Participants grid
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(manager.participants) { participant in
                    ParticipantStreamView(participant: participant)
                }
            }
            .padding()
            
            VStack {
                Spacer()
                
                // Control buttons
                HStack(spacing: 20) {
                    Button(action: manager.toggleAudioMute) {
                        Image(systemName: manager.localUserAudioMuted ? "mic.slash.fill" : "mic.fill")
                            .foregroundColor(manager.localUserAudioMuted ? .red : .white)
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        if manager.localUserWantsPublish {
                            manager.stopPublishing()
                        } else {
                            manager.startPublishing()
                        }
                    }) {
                        Image(systemName: manager.localUserWantsPublish ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundColor(manager.localUserWantsPublish ? .red : .green)
                            .font(.largeTitle)
                    }
                    
                    Button(action: manager.toggleVideoMute) {
                        Image(systemName: manager.localUserVideoMuted ? "video.slash.fill" : "video.fill")
                            .foregroundColor(manager.localUserVideoMuted ? .red : .white)
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: manager.swapCamera) {
                        Image(systemName: "camera.rotate.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 50)
            }
        }
    }
    
    private var gridColumns: [GridItem] {
        let count = max(1, manager.participants.count)
        let columns = count <= 2 ? 1 : 2
        return Array(repeating: GridItem(.flexible()), count: columns)
    }
}

/// Individual participant stream view
private struct ParticipantStreamView: View {
    @ObservedObject var participant: RealtimeParticipant
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            if let videoStream = participant.streams.first(where: { $0.device is IVSImageDevice }) {
                RealtimeVideoStreamView(stream: videoStream)
            } else {
                VStack {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text(participant.isLocal ? "You" : "Participant")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
        }
        .aspectRatio(9/16, contentMode: .fit)
        .cornerRadius(10)
    }
}

/// Video stream view wrapper
private struct RealtimeVideoStreamView: UIViewRepresentable {
    let stream: IVSStageStream
    
    func makeUIView(context: Context) -> IVSImagePreviewView {
        let previewView = IVSImagePreviewView()
        if let imageDevice = stream.device as? IVSImageDevice {
            previewView.imageDevice = imageDevice
        }
        return previewView
    }
    
    func updateUIView(_ uiView: IVSImagePreviewView, context: Context) {
        // Updates handled by the stream
    }
}