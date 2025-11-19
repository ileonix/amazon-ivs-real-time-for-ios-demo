import SwiftUI
import LiveCommerceSDK

struct Channel {
    let playbackUrl: String
}

struct SDKUltraLowLatencyConsumerView: View {
    let channel: Channel
    let region: String
    let roomId: String
    let token: String
    
    var body: some View {
        ZStack(alignment: .bottom) {
            LiveCommerceInterface.UltraLowLatency.consumerView(streamURL: channel.playbackUrl)
            
            HStack(alignment: .bottom) {
                LiveCommerceInterface.Chat.chatView(
                    region: region,
                    roomId: roomId,
                    token: token
                )
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                
                Spacer()
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}