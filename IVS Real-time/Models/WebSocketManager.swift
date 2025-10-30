//
//  WebSocketManager.swift
//  IVS Real-time
//
//  Created by Assistant on $(date).
//

import Foundation
import SocketIO

protocol WebSocketManagerDelegate: AnyObject {
    func webSocketDidConnect()
    func webSocketDidDisconnect()
    func webSocketDidReceiveMessage(_ event: String, data: [Any])
    func webSocketDidReceiveError(_ error: String)
}

class WebSocketManager: NSObject, ObservableObject {
    weak var delegate: WebSocketManagerDelegate?
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private let serverURL = "https://implorable-tisa-intercondyloid.ngrok-free.dev"
    
    @Published var isConnected = false
    
    override init() {
        super.init()
        setupSocket()
    }
    
    private func setupSocket() {
        guard let url = URL(string: serverURL) else {
            print("❌ Invalid Socket.IO URL")
            return
        }
        
        manager = SocketManager(socketURL: url, config: [
            .log(true),
            .compress,
            .extraHeaders(["ngrok-skip-browser-warning": "true"]),
            .forceWebsockets(true)
        ])
        
        socket = manager?.defaultSocket
        
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("✅ Socket.IO connected")
            DispatchQueue.main.async {
                self?.isConnected = true
                self?.delegate?.webSocketDidConnect()
            }
        }
        
        socket?.on(clientEvent: .disconnect) { [weak self] data, ack in
            print("🔌 Socket.IO disconnected")
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.delegate?.webSocketDidDisconnect()
            }
        }
        
        socket?.on(clientEvent: .error) { [weak self] data, ack in
            print("❌ Socket.IO error: \(data)")
            DispatchQueue.main.async {
                self?.delegate?.webSocketDidReceiveError("Socket.IO error: \(data)")
            }
        }
        
        socket?.onAny { [weak self] event in
            print("📨 Socket.IO event: \(event.event) with data: \(event.items ?? [])")
            DispatchQueue.main.async {
                self?.delegate?.webSocketDidReceiveMessage(event.event, data: event.items ?? [])
            }
        }
    }
    
    func connect() {
        guard !isConnected else { return }
        print("🔌 Connecting to Socket.IO...")
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
        print("🔌 Socket.IO disconnected")
    }
    
    func emit(_ event: String, data: [Any] = []) {
        guard isConnected else {
            print("❌ Socket.IO not connected")
            return
        }
        socket?.emit(event, data)
    }
    
    func on(_ event: String, callback: @escaping ([Any], SocketAckEmitter) -> Void) {
        socket?.on(event, callback: callback)
    }
}

// MARK: - Server To Client Topics
/*
     joined: (payload: { key: string }) => void;
     pinned: (payload: { productId: string }) => void;
     unpinAll: (payload: Record<string, never>) => void;
     attached: (payload: {
         productId: string;
         position?: number;
         isPinned?: boolean;
         product?: ProductResponse;
     }) => void;
     productRemoved: (payload: { productId: string }) => void;
     reordered: (payload: { productId: string; position: number }) => void;
     pinPosition: (payload: { productId: string; x: number; y: number }) => void;
 */
extension WebSocketManager {
    enum ServerToClient: String, CaseIterable {
        case joined
        case pinned
        case unpinAll
        case attached
        case productRemoved
        case reordered
        case pinPosition
    }
    
    // MARK: joined
    func serverToClientTopicJoined(callback: @escaping (String) -> Void) {
        socket?.on(ServerToClient.joined.rawValue) { data, ack in
            if let dict = data.first as? [String: Any],
               let hostId = dict["key"] as? String {
                print("CPK: 📡 joined: key =", hostId)
                callback(hostId)
            } else {
                print("CPK: ⚠️ Could not parse 'key' from:", data)
            }
        }
    }
    
    // MARK: pinned
    func serverToClientTopicPinProduct(callback: @escaping (String) -> Void) {
        socket?.on(ServerToClient.pinned.rawValue) { data, ack in
            if let dict = data.first as? [String: Any],
               let productId = dict["productId"] as? String {
                print("CPK: 📦 pinned: productId =", productId)
                callback(productId)
            } else {
                print("CPK: ⚠️ Could not parse 'productId' from:", data)
            }
        }
    }
    
    // MARK: unpinAll
    func serverToClientTopicUnpinAll(callback: @escaping () -> Void) {
        socket?.on(ServerToClient.unpinAll.rawValue) { data, ack in
            print("CPK: 🧹 unpinAll triggered")
            callback()
        }
    }
    
    // MARK: attached
    func serverToClientTopicAttached(callback: @escaping (_ productId: String, _ position: Int?, _ isPinned: Bool?) -> Void) {
        socket?.on(ServerToClient.attached.rawValue) { data, ack in
            if let dict = data.first as? [String: Any],
               let productId = dict["productId"] as? String {
                let position = dict["position"] as? Int
                let isPinned = dict["isPinned"] as? Bool
                print("CPK: 📎 attached: productId=\(productId), position=\(position ?? -1), isPinned=\(isPinned ?? false)")
                callback(productId, position, isPinned)
            } else {
                print("CPK: ⚠️ Could not parse 'attached' payload:", data)
            }
        }
    }
    
    // MARK: productRemoved
    func serverToClientTopicProductRemoved(callback: @escaping (String) -> Void) {
        socket?.on(ServerToClient.productRemoved.rawValue) { data, ack in
            if let dict = data.first as? [String: Any],
               let productId = dict["productId"] as? String {
                print("CPK: 🗑️ productRemoved: productId =", productId)
                callback(productId)
            } else {
                print("CPK: ⚠️ Could not parse 'productId' from:", data)
            }
        }
    }
    
    // MARK: reordered
    func serverToClientTopicReordered(callback: @escaping (_ productId: String, _ position: Int) -> Void) {
        socket?.on(ServerToClient.reordered.rawValue) { data, ack in
            if let dict = data.first as? [String: Any],
               let productId = dict["productId"] as? String,
               let position = dict["position"] as? Int {
                print("CPK: 🔁 reordered: productId=\(productId), position=\(position)")
                callback(productId, position)
            } else {
                print("CPK: ⚠️ Could not parse 'reordered' payload:", data)
            }
        }
    }
    
    // MARK: pinPosition
    func serverToClientTopicPinPosition(callback: @escaping (_ productId: String, _ x: Double, _ y: Double) -> Void) {
        socket?.on(ServerToClient.pinPosition.rawValue) { data, ack in
            if let dict = data.first as? [String: Any],
               let productId = dict["productId"] as? String,
               let x = dict["x"] as? Double,
               let y = dict["y"] as? Double {
                print("CPK: 📍 pinPosition: productId=\(productId), x=\(x), y=\(y)")
                callback(productId, x, y)
            } else {
                print("CPK: ⚠️ Could not parse 'pinPosition' payload:", data)
            }
        }
    }
}

//MARK: Client to Server
/*
     join: (payload: { key: string }) => void;
     pinProduct: (payload: { key: string; productId: string }) => void;
     unpinAll: (payload: { key: string }) => void;
     attachProduct: (payload: { key: string; productId: string }) => void;
     removeProduct: (payload: { key: string; productId: string }) => void;
     reorderProduct: (payload: { key: string; productId: string; position: number }) => void;
     pinPosition: (payload: { key: string; productId: string; x: number; y: number }) => void;
 */
enum ClientToServer: String, CaseIterable {
    case join
    case pinProduct
    case unpinAll
    case attachProduct
    case removeProduct
    case reorderProduct
    case pinPosition
}

extension WebSocketManager {
    
    // MARK: join
    func clientToServerJoin(hostId: String) {
        let payload: [String: Any] = ["key": hostId]
        socket?.emit(ClientToServer.join.rawValue, payload)
        print("CPK: 📤 emit join:", payload)
    }
    
    // MARK: pinProduct
    func clientToServerPinProduct(hostId: String, productId: String) {
        let payload: [String: Any] = ["key": hostId, "productId": productId]
        socket?.emit(ClientToServer.pinProduct.rawValue, payload)
        print("CPK: 📤 emit pinProduct:", payload)
    }
    
    // MARK: unpinAll
    func clientToServerUnpinAll(hostId: String) {
        let payload: [String: Any] = ["key": hostId]
        socket?.emit(ClientToServer.unpinAll.rawValue, payload)
        print("CPK: 📤 emit unpinAll:", payload)
    }
    
    // MARK: attachProduct
    func clientToServerAttachProduct(hostId: String, productId: String) {
        let payload: [String: Any] = ["key": hostId, "productId": productId]
        socket?.emit(ClientToServer.attachProduct.rawValue, payload)
        print("CPK: 📤 emit attachProduct:", payload)
    }
    
    // MARK: removeProduct
    func clientToServerRemoveProduct(hostId: String, productId: String) {
        let payload: [String: Any] = ["key": hostId, "productId": productId]
        socket?.emit(ClientToServer.removeProduct.rawValue, payload)
        print("CPK: 📤 emit removeProduct:", payload)
    }
    
    // MARK: reorderProduct
    func clientToServerReorderProduct(hostId: String, productId: String, position: Int) {
        let payload: [String: Any] = [
            "key": hostId,
            "productId": productId,
            "position": position
        ]
        socket?.emit(ClientToServer.reorderProduct.rawValue, payload)
        print("CPK: 📤 emit reorderProduct:", payload)
    }
    
    // MARK: pinPosition
    func clientToServerPinPosition(hostId: String, productId: String, x: Double, y: Double) {
        let payload: [String: Any] = [
            "key": hostId,
            "productId": productId,
            "x": x,
            "y": y
        ]
        socket?.emit(ClientToServer.pinPosition.rawValue, payload)
        print("CPK: 📤 emit pinPosition:", payload)
    }
}
