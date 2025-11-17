//
//  LiveBroadcastView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 10/11/2568 BE.
//

import SwiftUI
import AmazonIVSBroadcast
import LiveCommerceSDK

struct LiveBroadcastView: View {
    @StateObject private var broadcastManager = LiveCommerceSDK.createBroadcastManager()
    @ObservedObject var viewModel: BroadcastViewModel
    @State private var showingPermissionAlert = false
    
    init(viewModel: BroadcastViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Fullscreen Camera Preview using SDK
            CameraPreviewView(camera: broadcastManager.attachedCamera)
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }
            
            VStack {
                // Header with back button
                HStack {
                    Button {
                        // Navigate back to setup
                        if let appModel = viewModel.appModel {
                            withAnimation {
                                appModel.isSetupCompleted = false
                            }
                            if viewModel.isRunning {
                                viewModel.stopBroadcast()
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    Spacer()
                    Text("Live Broadcast")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    // Connection Status
                    HStack {
                        Circle()
                            .fill(connectionColor)
                            .frame(width: 12, height: 12)
                        Text(connectionStatusText)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color.black.opacity(0.3))
                
                Spacer()
                
                // Bottom overlay with controls
                VStack(spacing: 12) {
                    // Input Fields
                    VStack(spacing: 8) {
                        TextField("Endpoint URL", text: $broadcastManager.endpoint)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("Stream Key", text: $broadcastManager.streamKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Control Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            broadcastManager.showDeviceSelection(for: .camera)
                        }) {
                            VStack {
                                Image(systemName: "camera")
                                    .foregroundColor(.white)
                                Text("Camera")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            broadcastManager.showDeviceSelection(for: .microphone)
                        }) {
                            VStack {
                                Image(systemName: "mic")
                                    .foregroundColor(.white)
                                Text("Mic")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: broadcastManager.toggleMute) {
                            Image(systemName: broadcastManager.isMuted ? "speaker.slash" : "speaker")
                                .foregroundColor(broadcastManager.isMuted ? .red : .white)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Start/Stop Button
                    Button(action: {
                        if broadcastManager.isStreaming {
                            broadcastManager.stopBroadcast()
                        } else {
                            broadcastManager.startBroadcast()
                        }
                    }) {
                        Text(broadcastManager.isStreaming ? "Stop Broadcast" : "Start Broadcast")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(broadcastManager.isStreaming ? Color.red : Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            checkPermissions()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .alert("Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Camera and microphone access is required for broadcasting.")
        }
        .alert("Error", isPresented: $broadcastManager.showingError) {
            Button("OK") { }
        } message: {
            Text(broadcastManager.errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $broadcastManager.showingDeviceSelection) {
            DeviceSelectionView(
                devices: broadcastManager.availableDevices,
                deviceType: broadcastManager.deviceSelectionType,
                onDeviceSelected: { device in
                    broadcastManager.selectDevice(device)
                    broadcastManager.showingDeviceSelection = false
                }
            )
        }
    }
    
    private var connectionColor: Color {
        switch broadcastManager.connectionState {
        case .invalid, .disconnected:
            return .gray
        case .connecting:
            return .yellow
        case .connected:
            return .green
        case .error:
            return .red
        @unknown default:
            return .gray
        }
    }
    
    private var connectionStatusText: String {
        switch broadcastManager.connectionState {
        case .invalid:
            return "Invalid"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .error:
            return "Error"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func checkPermissions() {
        PermissionManager.checkAVPermissions { granted in
            if granted {
                broadcastManager.setupSession()
            } else {
                showingPermissionAlert = true
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct DeviceSelectionView: View {
    let devices: [IVSDeviceDescriptor]
    let deviceType: IVSDeviceType
    let onDeviceSelected: (IVSDeviceDescriptor) -> Void
    
    var body: some View {
        NavigationView {
            List(devices, id: \.urn) { device in
                Button(action: {
                    onDeviceSelected(device)
                }) {
                    HStack {
                        Text(device.friendlyName)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Select \(deviceType == .camera ? "Camera" : "Microphone")")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
