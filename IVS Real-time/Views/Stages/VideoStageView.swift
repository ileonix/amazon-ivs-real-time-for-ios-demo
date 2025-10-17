//
//  VideoStageView.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI

struct VideoStageView: View {
    @EnvironmentObject var appModel: AppModel

    @ObservedObject var stage: Stage

    var body: some View {
        ZStack(alignment: .top) {
            if stage == appModel.activeStage {
                switch stage.mode {
                    case .none, .spot:
                        ZStack {
                            VideoView(stage: stage)
                                .transition(.opacity)
                                .onTapGesture {
                                    print("CPK: onAppear setup completed: \(appModel.isSetupCompleted)")
                                    if appModel.isSetupCompleted, appModel.user.isOnStage {
                                        appModel.recordVideo(completion: { videoPath in
                                            appModel.captureImage(completion: { imagePath in
                                                print("CPK: videoPath \(videoPath)")
                                                print("CPK: imagePath \(imagePath)")
                                                if let videoPath = videoPath, let imagePath = imagePath {
                                                    appModel.server.createS3UploadUrls(user: appModel.user, hostCaptureVideoPath: videoPath, hostCaptureImagePath: imagePath ?? "", onComplete: { urls in
                                                        print("CPK: appModel.stageModel.localUser.isOnStage \(appModel.stageModel.localUser.isOnStage)")
                                                        print("CPK: urls \(urls?.videoKeyName)")
                                                    })
                                                }
                                            })
                                        })
                                    }
                                }
                            Text("HostId: \(stage.hostId)")
                                .foregroundColor(appModel.isSetupCompleted ? .green : .red)
                        }
                    case .pk:
                        PKView(stage: stage)
                            .transition(.scale)
                }
            } else {
                ZStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Color("BackgroundDark")
                )
            }
        }
        .frame(height: UIScreen.main.bounds.height - appModel.activeStageBottomSpace)
        .edgesIgnoringSafeArea(.top)
        .frame(width: UIScreen.main.bounds.width)
        .cornerRadius(30)
        .overlay {
            StageOverlayView(stage: stage)
        }
        .overlay {
            if appModel.pkVotingWinVisualsActive {
                ZStack {
                    Image("light-rays")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 600)
                    Image(appModel.votesCountHost > appModel.votesCountParticipant ? "banner-red" : "banner-blue")
                        .resizable()
                        .frame(width: 120, height: 180)
                        .offset(y: 80)
                    Image("crest-banner")
                        .resizable()
                        .frame(width: 220, height: 220)
                    AvatarView(avatar: (appModel.votesCountHost > appModel.votesCountParticipant ? appModel.hostAvatar : appModel.activeStageSecondParticipant?.avatar) ?? Avatar(),
                               size: 63)
                    .offset(y: -20.5)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        self.appModel.pkVotingWinVisualsActive = false
                    }
                }
                .onTapGesture {
                    withAnimation {
                        appModel.pkVotingWinVisualsActive = false
                    }
                }
            }
        }
    }
}
