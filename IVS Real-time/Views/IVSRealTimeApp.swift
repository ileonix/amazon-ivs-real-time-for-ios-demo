//
//  IVSRealTimeApp.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI
import LiveCommerceSDK

import Wormholy

@main
struct IVSRealTimeApp: App {
    @StateObject var appModel: AppModel
    
    init() {
        // Configure SDK before creating AppModel
        let prefixAPIUrl = UserDefaults.standard.string(forKey: Constants.kCustomerCode) ?? ""
        LiveCommerceInterface.configure(
            baseURL: "ddqs04nk76rcv.\(Constants.API_URL)",
            apiKey: UserDefaults.standard.string(forKey: Constants.kApiKey) ?? "",
            ecommerceURL: Constants.ECOMMERECE_API_URL
        )
        
        Wormholy.shakeEnabled = true
        Wormholy.limit = 20
        Wormholy.swiftyInitialize()
        Wormholy.swiftyLoad()
        
        // Now create AppModel after SDK is configured
        _appModel = StateObject(wrappedValue: AppModel())
        
//        setupWormholy()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
        }
    }
    
    func setupWormholy() {
        Wormholy.shakeEnabled = true
        Wormholy.limit = 20
        Wormholy.swiftyInitialize()
        Wormholy.swiftyLoad()
    }
}

struct RootView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        NavigationView {
            ZStack {
                if !appModel.isConnected {
                    WelcomeView()
                        .transition(.move(edge: .leading))
                } else if appModel.isReadyToGoCustomerLanding && appModel.userRole == .customer {
                    CustomerShopLanding(stagesModel: appModel.stagesModel,
                                        stageModel: appModel.stageModel,
                                        channelsModel: appModel.channelsModel)
                        .environmentObject(appModel)
                        .transition(.move(edge: .trailing))
                } else if let selectedChannel = appModel.selectedChannel, appModel.userRole == .customer {
                    SDKUltraLowLatencyConsumerView(
                        channel: selectedChannel,
                        onBack: { 
                            appModel.selectedChannel = nil
                            appModel.isReadyToGoCustomerLanding = true
                        }
                    )
                        .environmentObject(appModel)
                        .transition(.move(edge: .trailing))
                        .onAppear {
                            appModel.isSetupCompleted = true
                            appModel.user.hostId = selectedChannel.hostId
                            if appModel.webSocketManager.isConnected {
                                appModel.webSocketManager.clientToServerJoin(hostId: selectedChannel.hostId)
                            }
                        }
                } else if let selectedStage = appModel.selectedStage, appModel.userRole == .customer {
                    SDKRealtimeConsumerView(stage: selectedStage)
                        .environmentObject(appModel)
                        .transition(.move(edge: .trailing))
                        .onAppear {
                            appModel.shouldJoinActiveStage = true
                            appModel.isSetupCompleted = true
                            appModel.user.hostId = selectedStage.hostId
                            if appModel.webSocketManager.isConnected {
                                appModel.webSocketManager.clientToServerJoin(hostId: selectedStage.hostId)
                            }
                        }
                        .onDisappear {
                            appModel.shouldJoinActiveStage = false
                        }
                } else if appModel.isSetupCompleted && appModel.userRole == .merchant {
                    if appModel.streamType == .ultraLowLatency {
                        SDKUltraLowLatencyMerchantView(
                            endpoint: appModel.broadcastViewModel.endpoint, 
                            streamKey: appModel.broadcastViewModel.streamKey,
                            onBack: { appModel.isSetupCompleted = false }
                        )
                        .environmentObject(appModel)
                        .transition(.move(edge: .trailing))
                    } else {
                        SDKRealtimeMerchantView(hostToken: appModel.user.hostParticipantToken?.tokenData.token ?? "")
                            .environmentObject(appModel)
                            .transition(.move(edge: .trailing))
                            .onAppear {
                                if appModel.webSocketManager.isConnected {
                                    appModel.webSocketManager.clientToServerJoin(hostId: appModel.user.hostId)
                                }
                            }
                    }
                } else if appModel.isConnected && !appModel.isSetupCompleted {
                    SetupView()
                        .transition(.opacity)
                }

                if appModel.isLoading {
                    LoadingView()
                }

                ErrorView()
            }
            .animation(.easeInOut, value: appModel.isConnected)
            .animation(.easeInOut, value: appModel.isSetupCompleted)
            .animation(.easeInOut, value: appModel.isReadyToGoCustomerLanding)
            .animation(.easeInOut, value: appModel.selectedStage)
            .onFirstAppear {
                checkAVPermissions { granted in
                    if !granted {
                        appModel.appendErrorMessage("No camera/microphone permission granted")
                    }

                    if UserDefaults.standard.string(forKey: Constants.kCustomerCode) != nil {
                        appModel.verify(silent: true) { _ in }
                    }
                }
                
                appModel.webSocketManager.connect()
            }
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
