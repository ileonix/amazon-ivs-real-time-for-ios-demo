//
//  SetupView.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI

struct SetupView: View {
    @EnvironmentObject var appModel: AppModel
    @State var isSettingsPresent: Bool = false
    @State var isStageSelectionPresent: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Color("BackgroundWhite")
                .edgesIgnoringSafeArea(.all)

            VStack {
                HStack {
                    Button(action: {
                        appModel.generateRandomUsername()
                    }) {
                        Image("arrow-path")
                            .padding(.all, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(30)
                    }
                    .padding(.trailing, 8)

                    Text(appModel.username)
                        .font(Constants.fRobotoMonoBold)
                        .foregroundColor(.black)

                    Spacer()

                    Button {
                        withAnimation {
                            isSettingsPresent.toggle()
                        }
                    } label: {
                        Image("cog-6-tooth")
                            .renderingMode(.template)
                            .foregroundColor(.black)
                    }
                    .padding(.trailing, 8)
                }

                Spacer()

                VStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        Text("BBTV")//("IVS")
                            .font(Constants.fInterBlack36)
                            .foregroundColor(.black)
                        Text("Shopping")//("Real-time")
                            .foregroundColor(Color("Orange"))
                            .font(Constants.fInterBlack36)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 40)
                .frame(maxWidth: 600)

                VStack(spacing: 12) {
                    
                    if appModel.userRole == .merchant {
                        Button {
                            withAnimation {
                                isStageSelectionPresent.toggle()
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text("")
                                    .frame(maxWidth: .infinity)
                                Text("สร้างห้องไลฟ์แชทขายของ") //Create new stage
                                    .foregroundColor(.black)
                                    .font(Constants.fInterExtraBold22)
                                    .padding(.top, 50)
                                    .padding(.bottom, 1)
                                    .frame(alignment: .leading)
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 30)
                            .background(
                                Color("Orange")
                            )
                            .cornerRadius(20)
                        }
                    }
                    
                    if appModel.userRole == .customer {
                        Button {
                            withAnimation {
                                //appModel.isSetupCompleted.toggle()
                                appModel.isReadyToGoCustomerLanding.toggle()
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text("")
                                    .frame(maxWidth: .infinity)
                                Text("เข้าห้องไลฟ์แชทขายของ") //Join stage (feed view)
                                    .font(Constants.fInterExtraBold22)
                                    .foregroundColor(.black)
                                    .padding(.top, 50)
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 30)
                            .background(
                                LinearGradient(colors: [Color("Gradient1"), Color("Gradient2")],
                                               startPoint: .top,
                                               endPoint: .bottom)
                            )
                            .cornerRadius(20)
                        }
                    }
                }
                .padding(.bottom, 16)
                .frame(maxWidth: 600)
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)

            if isSettingsPresent {
                SettingsView(isPresent: $isSettingsPresent)
            }

            if isStageSelectionPresent {
                BottomSheetConfirmationView(
                    isPresent: $isStageSelectionPresent,
                    title: "Select experience",
                    contentHeight: 250,
                    contentView:
                        VStack {
                            Button(action: {
                                withAnimation {
                                    isStageSelectionPresent.toggle()
                                }
                                appModel.createStage(.video)
                            }) {
                                Text("Video stage")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .modifier(PrimaryButton(color: Color("BackgroundGray")))

                            Button(action: {
                                withAnimation {
                                    isStageSelectionPresent.toggle()
                                }
                                appModel.createStage(.audio)
                            }) {
                                Text("Audio room")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                            }
                            .modifier(PrimaryButton(color: Color("BackgroundGray")))
                        }
                )
            }
        }
    }
}
