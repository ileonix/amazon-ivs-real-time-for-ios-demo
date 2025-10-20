//
//  CartItem.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 20/10/2568 BE.
//

import Foundation

struct CartItem: Identifiable, Equatable {
    let id: String
    let product: Product
    var quantity: Int
    
    init(product: Product, quantity: Int) {
        self.id = product.id
        self.product = product
        self.quantity = quantity
    }
    
    var totalPrice: Int {
        return product.discountedPrice * quantity
    }
}

class CartViewModel: ObservableObject {
    @Published var items: [CartItem] = []
    
    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
    
    var totalPrice: Int {
        items.reduce(0) { $0 + $1.totalPrice }
    }
    
    func addToCart(_ product: Product) {
        if let index = items.firstIndex(where: { $0.id == product.id }) {
            items[index].quantity += 1
        } else {
            items.append(CartItem(product: product, quantity: 1))
        }
    }
    
    func removeFromCart(_ cartItem: CartItem) {
        items.removeAll { $0.id == cartItem.id }
    }
    
    func updateQuantity(for cartItem: CartItem, quantity: Int) {
        if let index = items.firstIndex(where: {
            print("CPK: update \($0.product.name) \(cartItem.product.name)")
            return $0.id == cartItem.id
        }) {
            if quantity > 0 {
                items[index].quantity = quantity
            } else {
                removeFromCart(cartItem)
            }
        }
    }
    
    func incrementQuantity(productId: String) {
        if let index = items.firstIndex(where: {
            print("CPK: incrementQuantity \($0.product.name) \($0.product.id) == \(productId)")
            return $0.id == productId
        }) {
            items[index].quantity += 1
        }
    }
    
    func decrementQuantity(productId: String) {
        if let index = items.firstIndex(where: {
            print("CPK: decrementQuantity at index:[\(index)]\($0.product.name) \($0.product.id) == \(productId)")
            return $0.id == productId
        }) {
            if items[index].quantity > 1 {
                items[index].quantity -= 1
            } else {
                items.remove(at: index)
            }
        }
    }
}
