//
//  WarehouseStockView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 20/10/2568 BE.
//

import SwiftUI

struct WarehouseStockView: View {
    @ObservedObject var productsViewModel: ProductsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                if productsViewModel.products.isEmpty {
                    Spacer()
                    Text("No products in warehouse")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List {
                        ForEach(productsViewModel.products, id: \.id) { product in
                            WarehouseItemRow(product: product, productsViewModel: productsViewModel)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Warehouse Stock")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct WarehouseItemRow: View {
    let product: Product
    @ObservedObject var productsViewModel: ProductsViewModel
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: Constants2.productImageBaseUrl + product.imageUrl)) { image in
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
                Text(product.name)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("฿\(product.discountedPrice)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Stock: \(product.stock)")
                    .font(.caption)
                    .foregroundColor(product.stock > 0 ? .green : .red)
            }
            
            Spacer()
            
            HStack {
                Button("-") {
                    productsViewModel.decrementStock(productId: product.id)
                }
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(15)
                .buttonStyle(PlainButtonStyle())
                
                Text("\(product.stock)")
                    .frame(minWidth: 30)
                
                Button("+") {
                    productsViewModel.incrementStock(productId: product.id)
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
