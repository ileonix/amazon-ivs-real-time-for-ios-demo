//
//  StreamingModel.swift
//  IVS Real-time
//
//  Unified model to switch between Real-time Stages and Broadcast Sessions
//

import SwiftUI
import AmazonIVSBroadcast
import Foundation

class StreamingModel: ObservableObject {
    @Published var useBroadcastMode: Bool = false {
        didSet {
            print("Switching to \(useBroadcastMode ? "Broadcast" : "Real-time Stage") mode")
        }
    }
    
    // Real-time stage components
    @Published var stageModel: StageModel
    
    // Broadcast session components  
    @Published var broadcastModel: BroadcastModel
    
    // Server model (shared)
    @Published var serverModel: ServerModel
    
    init() {
        self.stageModel = StageModel()
        self.broadcastModel = BroadcastModel()
        self.serverModel = ServerModel()
        
        // Sync the mode flag
        self.serverModel.useBroadcastMode = useBroadcastMode
    }
    
    // MARK: - Unified Interface
    
    func createSession(user: User, onComplete: @escaping (Bool) -> Void) {
        if useBroadcastMode {
            createBroadcastSession(user: user, onComplete: onComplete)
        } else {
            createStageSession(user: user, onComplete: onComplete)
        }
    }
    
    func startStreaming(user: User) {
        if useBroadcastMode {
            broadcastModel.startBroadcast()
        } else {
            stageModel.publish(user)
        }
    }
    
    func stopStreaming(user: User) {
        if useBroadcastMode {
            broadcastModel.stopBroadcast()
        } else {
            stageModel.unpublish(user)
        }
    }
    
    func applyFilter(_ filterName: String) {
        if useBroadcastMode {
            broadcastModel.applyFilter(filterName)
        } else {
            stageModel.localUser.applyFilter(filterName)
        }
    }
    
    // MARK: - Private Methods
    
    private func createBroadcastSession(user: User, onComplete: @escaping (Bool) -> Void) {
        serverModel.createChannel(user: user) { [weak self] success, credentials in
            if success, let credentials = credentials {
                self?.broadcastModel.channelCredentials = credentials
                self?.broadcastModel.setupBroadcastSession()
                onComplete(true)
            } else {
                onComplete(false)
            }
        }
    }
    
    private func createStageSession(user: User, onComplete: @escaping (Bool) -> Void) {
        // Use existing stage creation logic
        stageModel.joinAsHost { success in
            onComplete(success)
        }
    }
}