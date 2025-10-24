//
//  IVSRealTimeApp.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI

@main
struct IVSRealTimeApp: App {
    @StateObject var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        ZStack {
            if !appModel.isConnected {
                WelcomeView()
                    .transition(.move(edge: .leading))
            } else if appModel.isReadyToGoCustomerLanding && appModel.userRole == .customer {
                CustomerShopLanding(stagesModel: appModel.stagesModel,
                                    stageModel: appModel.stageModel)
                    .environmentObject(appModel)
                    .transition(.move(edge: .trailing))
            } else if appModel.isSetupCompleted && (appModel.userRole == .merchant || appModel.userRole == .customer) {
                FeedsView(stagesModel: appModel.stagesModel,
                          stageModel: appModel.stageModel)
                    .environmentObject(appModel)
                    .transition(.move(edge: .trailing))
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
        .onFirstAppear {
            checkAVPermissions { granted in
                if !granted {
                    appModel.appendErrorMessage("No camera/microphone permission granted")
                }

                if UserDefaults.standard.string(forKey: Constants.kCustomerCode) != nil {
                    appModel.verify(silent: true) { _ in }
                }
            }
        }
    }
}
//@main
//struct IVSRealTimeApp: App {
//    @ObservedObject var appModel: AppModel = AppModel()
//
//    var body: some Scene {
//        WindowGroup {
//            NavigationView {
//                ZStack(alignment: .top) {
//                    if !appModel.isConnected {
//                        WelcomeView()
//                            .transition(.move(edge: .leading))
//                            .preferredColorScheme(.light)
//                    }
//
//                    if appModel.isConnected && !appModel.isSetupCompleted {
//                        SetupView()
//                            .transition(!appModel.isSetupCompleted ? .opacity : .move(edge: .trailing))
//                            .preferredColorScheme(.light)
//                    }
//                    
//                    NavigationLink(
//                        destination: CustomerShopLanding(stagesModel: appModel.stagesModel,
//                                                         stageModel: appModel.stageModel)
//                            .environmentObject(appModel)
//                            .preferredColorScheme(.dark),
//                        isActive: $appModel.isReadyToGoCustomerLanding
//                    ){ EmptyView() }
//                    
//                    NavigationLink(
//                        destination: appModel.selectedStage.map { VideoStageView(stage: $0)
//                            .onDisappear {
//                                appModel.selectedStage = nil
//                                appModel.isReadyToGoCustomerLanding = true
//                            }
//                        }
//                            .environmentObject(appModel),
//                        isActive: .constant(appModel.selectedStage != nil)
//                    ){ EmptyView() }
//                    
//                    NavigationLink(
//                        destination: FeedsView(stagesModel: appModel.stagesModel,
//                                               stageModel: appModel.stageModel)
//                            .environmentObject(appModel)
//                            .preferredColorScheme(.dark),
//                        isActive: appModel.user.isHost ? $appModel.isSetupCompleted : $appModel.isReadyToGoFeedView //.isSetupCompleted
//                    ) { EmptyView() }
//
//                    if appModel.isLoading {
//                        LoadingView()
//                    }
//
//                    ErrorView()
//                }
//                .environmentObject(appModel)
//                .onFirstAppear {
//                    checkAVPermissions { granted in
//                        if !granted {
//                            appModel.appendErrorMessage("No camera/microphone permission granted")
//                        }
//
//                        if UserDefaults.standard.string(forKey: Constants.kCustomerCode) != nil {
//                            appModel.verify(silent: true) { _ in }
//                        }
//                    }
//                }
//                .navigationBarHidden(true)
//            }
//            .navigationViewStyle(.stack)
//        }
//    }
//}
