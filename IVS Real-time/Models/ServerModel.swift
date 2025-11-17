//
//  ServerModel.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 30/03/2023.
//

import Foundation
import SwiftUI
import LiveCommerceSDK

protocol ServerDelegate: AnyObject {
    func didEmitError(error: String)
    func activeVotingSessionInProgress(_ session: VotingSession)
}

class ServerModel: ObservableObject {
    var delegate: ServerDelegate?
    var decoder = JSONDecoder()
    
    // Mode selection flag
    @Published var useBroadcastMode: Bool = false // false = Real-time stages, true = Broadcast sessions
    
    enum Endpoint: String {
        case root = ""
        case verify
        // Real-time stage endpoints
        case create
        case join
        case updateMode = "update/mode"
        case updateSeats = "update/seats"
        // Broadcast session endpoints
//        case createChannel = "streams"
//        case getChannels = "streams"//?type=ULTRA_LOW_LATENCY"
        case streams
        // Common endpoints
        case uploads
        case chatTokenCreate = "chatToken/create"
        case castVote
        case disconnect
    }
    
    enum EcommerceEndpoint: String {
        //product
        case products
        case productsStream = "products/stream/{{stream_key}}"
        case addProductToLive = "products/stream/{{stream_key}}/attach/{{product_id}}"
        case removeProductToLive = "products/stream/{{stream_key}}/detach/{{product_id}}"
        case reOrderProductInLive = "products/stream/{{stream_key}}/reorder/{{product_id}}"
        //stream
        case streams //GET to get list and POST to create stream
        case endStream = "streams/{{stream_key}}/end"
        case getStreamByKey = "streams/{{stream_key}}"
        // Replaces placeholders (e.g. `{{key}}`) in the path with actual values.
        func path(replacing params: [String: String]? = nil) -> String {
            var path = self.rawValue
            if let params = params {
                for (key, value) in params {
                    path = path.replacingOccurrences(of: "{{\(key)}}", with: value)
                }
            }
            return path
        }
    }
    
    enum HTTPMethod: String {
        case GET
        case POST
        case PUT
        case DELETE
        case PATCH
    }
    
    // Verify authentication code
    func verify(silent: Bool, _ onComplete: @escaping (Bool) -> Void) {
        send(silent: silent, .GET, endpoint: .verify, body: nil) { _, _, error in
            if let error = error {
                print("ℹ ❌ Could not verify customer code: \(error)")
                self.delegate?.didEmitError(error: "Invalid code")
                onComplete(false)
                return
            }

            onComplete(true)
        }
    }

    func getStages(onlyActive: Bool = true, _ onComplete: @escaping (Bool, [StageDetails]) -> Void) {
        send(.GET,
             endpoint: .root,
             body: nil,
             queryItems: onlyActive ? [URLQueryItem(name: "status", value: "active")] : nil,
             onComplete: { [weak self] success, data, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false, [])
            }

            guard let data = data else {
                print("ℹ ❌ No data in response")
                onComplete(false, [])
                return
            }

            do {
                let rawStages = try self?.decoder.decode(Stages.self, from: data)
                guard let stages = rawStages?.stages else {
                    print("ℹ ❌ Got something else than stages array")
                    onComplete(false, [])
                    return
                }
                print("ℹ got \(stages.count) stages")
                onComplete(success, stages)

            } catch {
                print("❌ \(error)")
                onComplete(false, [])
                return
            }
        })
    }

    func createStage(type: StageType, user: User, onComplete: @escaping (Bool, HostParticipantToken?) -> Void) {
        guard let customerCode = UserDefaults.standard.string(forKey: Constants.kCustomerCode) else {
            delegate?.didEmitError(error: "Customer code not set")
            return
        }

        let body = """
            {
                "cid": "\(customerCode)",
                "hostId": "\(user.hostId)",
                "hostAttributes": {
                    "avatarColBottom": "\(user.avatar.colBottom)",
                    "avatarColLeft": "\(user.avatar.colLeft)",
                    "avatarColRight": "\(user.avatar.colRight)",
                    "username": "\(user.username)"
                },
                "type": "\(type.rawValue)"
            }
        """

        send(.POST, endpoint: .create, body: body, onComplete: { [weak self] _, data, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false, nil)
            }

            guard let data = data else {
                print("ℹ ❌ No data in response")
                onComplete(false, nil)
                return
            }

            do {
                let hostParticipantToken = try self?.decoder.decode(HostParticipantToken.self, from: data)
                //let uploadPreviewUrls = try self?.decoder.decode(UploadPreviewUrls.self, from: data)
                print("ℹ got host participant token: \(String(describing: hostParticipantToken))")
                onComplete(true, hostParticipantToken)
            } catch {
                print("ℹ ❌ \(error)")
                onComplete(false, nil)
                return
            }
        })
    }
    
    // MARK: - Broadcast Session Methods
    
    func createChannel(user: User, onComplete: @escaping (Bool, ChannelCredentials?) -> Void) {
//        guard let customerCode = UserDefaults.standard.string(forKey: Constants.kCustomerCode) else {
//            delegate?.didEmitError(error: "Customer code not set")
//            return
//        }

        let body = """
            {
                "hostId": "\(user.hostId)",
                "title": "Live Stream by \(user.hostId)",
                "hostAttributes": {
                  "name": "\(user.hostId)",
                  "description": "Live Shopping"
                },
                "streamConfig": {
                  "latencyMode": "LOW",
                  "recordingEnabled": true,
                  "maxViewers": 1000
                }
            }
        """

        sendWithUnsafeDelegate(.POST, endpoint: .streams, body: body, onComplete: { [weak self] _, data, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false, nil)
            }

            guard let data = data else {
                print("ℹ ❌ No data in response")
                onComplete(false, nil)
                return
            }

            do {
                let channelCredentials = try self?.decoder.decode(ChannelCredentials.self, from: data)
                print("ℹ got channel credentials: \(String(describing: channelCredentials))")
                onComplete(true, channelCredentials)
            } catch {
                print("ℹ ❌ \(error)")
                onComplete(false, nil)
                return
            }
        })
    }
    
    func getChannels(onlyActive: Bool = true, _ onComplete: @escaping (Bool, [ChannelDetails]) -> Void) {
        send(.GET,
             endpoint: .streams,
             body: nil,
             queryItems: onlyActive ? [URLQueryItem(name: "type", value: "ULTRA_LOW_LATENCY")] : nil,
             onComplete: { [weak self] success, data, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false, [])
            }

            guard let data = data else {
                print("ℹ ❌ No data in response")
                onComplete(false, [])
                return
            }

            do {
                let rawChannels = try self?.decoder.decode(Channels.self, from: data)
                guard let channels = rawChannels?.streams else {
                    print("ℹ ❌ Got something else than channels array")
                    onComplete(false, [])
                    return
                }
                print("ℹ got \(channels.count) channels")
                onComplete(success, channels)

            } catch {
                print("❌ \(error)")
                onComplete(false, [])
                return
            }
        })
    }
    
    func createS3UploadUrls(user: User, hostCaptureVideoPath: String, hostCaptureImagePath: String, onComplete: @escaping (UploadPreviewUrls?) -> Void) {
        let body = """
            {
                "hostId": "\(user.hostId)"
            }
        """
        send(.POST, endpoint: .uploads, body: body, onComplete: { [weak self] _, data, errorMessage in
            guard let self = self else {
                onComplete(nil)
                return
            }
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(nil)
            }
            
            guard let data = data else {
                print("ℹ ❌ No data in response")
                onComplete(nil)
                return
            }
            
            do {
                let uploadPreviewUrls = try decoder.decode(UploadPreviewUrlsWrapper.self, from: data)
                guard let uploadVideoSignedUrl = URL(string: uploadPreviewUrls.uploadPreviewUrls.uploadVideoSignedUrl ?? "")
                    ,let uploadImageSignedUrl = URL(string: uploadPreviewUrls.uploadPreviewUrls.uploadImageSignedUrl ?? "")
                else {
                    onComplete(nil)
                    return
                }
                
                Task {
                    do {
                        
                        print("CPK: before upload video local video path\(hostCaptureVideoPath)")
                        print("CPK: before upload video s3 upload path \(uploadVideoSignedUrl)")
                        try await self.uploadFileToS3PresignedURL(
                            fileURL: URL(fileURLWithPath: hostCaptureVideoPath),
                            presignedURL: uploadVideoSignedUrl,
                            contentType: "video/mp4"
                        )
                        
                        print("CPK: before upload image local video path\(hostCaptureImagePath)")
                        print("CPK: before upload image s3 upload path \(uploadImageSignedUrl)")
                        try await self.uploadFileToS3PresignedURL(
                            fileURL: URL(fileURLWithPath: hostCaptureImagePath),
                            presignedURL: uploadImageSignedUrl,
                            contentType: "image/jpeg"
                        )
                        
                        onComplete(uploadPreviewUrls.uploadPreviewUrls)
                    } catch {
                        print("CPK:❌ Upload failed: \(error) \(error.localizedDescription)")
                        onComplete(nil)
                    }
                }
                
                onComplete(uploadPreviewUrls.uploadPreviewUrls)
            } catch {
                print("CPK:ℹ ❌ \(error)")
                onComplete(nil)
                return
            }
        })
    }
    
    private func uploadFileToS3PresignedURL(fileURL: URL, presignedURL: URL, contentType: String, completion: @escaping (Result<Void, Error>) -> Void) {
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.uploadTask(with: request, fromFile: fileURL) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "InvalidResponse", code: -1)))
                return
            }

            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                let statusError = NSError(domain: "S3Upload", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "Upload failed with status code: \(httpResponse.statusCode)"
                ])
                completion(.failure(statusError))
            }
        }

        task.resume()
    }
    
    private func uploadFileToS3PresignedURL(fileURL: URL, presignedURL: URL, contentType: String) async throws {
        var request = URLRequest(url: presignedURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "S3Upload", code: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }


    func createChatToken(for user: User, stageHostId: String, onComplete: @escaping (Bool, ChatAuthToken?) -> Void) {
        let body = """
            {
                "hostId": "\(stageHostId)",
                "userId": "\(user.userId)",
                "attributes": {
                    "avatarColBottom": "\(user.avatar.colBottom)",
                    "avatarColLeft": "\(user.avatar.colLeft)",
                    "avatarColRight": "\(user.avatar.colRight)",
                    "username": "\(user.username)"
                }
            }
        """

        send(.POST, endpoint: .chatTokenCreate, body: body, onComplete: { [weak self] _, data, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false, nil)
            }

            guard let data = data else {
                print("ℹ ❌ No data in response")
                onComplete(false, nil)
                return
            }

            do {
                let chatToken = try self?.decoder.decode(ChatAuthToken.self, from: data)
                print("ℹ got chat token: \(String(describing: chatToken))")
                onComplete(true, chatToken)
            } catch {
                print("ℹ ❌ \(error)")
                onComplete(false, nil)
                return
            }
        })
    }

    func join(_ stage: Stage, user: User, onComplete: @escaping (Bool, ParticipantToken?) -> Void) {
        let body = """
            {
                "hostId": "\(stage.hostId)",
                "userId": "\(user.userId)",
                "attributes": {
                    "avatarColBottom": "\(user.avatar.colBottom)",
                    "avatarColLeft": "\(user.avatar.colLeft)",
                    "avatarColRight": "\(user.avatar.colRight)",
                    "username": "\(user.username)"
                }
            }
        """

        send(.POST, endpoint: .join, body: body, onComplete: { [weak self] _, data, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false, nil)
            }

            guard let data = data else {
                print("ℹ ❌ No data in response")
                onComplete(false, nil)
                return
            }

            do {
                let participantToken = try self?.decoder.decode(ParticipantToken.self, from: data)
                print("ℹ got participant token: \(String(describing: participantToken))")

                self?.checkForActiveVotingSession(participantToken)

                onComplete(true, participantToken)
            } catch {
                print("ℹ ❌ \(error)")
                onComplete(false, nil)
                return
            }
        })
    }

    func deleteStage(stageHostId: String, onComplete: @escaping (Bool) -> Void) {
        let body = """
            {
                "hostId": "\(stageHostId)"
            }
        """

        send(.DELETE, endpoint: .root, body: body, onComplete: { success, _, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false)
            }

            onComplete(success)
        })
    }

    func updateMode(_ stageId: String, toStageMode: StageMode, user: User, onComplete: @escaping (Bool) -> Void) {
        let body = """
            {
                "hostId": "\(stageId)",
                "userId": "\(user.userId)",
                "mode": "\(toStageMode.rawValue)"
            }
        """

        send(.PUT, endpoint: .updateMode, body: body, onComplete: { success, _, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false)
            }

            onComplete(success)
        })
    }

    func updateSeats(_ stageId: String, seats: [String], user: User, onComplete: @escaping (Bool) -> Void) {
        let body = """
            {
                "hostId": "\(stageId)",
                "userId": "\(user.userId)",
                "seats": \(seats)
            }
        """

        send(.PUT, endpoint: .updateSeats, body: body, onComplete: { success, _, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false)
            }

            onComplete(success)
        })
    }

    func castVote(in stageId: String, for user: User, onComplete: @escaping (Bool) -> Void) {
        let body = """
            {
                "hostId": "\(stageId)",
                "vote": "\(user.userId)"
            }
        """

        send(.POST, endpoint: .castVote, body: body, onComplete: { success, _, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false)
            }

            onComplete(success)
        })
    }

    func disconnectUser(from stageHostId: String, userId: String, participantId: String, onComplete: @escaping (Bool) -> Void) {
        let body = """
            {
                "hostId": "\(stageHostId)",
                "userId": "\(userId)",
                "participantId": "\(participantId)"
            }
        """

        send(.PUT, endpoint: .disconnect, body: body, onComplete: { success, _, errorMessage in
            if let error = errorMessage {
                print("ℹ ❌ \(error)")
                onComplete(false)
            }

            onComplete(success)
        })
    }

    // MARK: Private

    private func checkForActiveVotingSession(_ token: ParticipantToken?) {
        print("ℹ checking for active voting session...")
        if let session = token?.metadata.activeVotingSession {
            delegate?.activeVotingSessionInProgress(session)
        }
    }

    private func send(silent: Bool = false, _ method: HTTPMethod, endpoint: Endpoint, body: String?, queryItems: [URLQueryItem]? = nil, onComplete: @escaping (Bool, Data?, String?) -> Void) {
        guard let customerCode = UserDefaults.standard.string(forKey: Constants.kCustomerCode) else {
            if silent { return }
            delegate?.didEmitError(error: "Customer code not set")
            return
        }

        let urlComponents = NSURLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "\(customerCode).\(Constants.API_URL)"
        urlComponents.queryItems = queryItems
        urlComponents.path = "/\(endpoint.rawValue)"

        guard let url = urlComponents.url else {
            onComplete(false, nil, "Couldn't get url from URLComponents")
            return
        }

        let session = URLSession(configuration: .default)
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(UserDefaults.standard.string(forKey: Constants.kApiKey) ?? "", forHTTPHeaderField: "x-api-key")

        if let body = body {
            request.httpBody = body.data(using: .utf8)
        }

        print("ℹ 🔗 sending \(method) '\(url.absoluteString)' \(body != nil ? "with body: \(body!)" : "")")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("ℹ 🔗 ❌ Failed to send '\(method)' to '\(endpoint)': \(error)")
                onComplete(false, nil, silent ? nil : error.localizedDescription)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if ![200, 201, 204].contains(httpResponse.statusCode) {
                    print("ℹ 🔗 Got status code \(httpResponse.statusCode) when sending \(request)")
                    if let data = data, let response = String(data: data, encoding: .utf8) {
                        print(response)
                        onComplete(false, nil, "Got status code \(httpResponse.statusCode) with response: \(response)")
                    } else {
                        print("ℹ 🔗 ❌ Got status code \(httpResponse.statusCode) when sending \(method) to \(request)")
                    }
                    return
                }

                print("ℹ 🔗 sent \(method) to '\(endpoint)' successfully")
                onComplete(true, data, nil)
            }
        }
        .resume()
    }
    
    //MARK: Ecommerce Product API
    //MARK: Ecommerce customer API
    //MARK: Get live product
    func getProductListInLive(hostId: String, onComplete: @escaping ([AddProductToLiveResponse]) -> Void) {
        sendEcommerceAPI(.GET,
                         endpoint: .productsStream,
                         params: ["stream_key": hostId],
                         body: nil,
                         onComplete: { success, data, error in
            if let error = error {
                print("CPK: ℹ ❌ \(error)")
                onComplete([])
            }
            guard let data = data else {
                print("CPK: ℹ ❌ No data in response")
                onComplete([])
                return
            }
            do {
                let productList = try JSONDecoder().decode([AddProductToLiveResponse].self, from: data)
                onComplete(productList)
            } catch {
                print("CPK: ❌ \(error)")
                onComplete([])
                return
            }
        })
    }
    
    //MARK: Ecommerce merchant API
    //MARK: All product for add by other API
    func getProductList(onComplete: @escaping ([ECommerceProduct]) -> Void) {
        sendEcommerceAPI(.GET, endpoint: .products, body: nil, onComplete: { success, data, error in
            if let error = error {
                print("CPK: ℹ ❌ \(error)")
                onComplete([])
            }
            guard let data = data else {
                print("CPK: ℹ ❌ No data in response")
                onComplete([])
                return
            }
            do {
                let productList = try JSONDecoder().decode([ECommerceProduct].self, from: data)
                onComplete(productList)
            } catch {
                print("CPK: ❌ \(error)")
                onComplete([])
                return
            }
        })
    }
    
    //MARK: add product from /products to live
    func addProductInLive(hostId: String, productId: String, onComplete: @escaping (AddProductToLiveResponse?) -> Void) {
        sendEcommerceAPI(.POST,
                         endpoint: .addProductToLive,
                         params: ["stream_key": hostId, "product_id": productId],
                         body: nil,
                         onComplete: { success, data, error in
            if let error = error {
                print("CPK: ℹ ❌ \(error)")
                onComplete(nil)
            }
            guard let data = data else {
                print("CPK: ℹ ❌ No data in response")
                onComplete(nil)
                return
            }
            do {
                let product = try JSONDecoder().decode(AddProductToLiveResponse.self, from: data)
                onComplete(product)
            } catch {
                print("CPK: ❌ \(error)")
                onComplete(nil)
                return
            }
        })
    }
    
    func removeProductFromLive(hostId: String, productId: String, onComplete: @escaping (Bool) -> Void) {
        sendEcommerceAPI(.DELETE,
                         endpoint: .removeProductToLive,
                         params: ["stream_key": hostId, "product_id": productId],
                         body: nil,
                         onComplete: { success, data, error in
            if let error = error {
                print("CPK: ℹ ❌ \(error)")
                onComplete(false)
            }
            guard let data = data else {
                print("CPK: ℹ ❌ No data in response")
                onComplete(false)
                return
            }
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = jsonObject["success"] as? Bool {
                    print("✅ Success:", success)
                    onComplete(success)
                }
                
            } catch {
                print("CPK: ❌ \(error)")
                onComplete(false)
                return
            }
        })
    }
    
    func reorderProductInLive(hostId: String, productId: String, onComplete: @escaping (Bool) -> Void) {
        sendEcommerceAPI(.PATCH,
                         endpoint: .reOrderProductInLive,
                         params: ["stream_key": hostId, "product_id": productId],
                         body: nil,
                         onComplete: { success, data, error in
            if let error = error {
                print("CPK: ℹ ❌ \(error)")
                onComplete(false)
            }
            guard let data = data else {
                print("CPK: ℹ ❌ No data in response")
                onComplete(false)
                return
            }
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = jsonObject["ok"] as? Bool {
                    print("✅ Success:", success)
                    onComplete(success)
                }
                
            } catch {
                print("CPK: ❌ \(error)")
                onComplete(false)
                return
            }
        })
    }
    
    func createStream(hostId: String, onComplete: @escaping (EcommerceStreamInfo?) -> Void) {
        let body = """
            {
                "key": "\(hostId)",
                "title": "\(hostId)",
                "ivsChannelArn": "arn:aws:ivs:ap-southeast-1:123456789012:channel/AbCdEfGhIj"
            }
        """
        //EcommerceStreamInfo
        sendEcommerceAPI(.POST, endpoint: .streams, body: body, onComplete: { success, data, error in
            if let error = error {
                print("CPK: ℹ ❌ \(error)")
                onComplete(nil)
            }
            guard let data = data else {
                print("CPK: ℹ ❌ No data in response")
                onComplete(nil)
                return
            }
            do {
                let stream = try JSONDecoder().decode(EcommerceStreamInfo.self, from: data)
                print("✅ Stream title:", stream.title)
                print("📅 Created at:", stream.createdAt)
                onComplete(stream)
            } catch {
                print("CPK: ❌ \(error)")
                onComplete(nil)
                return
            }
        })
    }
    
    private func sendEcommerceAPI(_ method: HTTPMethod,
                                  endpoint: EcommerceEndpoint,
                                  params: [String: String]? = nil,
                                  body: String?,
                                  queryItems: [URLQueryItem]? = nil,
                                  onComplete: @escaping (Bool, Data?, String?) -> Void) {
        let urlComponents = NSURLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "\(Constants.ECOMMERECE_API_URL)"
        urlComponents.queryItems = queryItems
        urlComponents.path = "/api/\(endpoint.path(replacing: params))"

        guard let url = urlComponents.url else {
            onComplete(false, nil, "Couldn't get url from URLComponents")
            return
        }

        //let session = URLSession(configuration: .default) //For Prod
        let session = URLSession(configuration: .default, delegate: UnsafeSessionDelegate(), delegateQueue: nil) //TODO: For prevent SSL from ngrok only not for Production
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = body.data(using: .utf8)
        }

        print("CPK: ℹ 🔗 sending \(method) '\(url.absoluteString)' \(body != nil ? "with body: \(body!)" : "")")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("CPK: ℹ 🔗 ❌ Failed to send '\(method)' to '\(endpoint)': \(error)")
                onComplete(false, nil, error.localizedDescription)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if ![200, 201, 204].contains(httpResponse.statusCode) {
                    print("CPK: ℹ 🔗 Got status code \(httpResponse.statusCode) when sending \(request)")
                    if let data = data, let response = String(data: data, encoding: .utf8) {
                        print(response)
                        onComplete(false, nil, "Got status code \(httpResponse.statusCode) with response: \(response)")
                    } else {
                        print("ℹ 🔗 ❌ Got status code \(httpResponse.statusCode) when sending \(method) to \(request)")
                    }
                    return
                }

                print("ℹ 🔗 sent \(method) to '\(endpoint)' successfully")
                onComplete(true, data, nil)
            }
        }
        .resume()
    }
    
    private func sendWithUnsafeDelegate(_ method: HTTPMethod, endpoint: Endpoint, body: String?, queryItems: [URLQueryItem]? = nil, onComplete: @escaping (Bool, Data?, String?) -> Void) {
        guard let customerCode = UserDefaults.standard.string(forKey: Constants.kCustomerCode) else {
            delegate?.didEmitError(error: "Customer code not set")
            return
        }

        let urlComponents = NSURLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "\(customerCode).\(Constants.API_URL)"
        urlComponents.queryItems = queryItems
        urlComponents.path = "/\(endpoint.rawValue)"

        guard let url = urlComponents.url else {
            onComplete(false, nil, "Couldn't get url from URLComponents")
            return
        }

        let session = URLSession(configuration: .default, delegate: UnsafeSessionDelegate(), delegateQueue: nil)
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = method.rawValue
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(UserDefaults.standard.string(forKey: Constants.kApiKey) ?? "", forHTTPHeaderField: "x-api-key")

        if let body = body {
            request.httpBody = body.data(using: .utf8)
        }

        print("ℹ 🔗 sending \(method) '\(url.absoluteString)' \(body != nil ? "with body: \(body!)" : "")")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("ℹ 🔗 ❌ Failed to send '\(method)' to '\(endpoint)': \(error)")
                onComplete(false, nil, error.localizedDescription)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if ![200, 201, 204].contains(httpResponse.statusCode) {
                    print("ℹ 🔗 Got status code \(httpResponse.statusCode) when sending \(request)")
                    if let data = data, let response = String(data: data, encoding: .utf8) {
                        print(response)
                        onComplete(false, nil, "Got status code \(httpResponse.statusCode) with response: \(response)")
                    } else {
                        print("ℹ 🔗 ❌ Got status code \(httpResponse.statusCode) when sending \(method) to \(request)")
                    }
                    return
                }

                print("ℹ 🔗 sent \(method) to '\(endpoint)' successfully")
                onComplete(true, data, nil)
            }
        }
        .resume()
    }
}

//TODO: For Testing only
/*
 ❌ Failed to send 'GET' to 'products': Error Domain=NSURLErrorDomain Code=-1200 "An SSL error has occurred and a secure connection to the server cannot be made." UserInfo={NSLocalizedRecoverySuggestion=Would you like to connect to the server anyway?, _kCFStreamErrorDomainKey=3, NSErrorPeerCertificateChainKey=(
 CPK: ℹ ❌ An SSL error has occurred and a secure connection to the server cannot be made.
 */
class UnsafeSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        // Trust any certificate (for dev only!)
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
}
