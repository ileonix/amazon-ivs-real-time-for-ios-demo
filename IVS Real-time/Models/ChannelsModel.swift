//
//  ChannelsModel.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 10/11/2568 BE.
//

import SwiftUI

protocol ChannelsModelDelegate: AnyObject {
    func activeChannelChanged(to channel: ChannelDetails?)
}

class ChannelsModel: ObservableObject {
    @Published var channels: [ChannelDetails] = []
    weak var delegate: ChannelsModelDelegate?
    
    var logicalChannels: [ChannelDetails] {
        return channels//.filter { $0.status == "ACTIVE" }
    }
    
    func setNewChannels(_ newChannels: [ChannelDetails]) {
        channels = newChannels
    }
    
    func clearChannels() {
        channels.removeAll()
    }
}
