import SwiftUI
import LiveCommerceSDK
import AmazonIVSBroadcast

//struct LiveUltraLowLatencyMerchantView: View {
//    @EnvironmentObject var appModel: AppModel
//    @StateObject private var broadcastManager = LiveCommerceSDK.createBroadcastManager()
//    
//    var body: some View {
//        ZStack {
//            Color.black.ignoresSafeArea()
//            
//            // Camera preview (full screen)
//            CameraPreviewView(manager: broadcastManager)
//            
//            // Left side controls (similar to Real-time layout)
//            VStack {
//                HStack {
//                    LeftSideControls(manager: broadcastManager)
//                    Spacer()
//                }
//                Spacer()
//            }
//            
//            // Top status bar
//            VStack {
//                HStack {
//                    Spacer()
//                    
//                    // Live indicator
//                    HStack {
//                        Circle()
//                            .fill(broadcastManager.isStreaming ? Color.red : Color.gray)
//                            .frame(width: 8, height: 8)
//                        Text(broadcastManager.isStreaming ? "LIVE" : "OFFLINE")
//                            .foregroundColor(.white)
//                            .font(.caption)
//                            .fontWeight(.bold)
//                    }
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 6)
//                    .background(broadcastManager.isStreaming ? Color.red : Color.gray)
//                    .cornerRadius(15)
//                }
//                .padding()
//                
//                Spacer()
//            }
//            
//            // E-commerce overlay
//            EcommerceOverlay()
//        }
//        .onAppear {
//            setupBroadcast()
//        }
//        .onDisappear {
//            broadcastManager.stopBroadcast()
//        }
//        .alert("Error", isPresented: $broadcastManager.showingError) {
//            Button("OK") { }
//        } message: {
//            Text(broadcastManager.errorMessage ?? "Unknown error")
//        }
//    }
//    
//    private func setupBroadcast() {
//        broadcastManager.setupSession()
//        
//        // Set endpoint and stream key from app model
//        if let channel = appModel.selectedChannel {
//            broadcastManager.endpoint = channel.ingestEndpoint
//            broadcastManager.streamKey = channel.streamKey
//        }
//    }
//}

/// Left side controls matching Real-time layout
private struct LeftSideControls: View {
    @ObservedObject var manager: BroadcastManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Audio mute button
            Button(action: manager.toggleMute) {
                Image(systemName: manager.isMuted ? "mic.slash.fill" : "mic.fill")
                    .foregroundColor(manager.isMuted ? .red : .white)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            // Start/Stop broadcast button
            Button(action: {
                if manager.isStreaming {
                    manager.stopBroadcast()
                } else {
                    manager.startBroadcast()
                }
            }) {
                Image(systemName: manager.isStreaming ? "stop.circle.fill" : "play.circle.fill")
                    .foregroundColor(manager.isStreaming ? .red : .green)
                    .font(.largeTitle)
                    .frame(width: 70, height: 70)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            // Camera swap button
            Button(action: {
                manager.showDeviceSelection(for: .camera)
            }) {
                Image(systemName: "camera.rotate.fill")
                    .foregroundColor(.white)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
            
            // Microphone selection button
            Button(action: {
                manager.showDeviceSelection(for: .microphone)
            }) {
                Image(systemName: "mic.badge.plus")
                    .foregroundColor(.white)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.leading, 20)
        .padding(.top, 100)
        .sheet(isPresented: $manager.showingDeviceSelection) {
            DeviceSelectionSheet(manager: manager)
        }
    }
}

/// Camera preview view
//private struct CameraPreviewView: UIViewRepresentable {
//    @ObservedObject var manager: BroadcastManager
//    
//    func makeUIView(context: Context) -> UIView {
//        let view = UIView()
//        view.backgroundColor = .black
//        
//        // Add camera preview if available
//        if let camera = manager.attachedCamera {
//            let previewView = IVSImagePreviewView()
//            previewView.imageDevice = camera
//            previewView.translatesAutoresizingMaskIntoConstraints = false
//            view.addSubview(previewView)
//            
//            NSLayoutConstraint.activate([
//                previewView.topAnchor.constraint(equalTo: view.topAnchor),
//                previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//                previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//                previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//            ])
//        }
//        
//        return view
//    }
//    
//    func updateUIView(_ uiView: UIView, context: Context) {
//        // Update camera preview if needed
//        if let previewView = uiView.subviews.first as? IVSImagePreviewView {
//            previewView.imageDevice = manager.attachedCamera
//        }
//    }
//}

/// Device selection sheet
private struct DeviceSelectionSheet: View {
    @ObservedObject var manager: BroadcastManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(manager.availableDevices, id: \.urn) { device in
                    Button(device.friendlyName) {
                        manager.selectDevice(device)
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle(deviceTypeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var deviceTypeTitle: String {
        switch manager.deviceSelectionType {
        case .camera:
            return "Select Camera"
        case .microphone:
            return "Select Microphone"
        @unknown default:
            return "Select Device"
        }
    }
}

/// E-commerce overlay for products
private struct EcommerceOverlay: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                // Product pin overlay
                if let pinnedProduct = appModel.productsViewModel.pinnedProduct {
                    VStack {
                        AsyncImage(url: URL(string: pinnedProduct.imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        
                        Text(pinnedProduct.name)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    .frame(width: 80)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .position(appModel.pinProductPosition)
                }
            }
        }
    }
}
