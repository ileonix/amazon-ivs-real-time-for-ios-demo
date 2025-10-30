//
//  Untitled.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 20/10/2568 BE.
//

import SwiftUI
import UIKit

@MainActor
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var url: URL?
    private var task: URLSessionDataTask?

    func load(from url: URL) {
        self.url = url
        task?.cancel()
        task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil, let uiImage = UIImage(data: data) else {
                print("❌ Error getting image from \(url.absoluteString): \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.image = nil
                }
                return
            }
            DispatchQueue.main.async {
                self.image = uiImage
            }
        }
        task?.resume()
    }
}

struct ProductSwiftUIView: View {
    let product: Product
    let showBottomSeparator: Bool
    var isCompact: Bool = false
    var cartViewModel: CartViewModel?

    @StateObject private var imageLoader = ImageLoader()

    var body: some View {
        VStack(alignment: .leading) {
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: ContentMode.fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack {
                        Text("฿\(product.discountedPrice)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        if product.discountedPrice != product.price {
                            Text("฿\(product.price)")
                                .font(.caption)
                                .strikethrough()
                                .foregroundColor(.gray)
                        }
                    }
                }
                if !isCompact {
                    Spacer()
                    
                    if let cartViewModel = cartViewModel {
                        Button("Add to Cart") {
                            cartViewModel.addToCart(product)
                        }
                        .buttonStyle(CommerceButtonStyle(backgroundColor: .gray))
                        .frame(width: 100)
                    }
                }
            }
            .padding()
            .onAppear {
//                if var url = URL(string: Constants2.productImageBaseUrl) {
//                    url.appendPathComponent(product.imageUrl)
//                    imageLoader.load(from: url)
//                }
                if let url = URL(string: product.imageUrl) {
                    imageLoader.load(from: url)
                }
            }

            if showBottomSeparator {
                Divider().background(Color.gray)
            }
        }
    }
}

struct MerchantProductInLiveSwiftUIView: View {
    @EnvironmentObject var appModel: AppModel
    let product: Product
    let showBottomSeparator: Bool
    var productsViewModel: ProductsViewModel?

    @StateObject private var imageLoader = ImageLoader()
    @State private var isShowDeleteToast = false

    var body: some View {
        VStack(alignment: .leading) {
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: ContentMode.fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                        .cornerRadius(10)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    HStack {
                        Text("฿\(product.discountedPrice)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("stock \(product.price) units")
                            .font(.caption)
                            .strikethrough()
                            .foregroundColor(.gray)
                        if product.discountedPrice != product.price {
                            Text("฿\(product.price)")
                                .font(.caption)
                                .strikethrough()
                                .foregroundColor(.gray)
                        }
                        
                    }
                }
                
                Spacer()
                
                Button("Pin") {
                    productsViewModel?.setPinProduct(productId: product.id)
                    appModel.webSocketManager.clientToServerPinProduct(hostId: appModel.user.hostId, productId: product.id)
                }
                .buttonStyle(CommerceButtonStyle(backgroundColor: {
                    if let pinProduct = productsViewModel?.getPinProduct() {
                        return pinProduct.id == product.id ? .green : .gray
                    } else {
                        return .gray
                    }
                }()))
                .frame(width: 100)
                
                Button("Remove") {
                    productsViewModel?.setPinProduct(productId: product.id)
                    //TODO: call DELETE product and tel remove socket
                    appModel.removeProductFromLive(hostId: appModel.user.hostId,
                                                   productId: product.id, onComplete: { success in
//                        isShowDeleteToast = success
                    })
                    appModel.webSocketManager.clientToServerRemoveProduct(hostId: appModel.user.hostId, productId: product.id)
                    productsViewModel?.removeProduct(productId: product.id)
                    //isShowDeleteToast = false
                }
                //.toast(isShowing: $isShowDeleteToast, text: "Delete \(product.id) success")
                .buttonStyle(CommerceButtonStyle(backgroundColor: .gray))
                .frame(width: 100)
            }
            .padding()
            .onAppear {
                if let url = URL(string: product.imageUrl) {
                    imageLoader.load(from: url)
                }
            }

            if showBottomSeparator {
                Divider().background(Color.gray)
            }
        }
    }
}

struct VerticalProductSwiftUIView: View {
    let product: Product
    let showBottomSeparator: Bool
    var isCompact: Bool = false

    @StateObject private var imageLoader = ImageLoader()

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
            // Image at top
            Group {
                if let image = imageLoader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipped()
                        .cornerRadius(2)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .cornerRadius(2)
                }
            }

            // Product Name and Price Info
            VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                Text(product.name)
                    .font(isCompact ? .subheadline : .headline)
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text("฿\(product.discountedPrice)")
                        .font(isCompact ? .caption : .subheadline)
                        .foregroundColor(.white)

                    if product.discountedPrice != product.price {
                        Text("฿\(product.price)")
                            .font(isCompact ? .caption2 : .caption)
                            .strikethrough()
                            .foregroundColor(.gray)
                    }
                }
            }

            if showBottomSeparator {
                Divider().background(Color.gray)
            }
        }
        .padding()
        .onAppear {
//            if var url = URL(string: Constants2.productImageBaseUrl) {
//                url.appendPathComponent(product.imageUrl)
//                imageLoader.load(from: url)
//            }
            if let url = URL(string: product.imageUrl) {
                imageLoader.load(from: url)
            }
        }
    }
}
