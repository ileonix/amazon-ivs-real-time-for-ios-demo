//
//  BroadcastModel.swift
//  IVS Real-time
//
//  Created for Broadcast Session support
//

import SwiftUI
import AmazonIVSBroadcast
import AVFoundation
import LiveCommerceSDK

protocol BroadcastModelDelegate: AnyObject {
    func didEmitError(_ error: String)
    func broadcastStateChanged()
}

class BroadcastModel: NSObject, ObservableObject {
    @Published var isStreaming: Bool = false
    @Published var localUser: User
    
    weak var delegate: BroadcastModelDelegate?
    
    private var broadcastSession: IVSBroadcastSession?
    private var customImageSource: IVSCustomImageSource?
    private var customAudioSource: IVSCustomAudioSource?
    private var captureSession: AVCaptureSession?
    private var filterHelper: FilterHelper?
    
    private let captureQueue = DispatchQueue(label: "broadcast-capture-queue")
    
    // Channel credentials from server
    var channelCredentials: ChannelCredentials?
    
    override init() {
        self.localUser = User(isLocal: true, username: "", avatar: Avatar())
        super.init()
    }
    
    func setupBroadcastSession() {
        do {
            let config = IVSBroadcastConfiguration()
            try config.video.setSize(CGSize(width: 720, height: 1280))
            try config.video.setTargetFramerate(60)
            
            let customSlot = IVSMixerSlotConfiguration()
            customSlot.size = config.video.size
            customSlot.position = CGPoint(x: 0, y: 0)
            customSlot.preferredAudioInput = .userAudio
            customSlot.preferredVideoInput = .userImage
            try customSlot.setName("custom-slot")
            
            config.mixer.slots = [customSlot]
            
            IVSBroadcastSession.applicationAudioSessionStrategy = .noAction
            let session = try IVSBroadcastSession(configuration: config, descriptors: nil, delegate: self)
            
            // Create custom sources
            let audioSource = session.createAudioSource(withName: "custom-audio")
            session.attach(audioSource, toSlotWithName: "custom-slot")
            customAudioSource = audioSource
            
            let imageSource = session.createImageSource(withName: "custom-image")
            session.attach(imageSource, toSlotWithName: "custom-slot")
            customImageSource = imageSource
            
            // Setup filter helper
            filterHelper = FilterHelper()
            
            broadcastSession = session
            setupCaptureSession()
            
        } catch {
            delegate?.didEmitError("Failed to setup broadcast session: \(error)")
        }
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        // Video setup
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
           session.canAddInput(videoInput) {
            session.addInput(videoInput)
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
        }
        
        // Audio setup
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
            
            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: captureQueue)
            
            if session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
            }
        }
        
        session.commitConfiguration()
        session.startRunning()
        captureSession = session
    }
    
    func startBroadcast() {
        guard let credentials = channelCredentials,
              let session = broadcastSession else {
            delegate?.didEmitError("No channel credentials or broadcast session")
            return
        }
        
        do {
            try session.start(with: URL(string: credentials.ingestEndpoint)!, streamKey: credentials.streamKey)
            DispatchQueue.main.async {
                self.isStreaming = true
            }
        } catch {
            delegate?.didEmitError("Failed to start broadcast: \(error)")
        }
    }
    
    func stopBroadcast() {
        broadcastSession?.stop()
        DispatchQueue.main.async {
            self.isStreaming = false
        }
    }
    
    func applyFilter(_ filterName: String) {
        // Filter implementation would go here
        print("Applying filter: \(filterName)")
    }
    
    func getPreviewView() -> UIView? {
        do {
            return try customImageSource?.previewView(with: .fit)
        } catch {
            print("Error creating preview: \(error)")
            return nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension BroadcastModel: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output is AVCaptureVideoDataOutput {
            let finalBuffer = filterHelper?.process(inputBuffer: sampleBuffer) ?? sampleBuffer
            customImageSource?.onSampleBuffer(finalBuffer)
        } else if output is AVCaptureAudioDataOutput {
            customAudioSource?.onSampleBuffer(sampleBuffer)
        }
    }
}

// MARK: - IVSBroadcastSessionDelegate
extension BroadcastModel: IVSBroadcastSession.Delegate {
    func broadcastSession(_ session: IVSBroadcastSession, didChange state: IVSBroadcastSession.State) {
        DispatchQueue.main.async {
            self.delegate?.broadcastStateChanged()
        }
    }
    
    func broadcastSession(_ session: IVSBroadcastSession, didEmitError error: Error) {
        DispatchQueue.main.async {
            self.delegate?.didEmitError("Broadcast error: \(error)")
        }
    }
}
