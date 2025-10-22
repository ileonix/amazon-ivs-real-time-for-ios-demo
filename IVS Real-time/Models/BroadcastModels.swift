//
//  BroadcastModels.swift
//  IVS Real-time
//
//  Data models for Broadcast Session support
//

import Foundation

struct ChannelCredentials: Codable {
    let channelArn: String
    let ingestEndpoint: String
    let streamKey: String
    let playbackUrl: String
    let chatRoomArn: String
}

struct ChannelDetails: Codable {
    let channelArn: String
    let playbackUrl: String
    let chatRoomArn: String
    let hostId: String
    let status: String
    let hostAttributes: [String: String]?
}

struct Channels: Codable {
    let channels: [ChannelDetails]
}