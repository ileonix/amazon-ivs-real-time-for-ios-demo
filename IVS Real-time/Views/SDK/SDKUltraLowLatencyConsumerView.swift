import SwiftUI
import LiveCommerceSDK

struct SDKUltraLowLatencyConsumerView: View {
    let channel: Channel
    
    var body: some View {
        LiveCommerceInterface.UltraLowLatency.consumerView(streamURL: channel.playbackUrl)
    }
}