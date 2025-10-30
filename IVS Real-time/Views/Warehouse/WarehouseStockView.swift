//
//  WarehouseStockView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 20/10/2568 BE.
//

import SwiftUI

struct WarehouseStockView: View {
    @EnvironmentObject var appModel: AppModel
    @ObservedObject var productsViewModel: ProductsViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var selectedProducts: Set<String> = []
    
    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return productsViewModel.products
        } else {
            return productsViewModel.products.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    // Search Bar
                    HStack {
                        TextField("Search products...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Select All") {
                            selectedProducts = Set(filteredProducts.map { $0.id })
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                        
                        Button("Clear") {
                            selectedProducts.removeAll()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    if filteredProducts.isEmpty {
                        Spacer()
                        Text(searchText.isEmpty ? "No products in warehouse" : "No products found")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredProducts, id: \.id) { product in
                                WarehouseItemRow(
                                    product: product,
                                    productsViewModel: productsViewModel,
                                    isSelected: selectedProducts.contains(product.id),
                                    onSelectionChanged: { isSelected in
                                        if isSelected {
                                            selectedProducts.insert(product.id)
                                        } else {
                                            selectedProducts.remove(product.id)
                                        }
                                    }
                                )
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                            }
                            .onMove(perform: moveProducts)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                
                // Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Update selected") {
                            // Add selected products action
                            print("Adding products: \(selectedProducts)")
                            
                            //TODO: socket attached and call attach product to live
                            selectedProducts.forEach { productId in
                                if selectedProducts.contains(productId) {
                                    appModel.addProductToLive(hostId: appModel.user.hostId,
                                                              productId: productId, onComplete: { _ in
                                        print("CPK: \(productId) >>> Product added to live")
                                    })
                                    appModel.webSocketManager.clientToServerAttachProduct(hostId: appModel.user.hostId,
                                                                                          productId: productId)
                                } else {
                                    appModel.removeProductFromLive(hostId: appModel.user.hostId,
                                                                   productId: productId, onComplete: { _ in
                                        print("CPK: \(productId) >>> Product remove from live")
                                    })
                                    appModel.webSocketManager.clientToServerRemoveProduct(hostId: appModel.user.hostId,
                                                                                          productId: productId)
                                }
                            }
                            productsViewModel.products.removeAll { product in
                                !selectedProducts.contains(product.id)
                            }
                            presentationMode.wrappedValue.dismiss()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding()
                    }
                }
            }
            .navigationTitle("Warehouse Stock")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                appModel.getProductList(onComplete: { products in
                    productsViewModel.setProducts(products)
                    selectedProducts = Set(products.filter { $0.isPinned } .map { $0.id })
                })
            }
        }
    }
    
    private func moveProducts(from source: IndexSet, to destination: Int) {
        productsViewModel.products.move(fromOffsets: source, toOffset: destination)
    }
}

struct WarehouseItemRow: View {
    let product: Product
    @ObservedObject var productsViewModel: ProductsViewModel
    let isSelected: Bool
    let onSelectionChanged: (Bool) -> Void
    
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
            
            Button(action: {
                onSelectionChanged(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            HStack {
                Button("-") {
                    productsViewModel.decrementStock(productId: product.id)
                }
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(15)
                .buttonStyle(PlainButtonStyle())
                .disabled(true)
                
                Text("\(product.stock)")
                    .frame(minWidth: 30)
                
                Button("+") {
                    productsViewModel.incrementStock(productId: product.id)
                }
                .frame(width: 30, height: 30)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(15)
                .buttonStyle(PlainButtonStyle())
                .disabled(true)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }
}
