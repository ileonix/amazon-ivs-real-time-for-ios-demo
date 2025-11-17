//
//  AppModel.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI
import Network
import AmazonIVSBroadcast
import LiveCommerceSDK

class AppModel: NSObject, ObservableObject {
    @ObservedObject var server: ServerModel
    @ObservedObject var sdkNetworkHelper: SDKNetworkHelper
    
    //IVS Real-time streaming
    @ObservedObject var stagesModel: StagesModel
    @ObservedObject var stageModel: StageModel
    
    //IVS Ultra low latency streaming
    @ObservedObject var channelsModel: ChannelsModel
    @ObservedObject var broadcastViewModel: BroadcastViewModel
    
    @ObservedObject var viewModelAllProduct: ProductsViewModel
    @ObservedObject var webSocketManager: WebSocketManager
    
    @Published var user: User
    var userRole: UserRole? {
        get {
            user.userRole
        }
        set {
            user.userRole = newValue
        }
    }

    @Published var isConnected: Bool = false
    @Published var wasConnected: Bool = false
    @Published var isSetupCompleted: Bool = false
    @Published var isReadyToGoCustomerLanding: Bool = false
    @Published var selectedStage: Stage? = nil
    @Published var selectedChannel: ChannelDetails? = nil
    @Published var streamType: StreamType = .realtime
    
    enum StreamType {
        case realtime    // IVS Real-time (Stages)
        case ultraLowLatency  // IVS Ultra Low Latency (Broadcast)
    }
    
    @Published var isRealtimeNotUltraLowLantency: Bool = true {
        didSet {
            UserDefaults.standard.set(isRealtimeNotUltraLowLantency, forKey: Constants.kIVSRealtimeMode)
            streamType = isRealtimeNotUltraLowLantency ? StreamType.realtime : StreamType.ultraLowLatency
        }
    }
    
    @Published var isSimulcastOn: Bool = false {
        didSet {
            UserDefaults.standard.set(isSimulcastOn, forKey: Constants.kIsSimulcastOn)
            updateVideoConfiguration()
        }
    }
    @Published var isStatsOn: Bool = true {
        didSet {
            UserDefaults.standard.set(isStatsOn, forKey: Constants.kIsStatsOn)
        }
    }

    @Published var userWantsToJoinVideoStage: Bool = false
    @Published var userWantsToLeaveStage: Bool = false
    @Published var hostWantsToRemoveParticipant: Bool = false

    @Published var username: String = ""
    @Published private(set) var errorMessages: [String] = []

    @Published var isLoading: Bool = false

    @Published private(set) var activeStage: Stage?
    @Published private var activeStageHostUsername: String = ""
    @Published var activeStageSecondParticipant: User?
    @Published var activeStageHostParticipant: User?
    @Published var participantsChanged: Bool = false

    @Published var reactionViews: [ReactionView] = []
    @Published var pinProductPosition: CGPoint = CGPoint(x: 150, y: 150)
    @Published var votesCountHost: Int = 0
    @Published var votesCountParticipant: Int = 0
    @Published var votingSessionIsActive: Bool = false
    @Published var votingSessionStartedAt: Date?
    @Published var pkVotingWinVisualsActive: Bool = false
    @Published private(set) var connectedToNetwork: Bool = false {
        didSet {
            if connectedToNetwork {
                onNetworkRestore()
            } else {
                onNetworkLoose()
            }
        }
    }

    private var stageJoinInProgress: Bool = false
    private var seatChangeInProgress = false
    var chatModel: ChatModel?
    var shouldJoinActiveStage: Bool = false
    var activeVotingSessionTally: [String: Int]?
    let activeStageBottomSpace: CGFloat = 40
    let dateFormatter = DateFormatter()

    let monitor = NWPathMonitor()
    let queue = DispatchQueue(label: "NetworkMonitor")
    var hostAvatar: Avatar? {
        if user.isHost {
            return user.avatar
        } else {
            guard let attributes = user.participantToken?.hostAttributes else {
                return nil
            }
            return Avatar(colLeft: attributes["avatarColLeft"] ?? "",
                          colRight: attributes["avatarColRight"] ?? "",
                          colBottom: attributes["avatarColBottom"] ?? "")
        }
    }
    var maxBitrate: Int {
        var bitrate = UserDefaults.standard.integer(forKey: Constants.kMaxBitrate)
        if bitrate == 0 {
            bitrate = 400
        }
        return bitrate
    }

    override init() {
        self.server = ServerModel()
        self.sdkNetworkHelper = SDKNetworkHelper()
        self.user = User(isLocal: true, username: UsernameProvider.getRandomUsername(), avatar: Avatar())
        self.stagesModel = StagesModel()
        self.stageModel = StageModel()
        self.channelsModel = ChannelsModel()
        self.isSimulcastOn = UserDefaults.standard.bool(forKey: Constants.kIsSimulcastOn)
        self.isStatsOn = UserDefaults.standard.bool(forKey: Constants.kIsStatsOn)
        self.isRealtimeNotUltraLowLantency = UserDefaults.standard.bool(forKey: Constants.kIVSRealtimeMode)
        self.viewModelAllProduct = ProductsViewModel()
        self.webSocketManager = WebSocketManager()
        self.broadcastViewModel = BroadcastViewModel()
        super.init()
        
        // Set initial stream type based on loaded preference
        self.streamType = isRealtimeNotUltraLowLantency ? .realtime : .ultraLowLatency
        
        self.dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        UserDefaults.standard.register(defaults: [
            Constants.kIsStatsOn: true,
            Constants.kIVSRealtimeMode: true
        ])
        
        username = user.username
        stageModel.localUser = user

        server.delegate = self
        stagesModel.delegate = self
        stageModel.delegate = self
        webSocketManager.delegate = self
        broadcastViewModel.appModel = self

        checkNetworkConnection()
    }

    func generateRandomUsername() {
        username = UsernameProvider.getRandomUsername()
        user.username = username
    }

    private func toggleLoading(_ value: Bool) {
        DispatchQueue.main.async {
            withAnimation {
                self.isLoading = value
            }
        }
    }
    
    //MARK: Ecommerce call
    //TODO: for host only
    func getProductList(onComplete: @escaping ([Product]) -> Void) {
        server.getProductList() { [weak self] products in
            guard let self = self else { return }
            self.viewModelAllProduct.setProductsFromEcommerce(products)
            let eProducts = products.map {
                Product(id: $0.id,
                        name: $0.title,
                        imageUrl: $0.imageUrl,
                        imageLargeUrl: $0.imageUrl,
                        price: $0.price,
                        discountedPrice: Int(Double($0.price) * 0.9),
                        longDescription: $0.title,
                        stock: $0.stock,
                        isPinned: $0.isPinned)
            }
            onComplete(eProducts)
        }
    }
    
    //TODO: For host and participant
    func getProductListInLive(hostId: String, onComplete: @escaping ([Product]) -> Void) {
        server.getProductListInLive(hostId: hostId) { [weak self] products in
            guard let self = self else { return }
            self.viewModelAllProduct.setProductsFromEcommerce(products)
            let eProducts = products.map {
                Product(id: $0.productId,
                        name: $0.product.title,
                        imageUrl: $0.product.imageUrl,
                        imageLargeUrl: $0.product.imageUrl,
                        price: $0.product.price,
                        discountedPrice: Int(Double($0.product.price) * 0.9),
                        longDescription: $0.product.title,
                        stock: $0.product.stock,
                        isPinned: $0.isPinned)
            }
            onComplete(eProducts)
        }
    }
    
    func addProductToLive(hostId: String,
                          productId: String,
                          onComplete: @escaping (AddProductToLiveResponse?) -> Void) {
        server.addProductInLive(hostId: hostId, productId: productId, onComplete: { [weak self] response in
            guard let self = self else { return }
            onComplete(response)
        })
    }
    
    func removeProductFromLive(hostId: String,
                               productId: String,
                               onComplete: @escaping (Bool) -> Void) {
        server.removeProductFromLive(hostId: hostId, productId: productId, onComplete: { success in
            onComplete(success)
        })
    }
    
    func reorderProductInLive(hostId: String,
                              productId: String,
                              onComplete: @escaping (Bool) -> Void) {
        server.reorderProductInLive(hostId: hostId, productId: productId, onComplete: { success in
            onComplete(success)
        })
    }
    
    func createStream(hostId: String, onComplete: @escaping (EcommerceStreamInfo?) -> Void) {
        server.createStream(hostId: hostId, onComplete: { ecommerceStreamInfo in
            onComplete(ecommerceStreamInfo)
        })
    }

    // Verify authentication code is valid
    func verify(silent: Bool = false, completion: @escaping (Bool) -> Void) {
        errorMessages.removeAll()
        isLoading = true
        server.verify(silent: silent) { [weak self] success in
            DispatchQueue.main.async {
                withAnimation {
                    self?.isConnected = success
                    self?.wasConnected = success
                    self?.isLoading = false
                }
            }
            completion(success)
        }
    }

    func getStages(completion: @escaping (Bool) -> Void) {
        print("ℹCPK: getting stages...")

        server.getStages(onlyActive: !user.isHost) { [weak self] success, stageDetails in
            DispatchQueue.main.async {
                if success {
                    self?.stagesModel.setNewStages(stageDetails)
                }
            }
            completion(success)
        }
    }
    
    func getChannels(completion: @escaping (Bool) -> Void) {
        print("ℹCPK: getting channels...")
        
        server.getChannels(onlyActive: true) { [weak self] success, channelDetails in
            DispatchQueue.main.async {
                if success {
                    self?.channelsModel.setNewChannels(channelDetails)
                }
            }
            completion(success)
        }
    }
    
    //For consumer side, live from merchant can be Real-time (stages) or Ultra low latency (channels)
    func getAllStreams(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var overallSuccess = true
        
        group.enter()
        getStages { success in
            if !success { overallSuccess = false }
            group.leave()
        }
        
        group.enter()
        getChannels { success in
            if !success { overallSuccess = false }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(overallSuccess)
        }
    }

    func disconnect() {
        print("ℹCPK: disconnecting...")
        toggleLoading(true)

        if streamType == .ultraLowLatency {
            if broadcastViewModel.isRunning {
                broadcastViewModel.stopBroadcast()
            }
        } else {
            stageModel.leaveStage()
        }

        withAnimation {
            isConnected = false
        }

        toggleLoading(false)
    }

    func kickSecondParticipant() {
        toggleLoading(true)

        if let activeStage = activeStage {
            // Remove other participant by updating stage mode no NONE
            // because other participant should still remain in stage but stop publishing
            server.updateMode(activeStage.hostId, toStageMode: .none, user: user) { [weak self] success in
                print("ℹCPK: removed second participant by updating stage mode: \(success ? "✅" : "❌")")
                DispatchQueue.main.async {
                    self?.hostWantsToRemoveParticipant = false
                }
                self?.toggleLoading(false)
            }

        } else {
            print("ℹCPK: ❌ Can't remove second participant - some details missing")
            toggleLoading(false)
        }
    }

    func switchToUltraLowLatency() {
        streamType = .ultraLowLatency
        // Setup Ultra Low Latency broadcast
        broadcastViewModel.setupSession()
    }
    
    func switchToRealtime() {
        streamType = .realtime
        // Stop any ongoing broadcast
        if broadcastViewModel.isRunning {
            broadcastViewModel.stopBroadcast()
        }
    }
    
    func createChannel(completion: @escaping (Bool, ChannelCredentials?) -> Void) {
        toggleLoading(true)
        
        sdkNetworkHelper.createChannel(user: user) { [weak self] (success: Bool, channelCredentials: ChannelCredentials?) in
            DispatchQueue.main.async {
                if success, let channelCredentials = channelCredentials {
                    // Create Channel model for selectedChannel
                    let channel = ChannelDetails(
                        streamId: channelCredentials.streamId,
                        hostId: self?.user.hostId ?? "",
                        title: "Live Stream",
                        status: "LIVE",
                        createdAt: ISO8601DateFormatter().string(from: Date()),
                        playbackUrl: channelCredentials.playbackUrl,
                        chatRoomArn: channelCredentials.chatRoomArn,
                        hostAttributes: nil
                    )
                    self?.selectedChannel = channel
                }
                self?.toggleLoading(false)
                completion(success, channelCredentials)
            }
        }
    }
    
    func createUltraLowLatencyStream(hostId: String, title: String) {
        createChannel { [weak self] success, channelCredentials in
            if success, let channelCredentials = channelCredentials {
                let endpoint = "rtmps://\(channelCredentials.ingestEndpoint)/app/"
                print("CPK: Setting broadcast endpoint: \(endpoint)")
                print("CPK: Setting broadcast streamKey: \(channelCredentials.streamKey)")
                self?.broadcastViewModel.endpoint = endpoint
                self?.broadcastViewModel.streamKey = channelCredentials.streamKey
                self?.broadcastViewModel.startBroadcast()
            } else {
                print("CPK: Failed to create channel for Ultra Low Latency stream")
            }
        }
    }

    func createStage(_ type: StageType, completion: @escaping (Bool) -> Void = { _ in }) {
        toggleLoading(true)

        sdkNetworkHelper.createStage(type: type, user: user) { [weak self] (success: Bool, hostToken: HostParticipantToken?) in
            if success {
                print("ℹCPK: ✅ stage created")
                self?.stageModel.stageType = type
                self?.user.participantToken = nil
                self?.user.hostParticipantToken = hostToken
                self?.stageModel.collectInboundDebugData = false
                self?.user.participantId = hostToken?.tokenData.participantId


                DispatchQueue.main.async {
                    self?.activeStageHostParticipant = self?.user
                    self?.activeStageHostUsername = self?.user.username ?? ""
                }

                self?.stageModel.joinAsHost(onComplete: { [weak self] success in
                    print("ℹCPK: stage joined as host: \(success ? "✅" : "❌")")
                    

                    self?.getCreatedStage({ stage in
                        self?.finishStageCreation(stage)
                        completion(true)
                    })
                })
            } else {
                completion(false)
            }
        }
    }

    private func getCreatedStage(_ completion: @escaping (Stage) -> Void) {
        getStages(completion: { [weak self] _ in
            if let createdStage = self?.stagesModel.stages.first(where: { $0.hostId == self?.user.hostId }) {
                completion(createdStage)
            } else {
                print("ℹCPK: retrying to get created stage")
                self?.getCreatedStage(completion)
            }
        })
    }

    private func finishStageCreation(_ createdStage: Stage) {
        print("ℹCPK: found created stage (arn: \(createdStage.stageArn))")

        DispatchQueue.main.async {
            self.stagesModel.scrollTo(createdStage)
            createdStage.isJoined = true
            self.isSetupCompleted = true
        }

        print("ℹCPK: host will connect to chat now")
        connectToChat(createdStage.hostId)

        if createdStage.type == .video {
            stageModel.stageType = .video
            publishToVideoStage(.none)
        }

        if createdStage.type == .audio {
            stageModel.stageType = .audio
            publishToAudioStage(inAudioSeat: 0)
        }

        toggleLoading(false)
        
        //TODO: capture image and video preview after this when stage creation is complete
        // Now that the stage is created, you have the pre-signed URLs.
        // You can trigger the capture and upload process here.
        // For this example, we will assume the user triggers it via a button.
        print("ℹCPK: Stage creation complete. Ready to capture previews.")
    }

    // MARK: - Image and Video Capture
    
    func captureImage(completion: @escaping (String?) -> Void) {
        stageModel.captureImage { [weak self] outputPath in
            guard let self = self, let outputPath = outputPath else {
                print("CPK: ❌ Image capture failed or was cancelled.")
                completion(nil)
                return
            }
            print("CPK: ✅ Image capture completed. Path: \(outputPath.path)")
            completion(outputPath.path)
        }
    }

    func recordVideo(completion: @escaping (String?) -> Void) {
        stageModel.recordVideo(duration: 5.0) { [weak self] outputPath in
            guard let self = self, let outputPath = outputPath else {
                print("CPK:ℹ ❌ Video recording failed or was cancelled.")
                completion(nil)
                return
            }
            print("CPK:ℹ ✅ Video recording completed. Path: \(outputPath.path)")
            completion(outputPath.path)
        }
    }


    func publishToAudioStage(inAudioSeat: Int) {
        guard let participantId = user.participantId else {
            return
        }

        stageModel.toggleAudioOnlySubscribe(forParticipant: participantId)
        user.seatIndex = inAudioSeat

        updateSeat(seatIndex: inAudioSeat)
        DispatchQueue.main.async {
            self.user.isOnStage = true
        }
        stageModel.publish(user)
    }

    func changeSeat(to newIndex: Int) {
        guard let activeStage = activeStage,
              let seatIndex = user.seatIndex,
            !seatChangeInProgress else {
            return
        }

        activeStage.participant(leftAudioSeat: seatIndex) { [weak self] in
            self?.updateSeat(seatIndex: newIndex)
        }
    }

    private func updateSeat(seatIndex: Int) {
        guard let activeStage = activeStage,
              let participantId = user.participantId, !seatChangeInProgress else {
            return
        }
        seatChangeInProgress = true
        activeStage.participant(participantId, joinedAudioSeat: seatIndex) { [weak self] in
            guard let user = self?.user, let seats = self?.activeStage?.audioSeats else { return }
            self?.server.updateSeats(activeStage.hostId, seats: seats, user: user) { [weak self] success in
                if success {
                    self?.user.seatIndex = seatIndex
                    print("ℹCPK: ✅ audio seats updated")
                }

                self?.getStages(completion: { [weak self] _ in
                    self?.toggleLoading(false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.seatChangeInProgress = false
                    }
                })
            }
        }
    }

    func updateVideoConfiguration() {
        if isSimulcastOn {
            stageModel.videoConfig.simulcast.enabled = true
        } else {
            do {
                try stageModel.videoConfig.setMaxBitrate(maxBitrate * 1000)
                stageModel.videoConfig.simulcast.enabled = false
            } catch {
                print("ℹCPK: ❌ Failed to update maxBitrate: \(error)")
            }
        }

        stageModel.updateLocalVideoStreamConfiguration()
    }

    func publishToVideoStage(_ inMode: StageMode) {
        guard let activeStage = activeStage else {
            return
        }

        switch inMode {
            case .none:
                break
            case .spot:
                server.updateMode(activeStage.hostId, toStageMode: .spot, user: user) { success in
                    if success {
                        print("ℹCPK: ✅ stage mode updated to SPOT")
                    }
                }
            case .pk:
                server.updateMode(activeStage.hostId, toStageMode: .pk, user: user) { success in
                    if success {
                        print("ℹCPK: ✅ stage mode updated to PK/VS")
                    }
                }
        }

        DispatchQueue.main.async {
            self.user.isOnStage = true
            self.votesCountParticipant = 0
            self.votesCountHost = 0
        }
        stageModel.publish(user)
    }

    func endPublishingToStage(_ onComplete: @escaping () -> Void) {
        user.isOnStage = false
        stageModel.unpublish(user)

        if let stage = activeStage {
            if stage.type == .audio {
                if let participantId = user.participantId {
                    stageModel.toggleAudioOnlySubscribe(forParticipant: participantId)
                }
                if let seatIndex = user.seatIndex {
                    stage.participant(leftAudioSeat: seatIndex) { [weak self] in
                        guard let user = self?.user, let seats = self?.activeStage?.audioSeats else { return }
                        self?.server.updateSeats(stage.hostId, seats: seats, user: user) { _ in
                            onComplete()
                        }
                    }
                }
            }

            if stage.type == .video {
                // Update stage mode back to NONE
                server.updateMode(stage.hostId, toStageMode: .none, user: user) { _ in
                    onComplete()
                }
            }
        } else {
            onComplete()
        }
    }

    func connectToChat(_ hostId: String, reconnect: Bool = false) {
        print("ℹCPK: connecting to \(reconnect ? "previous" : "new") stage chat...")

        if !reconnect {
            if let oldChatModel = chatModel {
                print("ℹCPK: disconnecting previous stage chat...")
                oldChatModel.disconnect()
                chatModel = nil
            }

            self.chatModel = ChatModel()
            self.chatModel?.isHost = user.isHost
            chatModel?.eventDelegate = self
        }

        server.createChatToken(for: user, stageHostId: hostId) { [weak self] _, chatAuthToken in
            guard let user = self?.user else { return }
            let region = user.isHost ? user.hostParticipantToken?.region : user.participantToken?.region
            let tokenRequest = ChatTokenRequest(user: user,
                                                stageHostId: hostId,
                                                awsRegion: region ?? "us-west-2",
                                                chatRoomToken: chatAuthToken)
            self?.chatModel?.connectChatRoom(tokenRequest) { error in
                print("ℹCPK: ❌ Couldn't connect to chat: \(String(describing: error))")
            }
            self?.stageJoinInProgress = reconnect ? false : self?.stageJoinInProgress ?? false
        }
    }

    func leaveActiveStage(_ onComplete: @escaping () -> Void) {
        if streamType == .ultraLowLatency {
            // Handle Ultra Low Latency broadcast stop
            if broadcastViewModel.isRunning {
                broadcastViewModel.stopBroadcast()
            }
            clearData()
            onComplete()
            return
        }
        
        guard let stage = activeStage else {
            print("ℹCPK: ❌ Can't leave - no active stage")
            onComplete()
            return
        }

        print("ℹCPK: 🏁 leaving active stage (arn: \(stage.stageArn))...")
        toggleLoading(true)

        DispatchQueue.main.async {
            stage.isJoined = false
        }

        stageModel.leaveStage()
        chatModel?.disconnect()

        if user.isHost {
            // Delete created stage
            server.deleteStage(stageHostId: user.hostId) { [weak self] success in
                if success {
                    print("ℹCPK: ✅ stage deleted")

                    DispatchQueue.main.async {
                        withAnimation {
                            self?.userWantsToLeaveStage = false
                        }
                    }
                }

                onComplete()
                self?.toggleLoading(false)
            }

            clearData()

        } else {
            if let seatIndex = user.seatIndex {
                // Clear occupied audio seat
                stage.participant(leftAudioSeat: seatIndex) { [weak self] in
                    guard let user = self?.user, let seats = self?.activeStage?.audioSeats else { return }

                    switch stage.type {
                        case .audio:
                            self?.server.updateSeats(stage.hostId, seats: seats, user: user) { [weak self] _ in
                                self?.clearData()
                                onComplete()
                                self?.toggleLoading(false)
                            }
                        default:
                            self?.clearData()
                            onComplete()
                            self?.toggleLoading(false)
                    }
                }
            } else {
                clearData()
                onComplete()
                toggleLoading(false)
            }
        }
    }

    func appendErrorMessage(_ error: String) {
        // Show error message
        DispatchQueue.main.async {
            if self.errorMessages.contains(error) { return }
            self.errorMessages.append(error)
        }

        // Hide error message after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.removeErrorMessage(error)
        }
    }

    func removeErrorMessage(_ error: String) {
        DispatchQueue.main.async {
            if let index = self.errorMessages.firstIndex(of: error) {
                self.errorMessages.remove(at: index)
            }
        }
    }

    private func activeStageChanged(_ newStage: Stage?) {
        guard activeStage?.id != newStage?.id, let newStage = newStage else { return }

        if activeStage != nil, !user.isHost {
            // Disconnect from old stage and chat
            leaveActiveStage { [weak self] in
                // Then join the new one
                self?.join(newStage)
            }
        } else {
            join(newStage)
        }
    }

    func join(_ stage: Stage) {
        guard !stageJoinInProgress else {
            print("ℹCPK: stage is already being joined")
            return
        }
        stageJoinInProgress = true

        DispatchQueue.main.async {
            withAnimation {
                self.activeStage = stage
                self.votingSessionStartedAt = nil
                self.activeStageHostParticipant = nil
                self.activeStageSecondParticipant = nil
            }
        }

        guard shouldJoinActiveStage else {
            stageJoinInProgress = false
            return
        }

        toggleLoading(true)
        stageModel.stageType = stage.type
        print("ℹCPK: \(stage.type == .video ? "📺" : "📻") joining \(stage.hostId) stage (arn: \(stage.stageArn))...")

        server.join(stage, user: user) { [weak self] success, participantToken in
            if success {
                guard let token = participantToken?.token else {
                    print("ℹCPK: ❌ can't join - no participantToken")
                    self?.stageJoinInProgress = false
                    return
                }

                self?.stageModel.joinAsParticipant(token, onComplete: { _ in
                    self?.user.hostParticipantToken = nil
                    self?.user.participantToken = participantToken
                    self?.stageModel.collectInboundDebugData = true
                    self?.user.participantId = participantToken?.participantId

                    DispatchQueue.main.async {
                        self?.activeStageHostUsername = participantToken?.hostAttributes?["username"] ?? ""
                        withAnimation {
                            self?.userWantsToJoinVideoStage = false
                        }
                    }

                    self?.connectToChat(stage.hostId)
                })
                self?.toggleLoading(false)
                self?.stageJoinInProgress = false
            }

            DispatchQueue.main.async {
                stage.isJoined = success
            }
        }
    }

    func castVote(for user: User?) {
        guard let user = user,
              let stageId = activeStage?.hostId else {
            print("ℹCPK: ❌ Could't cast vote: active stage or user missing")
            return
        }

        server.castVote(in: stageId, for: user) { success in
            print("ℹCPK: vote casted for \(user.username): \(success ? "✅" : "❌")")
        }
    }

    private func applyActiveVotingTally() {
        guard let tally = activeVotingSessionTally else { return }

        if let key = activeStageHostParticipant?.username, let hostVotes = tally["\(key)"] {
            DispatchQueue.main.async {
                self.votesCountHost = hostVotes
                self.activeVotingSessionTally?.removeValue(forKey: key)
            }
        }

        if let key = activeStageSecondParticipant?.username, let participantVotes = tally["\(key)"] {
            DispatchQueue.main.async {
                self.votesCountParticipant = participantVotes
                self.activeVotingSessionTally?.removeValue(forKey: key)
            }
        }
    }

    func cleanUp() {
        if streamType == .ultraLowLatency {
            if broadcastViewModel.isRunning {
                broadcastViewModel.stopBroadcast()
            }
        } else {
            stagesModel.clearStages()
        }
        channelsModel.clearChannels()
        chatModel?.disconnect()
    }

    private func clearData() {
        DispatchQueue.main.async {
            self.user.isOnStage = false
            self.user.wantsAudioOnly = false
            self.activeStage?.mode = .none
            self.activeStage = nil
            self.votesCountParticipant = 0
            self.votesCountHost = 0
            self.votingSessionStartedAt = nil
        }
        user.seatIndex = nil
        user.hostParticipantToken = nil
        user.participantToken = nil
        user.participantId = nil
        user.participant = nil
        stageModel.collectInboundDebugData = true
        stageModel.debugData.clearAll()
    }

    // MARK: - Network monitoring

    func checkNetworkConnection() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    self.connectedToNetwork = true
                } else {
                    self.connectedToNetwork = false
                }
            }
        }
        monitor.start(queue: queue)
    }

    private func onNetworkRestore() {
        print("ℹCPK: ✅ Network restored")
        if activeStage != nil, !stageJoinInProgress {
            reconnectToStage()
            errorMessages = []
        }
    }

    private func onNetworkLoose() {
        print("ℹCPK: ⚠️ Network lost")
        appendErrorMessage("Network was lost")
        toggleLoading(true)
        stageJoinInProgress = false
    }

    private func reconnectToStage() {
        if streamType == .ultraLowLatency {
            // For Ultra Low Latency, just restart the broadcast if it was running
            if broadcastViewModel.isRunning {
                broadcastViewModel.stopBroadcast()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.broadcastViewModel.startBroadcast()
                }
            }
            toggleLoading(false)
            return
        }
        
        guard let stage = activeStage else {
            print("ℹCPK: ❌ Can't reconnect - no active stage set")
            toggleLoading(false)
            return
        }

        connectToChat(stage.hostId, reconnect: true)
        stageJoinInProgress = true

        if user.isHost {
            if stage.type == .video {
                publishToVideoStage(.none)
            }
            if stage.type == .audio {
                publishToAudioStage(inAudioSeat: 0)
            }
        } else {
            if user.isPublishing {
                stageModel.publish(user)
            }
        }

        toggleLoading(false)
    }
}


extension AppModel: ServerDelegate {
    func didEmitError(error: String) {
        self.appendErrorMessage(error)
        self.toggleLoading(false)
    }

    func activeVotingSessionInProgress(_ session: VotingSession) {
        print("ℹCPK: voting session is active: \(session)")
        activeVotingSessionTally = session.tally
        DispatchQueue.main.async {
            self.votingSessionStartedAt = self.dateFormatter.date(from: session.startedAt)
        }
    }
}

extension AppModel: StagesModelDelegate {
    func activeStageChanged(to stage: Stage?) {
        activeStageChanged(stage)
    }
}

extension AppModel: StageModelDelegate {
    func didEmitError(_ error: String) {
        self.appendErrorMessage(error)
        self.toggleLoading(false)
    }

    func participantJoined(_ participant: IVSParticipantInfo?) {
        print("ℹCPK: participant joined \(participant?.participantId ?? "nil")")
        guard let participantId = participant?.participantId,
              let newUser = stageModel.dataForParticipant(participantId) else {
            print("ℹCPK: ❌ could not get user for participantId \(String(describing: participant?.participantId))")
            return
        }

        if participant?.isLocal ?? false {
            guard user.isOnStage else {
                print("ℹCPK: will not set local user as active participant - user is not on stage")
                return
            }

            DispatchQueue.main.async {
                withAnimation {
                    if self.user.isHost {
                        self.activeStageHostParticipant = self.user
                        print("ℹCPK: active stage host set to local user")
                    } else {
                        self.activeStageSecondParticipant = self.user
                        print("ℹCPK: active 2nd participant set to local user")
                    }
                }
            }

        } else {
            guard newUser.streams.count == 0 else {
                print("ℹCPK: will not set new user as active participant - new user has 0 streams")
                return
            }

            guard let username = participant?.attributes["username"] else {
                print("ℹCPK: ❌ participant joined with no attributes - username missing")
                return
            }

            DispatchQueue.main.async {

                guard newUser.isPublishing else {
                    return
                }

                withAnimation {
                    if username == self.activeStageHostUsername {
                        self.activeStageHostParticipant = newUser
                        print("ℹCPK: active stage host set to new user")
                        self.applyActiveVotingTally()
                    } else {
                        self.activeStageSecondParticipant = newUser
                        print("ℹCPK: active 2nd participant set to new user")
                        self.applyActiveVotingTally()
                    }
                }
            }
        }
    }

    func participantLeftOrStoppedPublishing(_ participant: IVSParticipantInfo?) {
        print("ℹCPK: participant \(participant?.participantId ?? "nil") left or stopped publishing")
        if activeStageHostParticipant?.participantId == participant?.participantId {
            DispatchQueue.main.async {
                withAnimation {
                    self.activeStageHostParticipant = nil
                }
            }
            print("ℹCPK: leaving stage because host participant left the stage")
            leaveActiveStage { [weak self] in
                self?.stagesModel.scroll(.down)
            }
        }

        if activeStageSecondParticipant?.participantId == participant?.participantId {
            DispatchQueue.main.async {
                withAnimation {
                    self.activeStageSecondParticipant = nil
                }
            }
        }
    }

    func connectionStateChanged() {
        if stageModel.stageConnectionState == .disconnected {
            if user.isOnStage {
                endPublishingToStage {}
            }

            endPublishingToStage {
                DispatchQueue.main.async {
                    withAnimation {
                        self.activeStageHostParticipant = nil
                        self.activeStageSecondParticipant = nil
                    }
                }
            }
        }
    }

    func participantUsersChanged() {
        DispatchQueue.main.async {
            self.participantsChanged.toggle()
        }
    }
}

extension AppModel: ChatEventDelegate {
    func modeDidChange(_ attributes: [String: String]?) {
        guard let attributes = attributes,
              let newModeString = attributes["mode"],
              let newMode = StageMode(rawValue: newModeString) else { return }

        // Stop publishing (if I'm not the host) in case mode changed to NONE
        if user.isOnStage, !user.isHost && newMode == .none {
            DispatchQueue.main.async {
                self.endPublishingToStage {}
            }
        }

        DispatchQueue.main.async {
            withAnimation {
                self.stagesModel.stages.first(where: { $0.hostId == self.activeStage?.hostId })?.mode = newMode
            }
            self.votesCountParticipant = 0
            self.votesCountHost = 0
        }
    }

    func seatsDidChange(_ seats: [String]) {
        DispatchQueue.main.async {
            self.activeStage?.audioSeats = seats
        }
    }

    func votesChanged(_ attributes: [String: String]?) {
        print("ℹCPK: votes changed: \(String(describing: attributes))")
        guard let attributes = attributes else {
            print("ℹCPK: ❌ could not process vote attributes: no attributes")
            return
        }

        if let hostVotes = attributes["\(activeStageHostParticipant?.username ?? "")"] {
            if self.votesCountHost > Int(hostVotes) ?? 0 { return }

            DispatchQueue.main.async {
                self.votesCountHost = Int(hostVotes) ?? 0
            }
        }

        if let participantVotes = attributes["\(activeStageSecondParticipant?.username ?? "")"] {
            if self.votesCountParticipant > Int(participantVotes) ?? 0 { return }

            DispatchQueue.main.async {
                self.votesCountParticipant = Int(participantVotes) ?? 0
            }
        }
    }

    func votingStarted() {
        DispatchQueue.main.async {
            self.votingSessionStartedAt = Date.now
        }
    }

    func didReceive(_ reaction: String) {
        DispatchQueue.main.async {
            self.reactionViews.append(ReactionView(reaction: reaction))
            
        }
    }
    
    func didHostUpdatePinProductPosition(_ productPosition: CGPoint) {
        DispatchQueue.main.async {
            self.pinProductPosition = productPosition
        }
    }
    
    func didHostReplyPriceOf(_ productId: String) -> String? {
        guard let product = self.viewModelAllProduct.products.first(where: {
            $0.id == productId
        }) else {
            return "ขออภัยยังไม่มรายการนี้ถูกปักหมุด"
        }
        return "\(product.name) จากราคา \(product.price) เหลือเพียง \(product.discountedPrice)"
    }
    
    func didHostReplyRemainingOf(_ productId: String) -> String? {
        guard let product = self.viewModelAllProduct.products.first(where: {
            $0.id == productId
        }) else {
            return "ขออภัยยังไม่มรายการนี้ถูกปักหมุด"
        }
        return "\(product.name) เหลืออยู่ \(product.stock) ชิ้นครับ"
    }
}
