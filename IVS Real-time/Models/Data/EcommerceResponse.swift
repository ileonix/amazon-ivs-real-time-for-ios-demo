//
//  EcommerceResponse.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 22/10/2568 BE.
//

import Foundation
import UIKit

struct ECommerceProduct: Decodable, Equatable {
    let id: String
    let title: String
    let price: Int
    let stock: Int
    let imageUrl: String
    let isPinned: Bool
    
    func getImage(completion: @escaping (UIImage?) -> Void) {
        if var url = URL(string: self.imageUrl) {
            url.appendPathComponent(imageUrl)
            ImageEnum.getFrom(url) { image in
                completion(image)
            }
        }
    }
}

struct AddProductToLiveResponse: Decodable {
    let productId: String
    let position: Int
    let isPinned: Bool
    let product: ECommerceProduct
}

struct EcommerceStreamInfo: Decodable {
    let id: String
    let key: String
    let title: String
    let ivsChannelArn: String
    let isLive: Bool
    let createdAt: String
    let updatedAt: String
}
