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
