//
//  LiveBroadcastView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 10/11/2568 BE.
//

import SwiftUI
import AmazonIVSBroadcast

struct LiveBroadcastView: View {
    @ObservedObject var viewModel: BroadcastViewModel
    @State private var showingPermissionAlert = false
    
    init(viewModel: BroadcastViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        ZStack {
            // Fullscreen Camera Preview
            CameraPreviewView(camera: viewModel.attachedCamera)
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
                        TextField("Endpoint URL", text: $viewModel.endpoint)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        TextField("Stream Key", text: $viewModel.streamKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Control Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            viewModel.showDeviceSelection(for: .camera)
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
                            viewModel.showDeviceSelection(for: .microphone)
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
                        
                        Button(action: viewModel.toggleMute) {
                            Image(systemName: viewModel.isMuted ? "speaker.slash" : "speaker")
                                .foregroundColor(viewModel.isMuted ? .red : .white)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Start/Stop Button
                    Button(action: {
                        if viewModel.isRunning {
                            viewModel.stopBroadcast()
                        } else {
                            viewModel.startBroadcast()
                        }
                    }) {
                        Text(viewModel.isRunning ? "Stop Broadcast" : "Start Broadcast")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isRunning ? Color.red : Color.blue)
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
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $viewModel.showingDeviceSelection) {
            DeviceSelectionView(
                devices: viewModel.availableDevices,
                deviceType: viewModel.deviceSelectionType,
                onDeviceSelected: { device in
                    viewModel.selectDevice(device)
                    viewModel.showingDeviceSelection = false
                }
            )
        }
    }
    
    private var connectionColor: Color {
        switch viewModel.connectionState {
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
        switch viewModel.connectionState {
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
                viewModel.setupSession()
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
