import Foundation
import LiveCommerceSDK

/// Helper to integrate SDK network layer with existing AppModel
class SDKNetworkHelper: ObservableObject {
    private let networkAdapter: NetworkAdapter
    
    init() {
        self.networkAdapter = LiveCommerceInterface.Network.createAdapter()
    }
    
    // MARK: - Real-time Stage APIs
    func createStage(type: StageType, user: User, completion: @escaping (_ success: Bool, _ hostToken: HostParticipantToken?) -> Void) {
        Task {
            do {
                let response = try await networkAdapter.createStage(
                    cid: UserDefaults.standard.string(forKey: Constants.kCustomerCode) ?? "",
                    hostId: user.hostId,
                    hostAttributes: [
                        "avatarColBottom": user.avatar.colBottom,
                        "avatarColLeft": user.avatar.colLeft,
                        "avatarColRight": user.avatar.colRight,
                        "username": user.username
                    ],
                    type: type.rawValue
                )
                
                let hostToken = HostParticipantToken(
                    region: response.region,
                    tokenData: TokenData(
                        token: response.hostParticipantToken.token,
                        participantId: response.hostParticipantToken.participantId,
                        duration: response.hostParticipantToken.duration
                    ),
                    uploadPreviewUrls: UploadPreviewUrls(
                        uploadImageSignedUrl: response.uploadPreviewUrls.uploadImageSignedUrl,
                        uploadVideoSignedUrl: response.uploadPreviewUrls.uploadVideoSignedUrl,
                        imageKeyName: response.uploadPreviewUrls.imageKeyName ?? "",
                        videoKeyName: response.uploadPreviewUrls.videoKeyName ?? ""
                    )
                )
                
                DispatchQueue.main.async {
                    completion(true, hostToken)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
            }
        }
    }
    
    func getStages(onlyActive: Bool = true, completion: @escaping (Bool, [StageDetails]) -> Void) {
        Task {
            do {
                let stages = try await networkAdapter.getStages(onlyActive: onlyActive)
                
                let stageDetails = stages.map { stage in
                    StageDetails(
                        createdAt: stage.createdAt,
                        hostId: stage.hostId,
                        mode: .none,
                        type: StageType(rawValue: stage.type) ?? .video,
                        status: stage.status,
                        seats: [],
                        stageArn: stage.stageArn,
                        imagePreviewUrl: nil,
                        videoPreviewUrl: nil
                    )
                }
                
                DispatchQueue.main.async {
                    completion(true, stageDetails)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, [])
                }
            }
        }
    }
    
    // MARK: - Ultra Low Latency APIs
    func createChannel(user: User, completion: @escaping (_ success: Bool, _ channelCredentials: ChannelCredentials?) -> Void) {
        Task {
            do {
                let response = try await networkAdapter.createChannel(
                    hostId: user.hostId,
                    title: "Live Stream by \(user.hostId)",
                    hostAttributes: [
                        "name": user.hostId,
                        "description": "Live Shopping"
                    ],
                    streamConfig: StreamConfig(
                        latencyMode: "LOW",
                        recordingEnabled: true,
                        maxViewers: 1000
                    )
                )
                
                let credentials = ChannelCredentials(
                    streamId: UUID().uuidString,
                    streamType: .ULTRA_LOW_LATENCY,
                    channelArn: response.channelArn,
                    ingestEndpoint: response.ingestEndpoint,
                    streamKey: response.streamKey,
                    playbackUrl: response.playbackUrl,
                    chatRoomArn: "",
                    region: Constants.AWS_REGION
                )
                
                DispatchQueue.main.async {
                    completion(true, credentials)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, nil)
                }
            }
        }
    }
}
