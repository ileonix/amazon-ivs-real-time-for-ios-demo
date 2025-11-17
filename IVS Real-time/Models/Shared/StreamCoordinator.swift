import SwiftUI
import LiveCommerceSDK

/// Coordinates between Real-time and Ultra Low Latency streaming
class StreamCoordinator: ObservableObject {
    @Published var streamType: StreamType = .realtime
    @Published var selectedStage: Stage?
    @Published var selectedChannel: ChannelDetails?
    
    // Real-time components
    @ObservedObject var realtimeManager: RealtimeStreamManager
    
    // Ultra Low Latency components  
    @ObservedObject var ultraLowLatencyManager: UltraLowLatencyStreamManager
    
    // Shared components
    @ObservedObject var server: ServerModel
    @ObservedObject var user: User
    
    enum StreamType {
        case realtime
        case ultraLowLatency
    }
    
    init() {
        self.server = ServerModel()
        self.user = User(isLocal: true, username: UsernameProvider.getRandomUsername(), avatar: Avatar())
        self.realtimeManager = RealtimeStreamManager(server: server, user: user)
        self.ultraLowLatencyManager = UltraLowLatencyStreamManager(server: server, user: user)
    }
    
    func switchToRealtime() {
        streamType = .realtime
        ultraLowLatencyManager.stopBroadcast()
    }
    
    func switchToUltraLowLatency() {
        streamType = .ultraLowLatency
        realtimeManager.leaveStage()
    }
    
    func getAllStreams(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var overallSuccess = true
        
        group.enter()
        realtimeManager.getStages { success in
            if !success { overallSuccess = false }
            group.leave()
        }
        
        group.enter()
        ultraLowLatencyManager.getChannels { success in
            if !success { overallSuccess = false }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(overallSuccess)
        }
    }
}