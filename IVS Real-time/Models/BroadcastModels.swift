//
//  BroadcastModels.swift
//  IVS Real-time
//
//  Data models for Broadcast Session support
//

import Foundation

enum StreamType: String, Codable {
    case REALTIME
    case ULTRA_LOW_LATENCY
}

struct ChannelCredentials: Codable {
    let streamId: String
    let streamType: StreamType
    let channelArn: String
    let ingestEndpoint: String
    let streamKey: String
    let playbackUrl: String
    let chatRoomArn: String
    let region: String
}

struct ChannelDetails: Codable {
    let streamId: String
    let hostId: String
    let streamType: StreamType
    let title: String
    let status: String
    let createdAt: String
    let playbackUrl: String
    let chatRoomArn: String
    let hostAttributes: [String: String]?
}

struct Channels: Codable {
    let streams: [ChannelDetails]
}
