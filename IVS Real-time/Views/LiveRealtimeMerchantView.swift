import SwiftUI
import LiveCommerceSDK
import AmazonIVSBroadcast

struct LiveRealtimeMerchantView: View {
    @EnvironmentObject var appModel: AppModel
    @StateObject private var realtimeManager = LiveCommerceSDK.createRealtimeManager()
    @State private var showingStageCreation = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if realtimeManager.isConnected {
                // Show Real-time stage interface
                RealtimeMerchantInterface(manager: realtimeManager)
            } else {
                // Show stage creation interface
                StageCreationView(showingCreation: $showingStageCreation)
            }
        }
        .onAppear {
            setupRealtimeStreaming()
        }
        .sheet(isPresented: $showingStageCreation) {
            StageCreationSheet()
        }
    }
    
    private func setupRealtimeStreaming() {
        if appModel.user.isHost, let hostToken = appModel.user.hostParticipantToken?.tokenData.token {
            realtimeManager.joinStage(token: hostToken)
            realtimeManager.startPublishing()
        }
    }
}

/// Real-time interface for merchants
private struct RealtimeMerchantInterface: View {
    @EnvironmentObject var appModel: AppModel
    @ObservedObject var manager: RealtimeManager
    
    var body: some View {
        ZStack {
            // Participants view
            ParticipantsView(manager: manager)
            
            // Overlay controls
            VStack {
                // Top controls
                HStack {
                    Button("End Stage") {
                        manager.leaveStage()
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    
                    Spacer()
                    
                    // Connection status
                    HStack {
                        Circle()
                            .fill(manager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .foregroundColor(.white)
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(15)
                }
                .padding()
                
                Spacer()
                
                // Bottom controls
                HStack(spacing: 20) {
                    Button(action: manager.toggleAudioMute) {
                        Image(systemName: manager.localUserAudioMuted ? "mic.slash.fill" : "mic.fill")
                            .foregroundColor(manager.localUserAudioMuted ? .red : .white)
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
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
            
            // E-commerce overlay
            EcommerceOverlay()
        }
    }
}

/// Participants display for merchant view
private struct ParticipantsView: View {
    @ObservedObject var manager: RealtimeManager
    
    var body: some View {
        if manager.participants.isEmpty {
            VStack {
                Image(systemName: "person.2.fill")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("Waiting for participants...")
                    .foregroundColor(.gray)
            }
        } else {
            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(manager.participants) { participant in
                    ParticipantCard(participant: participant)
                }
            }
            .padding()
        }
    }
    
    private var gridColumns: [GridItem] {
        let count = max(1, manager.participants.count)
        let columns = count <= 2 ? 1 : 2
        return Array(repeating: GridItem(.flexible()), count: columns)
    }
}

/// Individual participant card
private struct ParticipantCard: View {
    @ObservedObject var participant: RealtimeParticipant
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            if let videoStream = participant.streams.first(where: { $0.device is IVSImageDevice }) {
                ParticipantVideoView(stream: videoStream)
            } else {
                VStack {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text(participant.isLocal ? "You (Host)" : "Guest")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            
            // Participant controls overlay
            if !participant.isLocal {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Remove") {
                            // Handle participant removal
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                    }
                }
                .padding(8)
            }
        }
        .aspectRatio(9/16, contentMode: .fit)
        .cornerRadius(10)
    }
}

/// Video view for participants
private struct ParticipantVideoView: UIViewRepresentable {
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

/// E-commerce overlay for products
private struct EcommerceOverlay: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                // Product pin overlay
                if let pinnedProduct = appModel.productsViewModel.pinnedProduct {
                    VStack {
                        AsyncImage(url: URL(string: pinnedProduct.imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        
                        Text(pinnedProduct.name)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    .frame(width: 80)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .position(appModel.pinProductPosition)
                }
            }
        }
    }
}

/// Stage creation view
private struct StageCreationView: View {
    @EnvironmentObject var appModel: AppModel
    @Binding var showingCreation: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "video.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Ready to go live?")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Start a Real-time stage to interact with your audience")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Create Stage") {
                showingCreation = true
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

/// Stage creation sheet
private struct StageCreationSheet: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create Real-time Stage")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 15) {
                    Button("Video Stage") {
                        createStage(.video)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Audio Stage") {
                        createStage(.audio)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createStage(_ type: StageType) {
        appModel.createStage(type) { success in
            if success {
                dismiss()
            }
        }
    }
}