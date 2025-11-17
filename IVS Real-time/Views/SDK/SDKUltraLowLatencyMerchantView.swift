import SwiftUI
import LiveCommerceSDK

struct SDKUltraLowLatencyMerchantView: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        Group {
            if let channel = appModel.selectedChannel {
                LiveCommerceInterface.UltraLowLatency.merchantView(
                    endpoint: channel.ingestEndpoint,
                    streamKey: channel.streamKey
                )
            } else {
                Text("Creating channel...")
                    .onAppear {
                        createChannelAndGetCredentials()
                    }
            }
        }
    }
    
    private func createChannelAndGetCredentials() {
        appModel.createChannel { success, credentials in
            // Channel will be available in appModel.selectedChannel
        }
    }
}