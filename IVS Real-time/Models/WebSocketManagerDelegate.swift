//
//  WebSocketManagerDelegate.swift
//  IVS Real-time
//
//  Created by Assistant.
//

import Foundation

extension AppModel: WebSocketManagerDelegate {
    func webSocketDidConnect() {
        print("CPK: 🔌 Socket.IO connected successfully")
    }
    
    func webSocketDidDisconnect() {
        print("CPK: 🔌 Socket.IO disconnected")
    }
    
    func webSocketDidReceiveMessage(_ event: String, data: [Any]) {
        print("CPK: 📨 Socket.IO event: \(event) with data: \(data)")
        // Handle incoming events here
    }
    
    func webSocketDidReceiveError(_ error: String) {
        print("CPK: ❌ Socket.IO error: \(error)")
        appendErrorMessage("Socket.IO error: \(error)")
    }
}
