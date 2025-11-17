import SwiftUI
import LiveCommerceSDK

/// Example view demonstrating both SDK usage patterns
struct SDKExampleView: View {
    @State private var showingDefaultBroadcast = false
    @State private var showingDefaultPlayer = false
    @State private var showingCustomBroadcast = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("LiveCommerceSDK Examples")
                .font(.title)
                .padding()
            
            // Option 1: Default UI (Plug & Play)
            VStack(spacing: 12) {
                Text("Option 1: Default UI")
                    .font(.headline)
                
                Button("Default Broadcast View") {
                    showingDefaultBroadcast = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Default Player View") {
                    showingDefaultPlayer = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            // Option 2: Custom Implementation
            VStack(spacing: 12) {
                Text("Option 2: Custom Implementation")
                    .font(.headline)
                
                Button("Custom Broadcast View") {
                    showingCustomBroadcast = true
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingDefaultBroadcast) {
            LiveCommerceSDK.createBroadcastView(config: BroadcastConfig(
                endpoint: "rtmps://your-endpoint.com/app/",
                streamKey: "your-stream-key"
            ))
        }
        .sheet(isPresented: $showingDefaultPlayer) {
            LiveCommerceSDK.createPlayerView(streamURL: "https://your-stream-url.m3u8")
        }
        .sheet(isPresented: $showingCustomBroadcast) {
            CustomBroadcastExampleView()
        }
    }
}

/// Example of custom implementation using SDK managers
struct CustomBroadcastExampleView: View {
    @StateObject private var broadcastManager = LiveCommerceSDK.createBroadcastManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Custom camera preview
            CameraPreviewView(camera: broadcastManager.attachedCamera)
                .ignoresSafeArea()
            
            VStack {
                // Custom header
                HStack {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                    Spacer()
                    Text("Custom Broadcast")
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.5))
                
                Spacer()
                
                // Custom controls
                VStack {
                    HStack {
                        TextField("Endpoint", text: $broadcastManager.endpoint)
                            .textFieldStyle(.roundedBorder)
                        TextField("Key", text: $broadcastManager.streamKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button(broadcastManager.isStreaming ? "Stop" : "Start") {
                        if broadcastManager.isStreaming {
                            broadcastManager.stopBroadcast()
                        } else {
                            broadcastManager.startBroadcast()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.black.opacity(0.7))
            }
        }
        .onAppear {
            broadcastManager.setupSession()
        }
    }
}