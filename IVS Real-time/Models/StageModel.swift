//
//  StageModel.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 31/03/2023.
//

import SwiftUI
import AmazonIVSBroadcast
import ReplayKit
import AVFoundation

protocol StageModelDelegate: AnyObject {
    func didEmitError(_ error: String)
    func participantJoined(_ participant: IVSParticipantInfo?)
    func participantLeftOrStoppedPublishing(_ participant: IVSParticipantInfo?)
    func connectionStateChanged()
    func participantUsersChanged()
}

class StageModel: NSObject, ObservableObject {
    @Published var primaryCameraName = "None"
    @Published var primaryMicrophoneName = "None"
    @Published var sessionRunning: Bool = false
    @Published var stageConnectionState: IVSStageConnectionState = .disconnected
    @Published var localUserAudioMuted: Bool = false
    @Published var localUserVideoMuted: Bool = false
    @Published var localUserWantsPublish: Bool = false
    @Published var remoteAudioMuted: Bool = false

    @ObservedObject var debugData: DebugData

    var localUser: User
    var stageType: StageType = .video
    var localStreams: [IVSLocalStageStream] = []
    var delegate: StageModelDelegate?
    var collectInboundDebugData: Bool = true

    let deviceDiscovery = IVSDeviceDiscovery()
    let deviceSlotName = UUID().uuidString

    private var debugTimer: Timer?
    private(set) var videoConfig = IVSLocalStageStreamVideoConfiguration()
    private var shouldRepublishWhenEnteringForeground = false
    private var stage: IVSStage?
    
    // For Video Recording
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var isRecording = false
    var participantUsers: [User] = [] {
        didSet {
            delegate?.participantUsersChanged()
        }
    }

    var selectedCamera: IVSDeviceDescriptor? {
        didSet {
            primaryCameraName = selectedCamera?.friendlyName ?? "None"
        }
    }

    var selectedMicrophone: IVSDeviceDescriptor? {
        didSet {
            primaryMicrophoneName = selectedMicrophone?.friendlyName ?? "None"
        }
    }

    override init() {
        self.localUser = User(isLocal: true, username: "", avatar: Avatar())
        self.debugData = DebugData()
        super.init()
        self.setupLocalUser()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mediaServicesLost),
                                               name: AVAudioSession.mediaServicesWereLostNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(mediaServicesReset),
                                               name: AVAudioSession.mediaServicesWereResetNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.mediaServicesWereLostNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    }

    private func setupLocalUser() {
        setupLocalCamera(to: .front)

        // Setup local audio stream for publishing microphone
        let devices = getLocalDevices()
        if let microphone = devices
            .compactMap({ $0 as? IVSMicrophone })
            .first {
            microphone.delegate = self
            // Enable echo cancellation for microphone device
            microphone.isEchoCancellationEnabled = true
            // Add stream with local audio device to localStreams
            self.localStreams.append(IVSLocalStageStream(device: microphone))
        }

        DispatchQueue.main.async {
            self.participantUsers.append(self.localUser)
        }
        localUser.streams = self.localStreams
    }

    private func setupLocalCamera(to position: IVSDevicePosition) {
        if let camera = getLocalDevices().compactMap({ $0 as? IVSCamera }).first {
            if let cameraSource = camera.listAvailableInputSources()
                .first(where: { position == .back ? $0.position == position && $0.isDefault : $0.position == position }) {
                camera.delegate = self
                print("CPK: FILTER Camera delegate set to StageModel")
                print("ℹCPK: local camera source: \(cameraSource)")
                camera.setPreferredInputSource(cameraSource) { [weak self] in
                    if let error = $0 {
                        print("ℹCPK: ❌ Error on setting preferred input source: \(error)")
                    } else {
                        self?.selectedCamera = cameraSource
                        print("CPK: FILTER Camera source set successfully")
                    }
                    print("ℹCPK: localy selected camera: \(String(describing: self?.selectedCamera))")
                }
            }
            let ivsLocalStageStream = IVSLocalStageStream(device: camera, configuration: videoConfig)
            print("CPK: FILTER Created local stage stream with camera")
            
            self.localStreams.append(ivsLocalStageStream)
        } else {
            print("CPK: FILTER No camera device found")
        }
    }

    @objc private func applicationDidEnterBackground() {
        // By default any active broadcast will stop, and all I/O devices will be shutdown until
        // the app is foregrounded again.
        // This behaviour can be changed by using -createAppBackgroundImageSourceWithAttemptTrim:OnComplete:
        // (read more in the documentation)

        let connectingOrConnected = (stageConnectionState == .connecting) || (stageConnectionState == .connected)
        if connectingOrConnected {
            shouldRepublishWhenEnteringForeground = localUserWantsPublish
            localUserWantsPublish = false
            participantUsers
                .compactMap { $0.participantId }
                .forEach {
                    mutatingParticipant($0) { data in
                        data.requiresAudioOnly = true
                    }
                }
            // after changes, refresh stage strategy state
            stage?.refreshStrategy()
        }
    }

    @objc private func applicationWillEnterForeground() {
        if shouldRepublishWhenEnteringForeground {
            localUserWantsPublish = true
            shouldRepublishWhenEnteringForeground = false
        }
        if !participantUsers.isEmpty {
            participantUsers
                .compactMap { $0.participantId }
                .forEach {
                    mutatingParticipant($0) { data in
                        data.requiresAudioOnly = stageType == .audio
                    }
                }
            // after changes, refresh stage strategy state
            stage?.refreshStrategy()
        }
    }

    @objc private func mediaServicesLost() {
        print("ℹCPK: ❌ media services were lost")
    }

    @objc private func mediaServicesReset() {
        print("ℹCPK: media services were reset")
    }

    func joinAsParticipant(_ token: String, onComplete: (Bool) -> Void) {
        print("ℹCPK: Joining stage as participant...")
        joinStage(token, onComplete: onComplete)
    }

    func joinAsHost(onComplete: @escaping (Bool) -> Void) {
        print("ℹCPK: Joining stage as host...")

        guard let hostToken = localUser.hostParticipantToken else {
            print("iCPK:❌ Can't join - no auth token in host stage details")
            onComplete(false)
            return
        }

        joinStage(hostToken.tokenData.token) { success in
            print("ℹCPK: Stage joined as host")
            onComplete(success)
        }
    }
    
    func captureImage(completion: @escaping (URL?) -> Void) {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.windows.first else {
                print("CPK: ❌ No window found")
                return completion(nil)
            }

            let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
            let image = renderer.image { ctx in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }

            guard let imageData = image.jpegData(compressionQuality: 0.9) else {
                print("CPK: ❌ Failed to convert image to JPEG")
                return completion(nil)
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(self.localUser.hostId).jpg")
            try? FileManager.default.removeItem(at: outputURL)

            do {
                try imageData.write(to: outputURL)
                print("CPK: ✅ Screenshot saved to: \(outputURL)")
                completion(outputURL)
            } catch {
                print("❌ Failed to write image to disk: \(error)")
                completion(nil)
            }
        }
    }

    func recordVideo(duration: TimeInterval, completion: @escaping (URL?) -> Void) {
//        guard localUser.isHost, !isRecording else {
//            completion(nil)
//            return
//        }
//
//        let outputPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(localUser.hostId).mp4")
//        try? FileManager.default.removeItem(at: outputPath)
//
//        do {
//            assetWriter = try AVAssetWriter(outputURL: outputPath, fileType: .mp4)
//            let outputSettings: [String: Any] = [
//                AVVideoCodecKey: AVVideoCodecType.h264,
//                AVVideoWidthKey: 720,
//                AVVideoHeightKey: 1280
//            ]
//            assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
//            assetWriterVideoInput?.expectsMediaDataInRealTime = true
//
//            if let writer = assetWriter, let input = assetWriterVideoInput, writer.canAdd(input) {
//                writer.add(input)
//                writer.startWriting()
//                writer.startSession(atSourceTime: .zero)
//                isRecording = true
//                print("CPK: 🎥 Started recording video...")
//
//                DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
//                    self?.stopRecording(completion: completion)
//                }
//            }
//            
//        } catch {
//            print("CPK: ❌ Failed to setup asset writer: \(error)")
//            completion(nil)
//        }
        
        
        let recorder = ScreenRecorder()
        recorder.startRecording(hostId: localUser.hostId) { fileURL in
            if let fileURL = fileURL {
                completion(fileURL)
            } else {
                completion(nil)
            }
        }
    }

    private func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording, let writer = assetWriter else {
            completion(nil)
            return
        }

        isRecording = false
        assetWriterVideoInput?.markAsFinished()
        writer.finishWriting { [weak self] in
            if writer.status == .completed {
                print("CPK: ✅ Video recording finished successfully.")
                completion(writer.outputURL)
            } else {
                print("CPK: ❌ Video recording failed: \(writer.error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
            self?.assetWriter = nil
            self?.assetWriterVideoInput = nil
        }
    }

    private func joinStage(_ token: String, onComplete: (Bool) -> Void) {
        print("ℹCPK: Joining stage")
        do {
            self.stage = nil
            let stage = try IVSStage(token: token, strategy: self)

            // set created stage IVSStageRenderer to self to get all the necessary information about it
            stage.addRenderer(self)
            stage.errorDelegate = self

            try stage.join()
            self.stage = stage

            print("ℹCPK: ✅ stage joined")

            DispatchQueue.main.async {
                self.sessionRunning = true
            }
            onComplete(true)

        } catch {
            print("ℹCPK: ❌ Error joining stage: \(error)")
            onComplete(false)
        }
    }

    func publish(_ user: User) {
        print("ℹCPK: 📢 publishing to stage")
        DispatchQueue.main.async {
            self.localUserWantsPublish = true
        }

        // Setup custom image source and filters for local user
        if user.isLocal {
            user.setupFilterForPublisher()
            
            // Create custom image source for filtering
            if let customImageSource = createCustomImageSource() {
                user.setupCustomImageSource(customImageSource)
            }
        }

        if let participantId = user.participantId {
            toggleSubscribed(forParticipant: participantId)
        }

        delegate?.participantJoined(user.participant)
    }

    func unpublish(_ user: User) {
        print("ℹCPK: ending publishing to stage")
        DispatchQueue.main.async {
            self.localUserWantsPublish = false
        }

        if let participantId = user.participantId {
            toggleSubscribed(forParticipant: participantId)
        }

        delegate?.participantLeftOrStoppedPublishing(user.participant)
    }

    private func createCustomImageSource() -> IVSCustomImageSource? {
        // For real-time stages, you need to use IVSBroadcastSession to create custom sources
        // This is a limitation - real-time stages don't directly support custom sources
        // You would need to implement a hybrid approach or use broadcast sessions
        return nil
    }
    
    func leaveStage() {
        print("ℹCPK: Leaving stage")
        localUser.captureSession?.stopRunning()
        stage?.leave()
        DispatchQueue.main.async {
            while self.participantUsers.count > 1 {
                self.participantUsers.remove(at: self.participantUsers.count - 1)
            }
        }
        DispatchQueue.main.async {
            self.sessionRunning = false
            self.localUserWantsPublish = false
        }
        stage = nil
        endRTCStats()
    }

    func toggleLocalAudioMute() {
        // Find local audio device and update the mute state
        localStreams
            .filter { $0.device is IVSAudioDevice }
            .forEach {
                $0.setMuted(!$0.isMuted)
                localUserAudioMuted = $0.isMuted
                if let audioDevice = $0.device as? IVSAudioDevice {
                    // audio device can be muted by setting its gain to 0
                    audioDevice.setGain(localUserAudioMuted ? 0 : 1)
                }
            }
        localUser.audioOn = !localUserAudioMuted
        localUser.audioMuted = localUserAudioMuted
        print("ℹCPK: Toggled audio, is muted: \(localUserAudioMuted)")
    }

    func toggleLocalVideoMute() {
        // Find local image device and update the mute state
        localStreams
            .filter { $0.device is IVSImageDevice }
            .forEach {
                // image device mute state can be toggled by using `setMuted(Bool)`
                $0.setMuted(!$0.isMuted)
                localUserVideoMuted = $0.isMuted
            }
        localUser.videoOn = !localUserVideoMuted
        print("ℹCPK: Toggled video, is muted: \(localUserVideoMuted)")
    }

    func toggleRemoteAudioMute() {
        participantUsers.forEach { user in
            if user.isLocal { return }
            mutatingParticipant(user.participantId) { data in
                data.toggleAudioMute()
            }
        }
        remoteAudioMuted.toggle()
        print("ℹCPK: Toggled remote audio, is muted: \(remoteAudioMuted)")
    }

    func swapCamera() {
        print("ℹCPK: swapping camera to \(selectedCamera?.position == .front ? "back" : "front")")
        setupLocalCamera(to: selectedCamera?.position == .front ? .back : .front)
    }

    func updateLocalVideoStreamConfiguration() {
        localStreams
            .filter { $0.device is IVSImageDevice }
            .forEach {
                print("Updating VideoConfig for \($0.device.descriptor().friendlyName)")
                $0.setConfiguration(videoConfig)
            }
    }

    func setCamera(_ device: IVSDeviceDescriptor?) {
        setDevice(device, outDevice: \Self.selectedCamera, type: IVSCamera.self, logSource: "setCamera")
    }

    func setMicrophone(_ device: IVSDeviceDescriptor?) {
        setDevice(device, outDevice: \Self.selectedMicrophone, type: IVSMicrophone.self, logSource: "setMicrophone")
    }

    private func getLocalDevices() -> [Any] {
#if targetEnvironment(simulator)
        // We can't use IVSDeviceDiscovery when using simulator
        return []
#else
        // List available devices
        return deviceDiscovery.listLocalDevices()
#endif
    }

    private func setDevice<DeviceType: IVSMultiSourceDevice>(_ inDevice: IVSDeviceDescriptor?,
                                                             outDevice: ReferenceWritableKeyPath<StageModel, IVSDeviceDescriptor?>,
                                                             type: DeviceType.Type,
                                                             logSource: String) {
        guard let localDevice = getLocalDevices().compactMap({ $0 as? DeviceType }).first else { return }

        if let inputSource = inDevice {
            localDevice.setPreferredInputSource(inputSource) { [weak self] in
                if let error = $0 {
                    print("ℹCPK: ❌ error setting device: \(error)")
                } else {
                    self?[keyPath: outDevice] = inputSource
                }
            }
        }

        var localStreamsDidChange = false
        let index = localStreams.firstIndex(where: { $0.device === localDevice })
        if let index = index, inDevice == nil {
            localStreams.remove(at: index)
            localStreamsDidChange = true
        } else if index == nil, inDevice != nil {
            localStreams.append(IVSLocalStageStream(device: localDevice, configuration: videoConfig))
            localStreamsDidChange = true
        }

        if localStreamsDidChange {
            self[keyPath: outDevice] = inDevice
            stage?.refreshStrategy()
            participantUsers[0].streams = localStreams
        }
    }

    func toggleSubscribed(forParticipant participantId: String) {
        mutatingParticipant(participantId) { $0.wantsSubscribed.toggle() }
        // Call `refreshStrategy` to trigger a refresh of all the `IVSStageStrategy` functions
        stage?.refreshStrategy()
    }

    func toggleAudioOnlySubscribe(forParticipant participantId: String) {
        var shouldRefresh = false
        mutatingParticipant(participantId) {
            shouldRefresh = $0.wantsSubscribed
            $0.wantsAudioOnly.toggle()
        }
        if shouldRefresh {
            // Call `refreshStrategy` to trigger a refresh of all the `IVSStageStrategy` functions
            stage?.refreshStrategy()
        }
    }

    func dataForParticipant(_ participantId: String) -> User? {
        if participantId.isEmpty { return nil }
        guard let participant = participantUsers.first(where: { $0.participantId == participantId }) else {
            print("ℹCPK: ❌ StageModel: could not find user for participant with id \(participantId)")
            return nil
        }
        return participant
    }

    func mutatingParticipant(_ participantId: String?, modifier: (inout User) -> Void) {
        guard let index = participantUsers.firstIndex(where: { $0.participantId == participantId }) else {
            print("ℹCPK: ❌ Something is out of sync, investigate")
            return
        }

        var participant = participantUsers[index]
        modifier(&participant)
        self.participantUsers[index] = participant
    }

    // MARK: - RTC stats
    // To obtain RTC stats, call requestRTCStats() on IVSStageStream and wait for
    // the stream(didGenerateRTCStats:) callback on IVSStageStreamDelegate

    func startRTCStats() {
        // get stats each second
        guard debugTimer == nil else { return }
        debugTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.getRTCStats()
        })
    }

    func endRTCStats() {
        // stop getting stats
        debugTimer?.invalidate()
        debugTimer = nil
    }

    func createRTCStats(for stream: IVSStageStream, username: String?) {
        if debugData.participantStats[stream.device.tag()] == nil {
            debugData.participantStats[stream.device.tag()] = DebugStats(username: username ?? "")
            print("ℹCPK: created participant stats slot for \(stream.device.tag())")
        }
    }

    func removeRTCStats(for stream: IVSStageStream) {
        if let index = debugData.participantStats.index(forKey: stream.device.tag()) {
            debugData.participantStats.remove(at: index)
            print("ℹCPK: removed participant stats slot for \(stream.device.tag())")
        }
    }

    private func getRTCStats() {
        participantUsers.forEach { user in
            user.streams.forEach { stream in
                do {
                    try stream.requestRTCStats()
                } catch {
                    print("ℹCPK: ❌ failed to request RTC stats: \(error)")
                }
            }
        }
    }

    func parseRTCStats(for stream: IVSStageStream, stats: [String: [String: String]]) {
        print("ℹCPK: \(stream.description) didGenerate stats for device with tag \(stream.device.tag())")
        if stream.device is IVSAudioDevice {
            parseAudio(for: stream, stats)
        } else if stream.device is IVSImageDevice {
            parseVideo(for: stream, stats)
        } else {
            print("ℹCPK: will not parse: \(stats)")
        }
    }

    private func parseBaseData(for stream: IVSStageStream, from stats: [String: [String: String]]) {
        let selectedCandidatePairId = stats["T01"]?["selectedCandidatePairId"] ?? ""
        let candidatePair = stats[selectedCandidatePairId]
        var remoteInbound = stats["remote-inbound-rtp"]
        var inbound = stats["inbound-rtp"]
        stats.forEach { (key: String, value: [String : String]) in
            if value["type"] == "remote-inbound-rtp" {
                remoteInbound = stats[key]
            } else if value["type"] == "inbound-rtp" {
                inbound = stats[key]
            }
        }

        DispatchQueue.main.async {
            if let roundTripTime = Float(candidatePair?["currentRoundTripTime"] ?? "") {
                self.debugData.participantStats[stream.device.tag()]?.medianLatency = String(format: "%.0fms", roundTripTime * 1000)
            } else {
                print("ℹCPK: ❌ Could not parse currentRoundTripTime to float from '\(candidatePair?["currentRoundTripTime"] ?? "")'")
                self.debugData.participantStats[stream.device.tag()]?.medianLatency = "-"
            }
            self.debugData.participantStats[stream.device.tag()]?.packetLossDown = remoteInbound?["packetsLost"] ?? inbound?["packetsLost"]

            for user in self.participantUsers {
                user.latency = self.debugData.videoParticipanStats
                    .filter({ $0.value.username == user.username })
                    .first?.value.medianLatency
            }
        }
    }

    private func parseVideo(for stream: IVSStageStream, _ stats: [String: [String: String]]) {
        print("ℹCPK: VIDEO didGenerateRTCStats: \(stats)")
        parseBaseData(for: stream, from: stats)

        var outbound = stats["outbound-rtp"]
        var inbound = stats["inbound-rtp"]
        stats.forEach { (key: String, value: [String : String]) in
            if value["type"] == "inbound-rtp" {
                inbound = stats[key]
            } else if value["type"] == "outbound-rtp" {
                outbound = stats[key]
            }
        }

        if let inbound = inbound {
            parseInbound(for: stream, inbound)
        } else if let outbound = outbound {
            parseOutbound(for: stream, outbound)
        }

        DispatchQueue.main.async {
            self.debugData.participantStats[stream.device.tag()]?.clipboardString = "\(stats)"
        }
    }

    private func parseAudio(for stream: IVSStageStream, _ stats: [String: [String: String]]) {
        print("ℹCPK: AUDIO didGenerateRTCStats: \(stats)")
        parseBaseData(for: stream, from: stats)

        DispatchQueue.main.async {
            self.debugData.participantStats[stream.device.tag()]?.clipboardString = "\(stats)"
        }
    }

    private func parseOutbound(for stream: IVSStageStream, _ outbound: [String: String]) {
        let reason = outbound["qualityLimitationReason"]
        DispatchQueue.main.async {
            self.debugData.participantStats[stream.device.tag()]?.streamQuality = reason == "none" ? "Normal" : "Degraded"
            self.debugData.participantStats[stream.device.tag()]?.fps = outbound["framesPerSecond"]
        }

        if var durationsString = outbound["qualityLimitationDurations"] {
            durationsString = durationsString.replacingOccurrences(of: "{", with: "")
            durationsString = durationsString.replacingOccurrences(of: "}", with: "")
            let durations = durationsString.components(separatedBy: ",")
            var durationsJson: [String: String] = [:]
            durations.forEach { str in
                let key = str.components(separatedBy: ":").first ?? ""
                let value = str.components(separatedBy: ":").last ?? ""
                durationsJson[key] = value
            }

            DispatchQueue.main.async {
                self.debugData.participantStats[stream.device.tag()]?.cpuLimitedTime = durationsJson["cpu"]
                self.debugData.participantStats[stream.device.tag()]?.networkLimitedTime = durationsJson["bandwidth"]
            }
        }
    }

    private func parseInbound(for stream: IVSStageStream, _ inbound: [String: String]) {
        DispatchQueue.main.async {
            self.debugData.participantStats[stream.device.tag()]?.fps = inbound["framesPerSecond"]
        }
    }
}

extension StageModel: IVSCameraDelegate {
    func camera(_ camera: IVSCamera, didOutputSampleBuffer sampleBuffer: CMSampleBuffer) {
        print("CPK: FILTER Camera delegate called - processing frame")
        
        // Apply filters to camera frames
        let processedBuffer = localUser.sendCameraFrame(sampleBuffer) ?? sampleBuffer
        
        // Use filtered buffer for recording if recording is active
        if isRecording,
           let writer = assetWriter, writer.status == .writing,
           let input = assetWriterVideoInput,
           input.isReadyForMoreMediaData {
            input.append(processedBuffer)
        }
    }
}

extension StageModel: RPPreviewViewControllerDelegate {
    
}
