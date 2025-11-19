import SwiftUI
import LiveCommerceSDK

struct SDKRealtimeMerchantView: View {
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        Group {
            if let hostToken = appModel.user.hostParticipantToken?.tokenData.token {
                LiveCommerceInterface.Realtime.merchantView(token: hostToken)
            } else {
                Text("Creating stage...")
                    .onAppear {
                        createStageAndGetToken()
                    }
            }
        }
    }
    
    private func createStageAndGetToken() {
        appModel.createStage(.video) { success in
            // Token will be available in appModel.user.hostParticipantToken
        }
    }
}