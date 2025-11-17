import SwiftUI

/// Manages e-commerce functionality shared across streaming types
class EcommerceManager: ObservableObject {
    @ObservedObject var productsViewModel: ProductsViewModel
    @ObservedObject var webSocketManager: WebSocketManager
    
    private let server: ServerModel
    
    @Published var pinProductPosition: CGPoint = CGPoint(x: 150, y: 150)
    @Published var reactionViews: [ReactionView] = []
    
    init(server: ServerModel) {
        self.server = server
        self.productsViewModel = ProductsViewModel()
        self.webSocketManager = WebSocketManager()
        
        webSocketManager.delegate = self
    }
    
    func getProductList(onComplete: @escaping ([Product]) -> Void) {
        server.getProductList() { [weak self] products in
            guard let self = self else { return }
            self.productsViewModel.setProductsFromEcommerce(products)
            let eProducts = products.map {
                Product(id: $0.id,
                        name: $0.title,
                        imageUrl: $0.imageUrl,
                        imageLargeUrl: $0.imageUrl,
                        price: $0.price,
                        discountedPrice: Int(Double($0.price) * 0.9),
                        longDescription: $0.title,
                        stock: $0.stock,
                        isPinned: $0.isPinned)
            }
            onComplete(eProducts)
        }
    }
    
    func getProductListInLive(hostId: String, onComplete: @escaping ([Product]) -> Void) {
        server.getProductListInLive(hostId: hostId) { [weak self] products in
            guard let self = self else { return }
            self.productsViewModel.setProductsFromEcommerce(products)
            let eProducts = products.map {
                Product(id: $0.productId,
                        name: $0.product.title,
                        imageUrl: $0.product.imageUrl,
                        imageLargeUrl: $0.product.imageUrl,
                        price: $0.product.price,
                        discountedPrice: Int(Double($0.product.price) * 0.9),
                        longDescription: $0.product.title,
                        stock: $0.product.stock,
                        isPinned: $0.isPinned)
            }
            onComplete(eProducts)
        }
    }
    
    func addProductToLive(hostId: String, productId: String, onComplete: @escaping (AddProductToLiveResponse?) -> Void) {
        server.addProductInLive(hostId: hostId, productId: productId, onComplete: onComplete)
    }
    
    func removeProductFromLive(hostId: String, productId: String, onComplete: @escaping (Bool) -> Void) {
        server.removeProductFromLive(hostId: hostId, productId: productId, onComplete: onComplete)
    }
}

// MARK: - WebSocket Delegate
extension EcommerceManager: WebSocketManagerDelegate {
    func didReceiveReaction(_ reaction: String) {
        DispatchQueue.main.async {
            self.reactionViews.append(ReactionView(reaction: reaction))
        }
    }
    
    func didUpdatePinProductPosition(_ position: CGPoint) {
        DispatchQueue.main.async {
            self.pinProductPosition = position
        }
    }
}