//
//  BroadcastViewModel.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 10/11/2568 BE.
//

import SwiftUI
import AmazonIVSBroadcast
import AVFoundation

class BroadcastViewModel: NSObject, ObservableObject {
    @Published var endpoint: String = ""
    @Published var streamKey: String = ""
    @Published var isRunning: Bool = false
    @Published var isMuted: Bool = false
    @Published var connectionState: IVSBroadcastSession.State = .invalid
    @Published var attachedCamera: IVSDevice?
    @Published var attachedMicrophone: IVSDevice?
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    @Published var showingDeviceSelection: Bool = false
    @Published var deviceSelectionType: IVSDeviceType = .camera
    @Published var availableDevices: [IVSDeviceDescriptor] = []
    
    weak var appModel: AppModel?
    private var broadcastSession: IVSBroadcastSession?
    
    override init() {
        super.init()
        loadLastUsedAuth()
    }
    
    func setupSession() {
        do {
            IVSBroadcastSession.applicationAudioSessionStrategy = .playAndRecord
            let session = try IVSBroadcastSession(
                configuration: IVSPresets.configurations().standardPortrait(),
                descriptors: IVSPresets.devices().frontCamera(),
                delegate: self
            )
            
            session.awaitDeviceChanges { [weak self] in
                DispatchQueue.main.async {
                    let devices = session.listAttachedDevices()
                    let cameras = devices.filter { $0.descriptor().type == .camera }
                    let microphones = devices.filter { $0.descriptor().type == .microphone }
                    
                    self?.attachedCamera = cameras.first
                    self?.attachedMicrophone = microphones.first
                }
            }
            
            self.broadcastSession = session
        } catch {
            showError("Failed to setup session: \(error.localizedDescription)")
        }
    }
    
    func startBroadcast() {
        guard let url = URL(string: endpoint), !streamKey.isEmpty else {
            showError("Invalid endpoint or stream key")
            return
        }
        
        do {
            let authItem = AuthItem(endpoint: endpoint, streamKey: streamKey)
            UserDefaultsAuthDao.shared.insert(authItem)
            
            try broadcastSession?.start(with: url, streamKey: streamKey)
            isRunning = true
        } catch {
            showError("Failed to start broadcast: \(error.localizedDescription)")
        }
    }
    
    func stopBroadcast() {
        broadcastSession?.stop()
        isRunning = false
    }
    
    func toggleMute() {
        isMuted.toggle()
        applyMute()
    }
    
    func showDeviceSelection(for type: IVSDeviceType) {
        deviceSelectionType = type
        availableDevices = IVSBroadcastSession.listAvailableDevices().filter { $0.type == type }
        showingDeviceSelection = true
    }
    
    func selectDevice(_ device: IVSDeviceDescriptor) {
        guard let session = broadcastSession else { return }
        
        switch device.type {
        case .camera:
            if let currentCamera = attachedCamera {
                session.exchangeOldDevice(currentCamera, withNewDevice: device) { [weak self] newDevice, _ in
                    DispatchQueue.main.async {
                        self?.attachedCamera = newDevice
                    }
                }
            } else {
                session.attach(device, toSlotWithName: nil) { [weak self] newDevice, _ in
                    DispatchQueue.main.async {
                        self?.attachedCamera = newDevice
                    }
                }
            }
        case .microphone:
            if let currentMic = attachedMicrophone {
                session.exchangeOldDevice(currentMic, withNewDevice: device) { [weak self] newDevice, _ in
                    DispatchQueue.main.async {
                        self?.attachedMicrophone = newDevice
                    }
                }
            } else {
                session.attach(device, toSlotWithName: nil) { [weak self] newDevice, _ in
                    DispatchQueue.main.async {
                        self?.attachedMicrophone = newDevice
                    }
                }
            }
        default:
            break
        }
    }
    
    private func loadLastUsedAuth() {
        if let lastAuth = UserDefaultsAuthDao.shared.lastUsedAuth() {
            endpoint = lastAuth.endpoint
            streamKey = lastAuth.streamKey
        }
        
    }
    
    private func applyMute() {
        let gain: Float = isMuted ? 0 : 1
        
        broadcastSession?.awaitDeviceChanges { [weak self] in
            DispatchQueue.main.async {
                self?.broadcastSession?.listAttachedDevices()
                    .compactMap { $0 as? IVSAudioDevice }
                    .forEach { $0.setGain(gain) }
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

extension BroadcastViewModel: IVSBroadcastSession.Delegate {
    func broadcastSession(_ session: IVSBroadcastSession, didChange state: IVSBroadcastSession.State) {
        DispatchQueue.main.async {
            self.connectionState = state
            if state == .disconnected || state == .error {
                self.isRunning = false
            }
        }
    }
    
    func broadcastSession(_ session: IVSBroadcastSession, didEmitError error: Error) {
        DispatchQueue.main.async {
            self.showError("Broadcast error: \(error.localizedDescription)")
        }
    }
    
    func broadcastSession(_ session: IVSBroadcastSession, didAddDevice descriptor: IVSDeviceDescriptor) {
        session.awaitDeviceChanges {
            DispatchQueue.main.async {
                let devices = session.listAttachedDevices()
                let cameras = devices.filter { $0.descriptor().type == .camera }
                let microphones = devices.filter { $0.descriptor().type == .microphone }
                
                self.attachedCamera = cameras.first
                self.attachedMicrophone = microphones.first
            }
        }
    }
    
    func broadcastSession(_ session: IVSBroadcastSession, didRemoveDevice descriptor: IVSDeviceDescriptor) {
        session.awaitDeviceChanges {
            DispatchQueue.main.async {
                let devices = session.listAttachedDevices()
                let cameras = devices.filter { $0.descriptor().type == .camera }
                let microphones = devices.filter { $0.descriptor().type == .microphone }
                
                self.attachedCamera = cameras.first
                self.attachedMicrophone = microphones.first
            }
        }
    }
    
    func broadcastSession(_ session: IVSBroadcastSession, audioStatsUpdatedWithPeak peak: Double, rms: Double) {
        // Audio stats updates - can be used for audio level indicators
    }
}
