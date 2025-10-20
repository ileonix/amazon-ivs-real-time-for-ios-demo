//
//  ShoppingCartView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 20/10/2568 BE.
//

import SwiftUI

struct ShoppingCartView: View {
    @ObservedObject var cartViewModel: CartViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if cartViewModel.items.isEmpty {
                    Spacer()
                    Text("Your cart is empty")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(cartViewModel.items) { item in
                            CartItemRow(item: item, cartViewModel: cartViewModel)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    VStack(spacing: 16) {
                        HStack {
                            Text("Total: ฿\(cartViewModel.totalPrice)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        Button("Checkout") {
                            // Checkout action
                        }
                        .buttonStyle(CommerceButtonStyle(backgroundColor: .blue))
                    }
                    .padding()
                }
            }
            .navigationTitle("Shopping Cart")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    @ObservedObject var cartViewModel: CartViewModel
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: Constants2.productImageBaseUrl + item.product.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.product.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("฿\(item.product.discountedPrice)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Button("-") {
                    cartViewModel.decrementQuantity(productId: item.product.id)
                }
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(15)
                .buttonStyle(PlainButtonStyle())
                
                Text("\(item.quantity)")
                    .frame(minWidth: 30)
                
                Button("+") {
                    cartViewModel.incrementQuantity(productId: item.product.id)
                }
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(15)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
}
