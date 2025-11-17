import SwiftUI
import LiveCommerceSDK

/// Manages IVS Ultra Low Latency streaming (Broadcast)
class UltraLowLatencyStreamManager: ObservableObject {
    @ObservedObject var channelsModel: ChannelsModel
    @StateObject var broadcastManager = LiveCommerceSDK.createBroadcastManager()
    @StateObject var playerManager = LiveCommerceSDK.createPlayerManager()
    
    private let server: ServerModel
    private let user: User
    
    @Published var isStreaming: Bool = false
    @Published var selectedChannel: ChannelDetails?
    
    init(server: ServerModel, user: User) {
        self.server = server
        self.user = user
        self.channelsModel = ChannelsModel()
    }
    
    func getChannels(completion: @escaping (Bool) -> Void) {
        server.getChannels(onlyActive: true) { [weak self] success, channelDetails in
            DispatchQueue.main.async {
                if success {
                    self?.channelsModel.setNewChannels(channelDetails)
                }
            }
            completion(success)
        }
    }
    
    func createChannel(completion: @escaping (Bool, ChannelCredentials?) -> Void) {
        server.createChannel(user: user) { [weak self] success, credentials in
            if success, let credentials = credentials {
                self?.broadcastManager.endpoint = "rtmps://\(credentials.ingestEndpoint)/app/"
                self?.broadcastManager.streamKey = credentials.streamKey
            }
            completion(success, credentials)
        }
    }
    
    func startBroadcast() {
        broadcastManager.startBroadcast()
        isStreaming = broadcastManager.isStreaming
    }
    
    func stopBroadcast() {
        broadcastManager.stopBroadcast()
        isStreaming = false
    }
    
    func playStream(url: String) {
        playerManager.play(url: url)
    }
    
    func stopStream() {
        playerManager.stop()
    }
}