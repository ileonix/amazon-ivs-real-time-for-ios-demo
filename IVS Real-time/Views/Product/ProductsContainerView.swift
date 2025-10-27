//
//  ProductsContainerView.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 20/10/2568 BE.
//

import SwiftUI

enum PlayerState {
    case expanded, collapsed
}

class ProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
//    @Published var serverModel: ServerModel
    init() {
//        self.serverModel = ServerModel()
//        loadProducts()
    }
    
    func setProductsFromEcommerce(_ products: [ECommerceProduct]) {
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
        DispatchQueue.main.async {
            self.products = eProducts
        }
    }
    
    func setProducts(_ products: [Product]) {
        DispatchQueue.main.async {
            self.products = products
        }
    }
    
    func decrementStock(productId: String) {
        if let index = products.firstIndex(where: { $0.id == productId }) {
            if products[index].stock > 0 {
                products[index].stock -= 1
            }
        }
    }
    
    func incrementStock(productId: String) {
        if let index = products.firstIndex(where: { $0.id == productId }) {
            products[index].stock += 1
        }
    }

    func setPinProduct(productId: String) {
        for (index, product) in products.enumerated() {
            products[index].isPinned = product.id == productId
        }
    }
}

struct CustomerProductListView: View {
    let products: [Product]
    @Binding var playerState: PlayerState
    var homeButtonAction: () -> Void
    @ObservedObject var cartViewModel: CartViewModel
    @State private var headerAlpha: Double = 1.0
    @State private var showingCart = false

    var body: some View {
        List {
            Section(header:
                Text("All Products")
                    .font(.custom("AmazonEmber-Bold", size: 24))
                    .foregroundColor(.clear) // Hide text, but keep for layout
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        HStack {
                            Text("All Products")
                                .font(.custom("AmazonEmber-Bold", size: 24))
                                .foregroundColor(.white)
                            Spacer()
                            
                            Button(action: { showingCart = true }) {
                                ZStack {
                                    Image(systemName: "cart")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Circle())
                                    
                                    if cartViewModel.totalItems > 0 {
                                        Text("\(cartViewModel.totalItems)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(4)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .offset(x: 12, y: -12)
                                    }
                                }
                            }
                            
                            Button(action: homeButtonAction) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        .opacity(playerState == .expanded ? 1 : 0)
                        .animation(.default, value: playerState)
                    )
                    .overlay(
                        Capsule()
                            .fill(Color.gray)
                            .frame(width: 40, height: 5)
                            .padding(.top, 8)
                        , alignment: .top
                    )
                    .padding(.vertical)
                    .opacity(headerAlpha)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                        }
                    )
            ) {
                ForEach(products, id: \.id) { product in
                    ProductSwiftUIView(product: product, showBottomSeparator: product.id != products.last?.id, cartViewModel: cartViewModel)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            let offset = value
            var alpha: CGFloat = 1
            if offset < -20 { // Adjust this value to control when fade starts
                alpha = max(0, (100 + offset) / 100)
            }
            self.headerAlpha = alpha
        }
        .listStyle(.plain)
        .background(Color.clear)
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingCart) {
            ShoppingCartView(cartViewModel: cartViewModel)
        }
        .onAppear {
            // To make list background transparent
            UITableView.appearance().backgroundColor = .clear
            UITableViewCell.appearance().backgroundColor = .clear
        }
    }
}

struct MerchantLiveProductListView: View {
    let products: [Product]
    @Binding var playerState: PlayerState
    var homeButtonAction: () -> Void
    @ObservedObject var productsViewModel: ProductsViewModel
    @State private var headerAlpha: Double = 1.0
    @State private var showingWarehouse = false

    private var headerTitle: some View {
        Text("รายการสินค้าขายในไลฟ์")
            .font(.custom("AmazonEmber-Bold", size: 24))
            .foregroundColor(.clear)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var headerButtons: some View {
        HStack {
            Text("รายการสินค้าขายในไลฟ์")
                .font(.custom("AmazonEmber-Bold", size: 24))
                .foregroundColor(.white)
            Spacer()
            Button("Warehouse") { showingWarehouse = true }
                .foregroundColor(.white)
            Button("✕", action: homeButtonAction)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .opacity(playerState == .expanded ? 1 : 0)
        .animation(.default, value: playerState)
    }
    
    private var dragIndicator: some View {
        Capsule()
            .fill(Color.gray)
            .frame(width: 40, height: 5)
            .padding(.top, 8)
    }
    
    private var scrollReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
        }
    }
    
    private var sectionHeader: some View {
        headerTitle
            .overlay(headerButtons)
            .overlay(dragIndicator, alignment: .top)
            .padding(.vertical)
            .opacity(headerAlpha)
            .background(scrollReader)
    }
    
    private var productsList: some View {
        List {
            Section(header: sectionHeader) {
                ForEach(products, id: \.id) { product in
                    MerchantProductInLiveSwiftUIView(product: product,
                                                     showBottomSeparator: product.id != products.last?.id,
                                                     productsViewModel: productsViewModel)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
            }
        }
    }

    var body: some View {
        productsList
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let offset = value
                var alpha: CGFloat = 1
                if offset < -20 {
                    alpha = max(0, (100 + offset) / 100)
                }
                self.headerAlpha = alpha
            }
            .listStyle(.plain)
            .background(Color.clear)
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingWarehouse) {
                WarehouseStockView(productsViewModel: productsViewModel)
            }
            .onAppear {
                UITableView.appearance().backgroundColor = .clear
                UITableViewCell.appearance().backgroundColor = .clear
            }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
