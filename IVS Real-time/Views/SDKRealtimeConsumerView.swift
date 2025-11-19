import SwiftUI
import LiveCommerceSDK

struct SDKRealtimeConsumerView: View {
    @EnvironmentObject var appModel: AppModel
    let stage: Stage
    
    var body: some View {
        Group {
            if let participantToken = appModel.user.participantToken {
                LiveCommerceInterface.Realtime.consumerView(token: participantToken.token)
            } else {
                Text("Joining stage...")
                    .onAppear {
                        joinStageAndGetToken()
                    }
            }
        }
    }
    
    private func joinStageAndGetToken() {
//        appModel.join(stage) { success, token in
//            // Token will be available in appModel.user.participantToken
//        }
    }
}
