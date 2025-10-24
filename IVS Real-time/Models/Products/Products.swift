//
//  Products.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 20/10/2568 BE.
//


import UIKit

enum Constants2 {
    // MARK: Stream url
    static let streamUrl = "https://4c62a87c1810.us-west-2.playback.live-video.net/api/video/v1/us-west-2.049054135175.channel.onToXRHIurEP.m3u8"

    // MARK: Product image source url
    static let productImageBaseUrl = "https://ecommerce.ivsdemos.com"
}

enum ImageEnum {
    static func getFrom(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url, completionHandler: { (data, _, error) in
            guard let data = data, error == nil else {
                print("❌ Error getting image from \(url.absoluteString): \(error!)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if let image = UIImage(data: data) {
                DispatchQueue.main.async { completion(image) }
            } else {
                print("❌ Could not get UIImage from data \(data)")
                DispatchQueue.main.async { completion(nil) }
            }
        }).resume()
    }
}

struct Products: Decodable {
    var items: [Product] = []

    enum CodingKeys: String, CodingKey {
        case items = "products"
    }
}

struct Product: Decodable, Equatable {
    var id: String
    var name: String
    var imageUrl: String
    var imageLargeUrl: String
    var price: Int
    var discountedPrice: Int
    var longDescription: String
    var stock: Int
    var isPinned: Bool

    func getImage(completion: @escaping (UIImage?) -> Void) {
        if var url = URL(string: Constants2.productImageBaseUrl) {
            url.appendPathComponent(imageUrl)
            ImageEnum.getFrom(url) { image in
                completion(image)
            }
        }
    }
}
