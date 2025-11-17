import SwiftUI

/// Manages IVS Real-time streaming (Stages)
class RealtimeStreamManager: ObservableObject {
    @ObservedObject var stagesModel: StagesModel
    @ObservedObject var stageModel: StageModel
    @ObservedObject var chatModel: ChatModel?
    
    private let server: ServerModel
    private let user: User
    
    @Published var activeStage: Stage?
    @Published var isLoading: Bool = false
    
    init(server: ServerModel, user: User) {
        self.server = server
        self.user = user
        self.stagesModel = StagesModel()
        self.stageModel = StageModel()
        
        stageModel.localUser = user
        stagesModel.delegate = self
        stageModel.delegate = self
    }
    
    func getStages(completion: @escaping (Bool) -> Void) {
        server.getStages(onlyActive: !user.isHost) { [weak self] success, stageDetails in
            DispatchQueue.main.async {
                if success {
                    self?.stagesModel.setNewStages(stageDetails)
                }
            }
            completion(success)
        }
    }
    
    func createStage(_ type: StageType, completion: @escaping (Bool) -> Void) {
        server.createStage(type: type, user: user) { [weak self] success, hostToken in
            if success {
                self?.user.hostParticipantToken = hostToken
                self?.stageModel.joinAsHost { _ in
                    completion(true)
                }
            } else {
                completion(false)
            }
        }
    }
    
    func joinStage(_ stage: Stage) {
        // Real-time stage joining logic
    }
    
    func leaveStage() {
        stageModel.leaveStage()
        chatModel?.disconnect()
        activeStage = nil
    }
}

// MARK: - Delegates
extension RealtimeStreamManager: StagesModelDelegate {
    func activeStageChanged(to stage: Stage?) {
        activeStage = stage
    }
}

extension RealtimeStreamManager: StageModelDelegate {
    func didEmitError(_ error: String) {
        print("Real-time error: \(error)")
    }
    
    func participantJoined(_ participant: IVSParticipantInfo?) {
        // Handle participant joined
    }
    
    func participantLeftOrStoppedPublishing(_ participant: IVSParticipantInfo?) {
        // Handle participant left
    }
    
    func connectionStateChanged() {
        // Handle connection state changes
    }
    
    func participantUsersChanged() {
        // Handle participant changes
    }
}