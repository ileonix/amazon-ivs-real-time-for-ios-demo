//
//  ScreenRecorder.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 16/10/2568 BE.
//

import Foundation
import ReplayKit
import AVFoundation

class ScreenRecorder: NSObject {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isRecording = false
    private var outputURL: URL?
    private var sessionStarted = false
    private var recordingQueue = DispatchQueue(label: "com.chanonp.screenrecording")
    
    private var videoSettings: [String: Any]?
    
    func startRecording(hostId: String, completion: @escaping (URL?) -> Void) {
        let recorder = RPScreenRecorder.shared()
        
        // Setup temp URL for saving file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(hostId).mp4")
        
        // Remove existing file if any
        try? FileManager.default.removeItem(at: tempURL)
        
        // Initialize variables
        isRecording = true
        sessionStarted = false
        outputURL = tempURL
        assetWriter = nil
        videoInput = nil
        
        recorder.isMicrophoneEnabled = false
        
        recorder.startCapture(handler: { [weak self] (sampleBuffer, bufferType, error) in
            guard let self = self, self.isRecording else { return }
            
            if let error = error {
                print("CPK: ❌ Capture error: \(error.localizedDescription)")
                return
            }
            
            if bufferType == .video {
                self.handleVideoSampleBuffer(sampleBuffer)
            }
            // You can add audio handling here if needed
            
        }, completionHandler: { error in
            if let error = error {
                print("CPK: ❌ Failed to start screen capture: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            print("CPK: ✅ Screen recording started")
            
            // Stop recording automatically after 5 seconds (or you can stop manually elsewhere)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.stopRecording(completion: completion)
            }
        })
    }
    
    private func handleVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        recordingQueue.async {
            guard self.isRecording else { return }
            
            if self.assetWriter == nil {
                // Get format description and video dimensions
                guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                    print("CPK: ❌ Failed to get format description")
                    return
                }
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
                
                // Prepare video settings dynamically based on buffer size
                self.videoSettings = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(dimensions.width),
                    AVVideoHeightKey: Int(dimensions.height)
                ]
                
                // Create asset writer
                do {
                    guard let outputURL = self.outputURL else {
                        print("CPK: ❌ outputURL is nil")
                        return
                    }
                    self.assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
                } catch {
                    print("CPK: ❌ Failed to create asset writer: \(error.localizedDescription)")
                    return
                }
                
                // Create video input
                guard let videoSettings = self.videoSettings else { return }
                self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                self.videoInput?.expectsMediaDataInRealTime = true
                
                if let videoInput = self.videoInput,
                   self.assetWriter?.canAdd(videoInput) == true {
                    self.assetWriter?.add(videoInput)
                } else {
                    print("CPK: ❌ Cannot add video input to asset writer")
                    return
                }
            }
            
            guard let assetWriter = self.assetWriter,
                  let videoInput = self.videoInput else {
                print("CPK: ❌ AssetWriter or VideoInput is nil")
                return
            }
            
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            if !self.sessionStarted {
                if assetWriter.startWriting() {
                    assetWriter.startSession(atSourceTime: pts)
                    self.sessionStarted = true
                    print("CPK: ✅ Asset writer session started at: \(pts.seconds)s")
                } else {
                    print("CPK: ❌ Failed to start writing: \(assetWriter.error?.localizedDescription ?? "unknown error")")
                    return
                }
            }
            
            if videoInput.isReadyForMoreMediaData {
                let success = videoInput.append(sampleBuffer)
                if !success {
                    print("CPK: ❌ Failed to append sample buffer: \(assetWriter.error?.localizedDescription ?? "unknown error")")
                }
            } else {
                print("CPK: ⚠️ Video input not ready for media data")
            }
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        isRecording = false
        RPScreenRecorder.shared().stopCapture { error in
            if let error = error {
                print("CPK: ❌ Failed to stop capture: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            self.recordingQueue.async {
                guard let assetWriter = self.assetWriter else {
                    print("CPK: ⚠️ Asset writer is nil on stop")
                    DispatchQueue.main.async {
                        completion(self.outputURL)
                    }
                    return
                }
                
                if assetWriter.status == .writing {
                    self.videoInput?.markAsFinished()
                    assetWriter.finishWriting {
                        print("CPK: ✅ Finished writing video to: \(self.outputURL?.absoluteString ?? "unknown")")
                        DispatchQueue.main.async {
                            completion(self.outputURL)
                        }
                    }
                } else {
                    print("CPK: ⚠️ Asset writer status on stop: \(assetWriter.status.rawValue)")
                    DispatchQueue.main.async {
                        completion(self.outputURL)
                    }
                }
            }
        }
    }
}


