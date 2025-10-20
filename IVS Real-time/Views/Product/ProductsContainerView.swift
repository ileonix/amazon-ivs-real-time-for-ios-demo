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

    init() {
        loadProducts()
    }

    private func loadProducts() {
        if let path = Bundle.main.path(forResource: "Products", ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                self.products = try JSONDecoder().decode(Products.self, from: data).items
            } catch {
                print("‼️ Error decoding products: \(error)")
            }
        }
    }
}

//struct ProductsContainerView: View {
//    @StateObject private var productsViewModel = ProductsViewModel()
//    @StateObject private var playerViewModel = PlayerViewModel()
//
//    @State private var playerState: PlayerState = .expanded
//    @State private var playerDragOffset: CGSize = .zero
//    @State private var playerEndDragOffset: CGSize = .zero
//    
//    @State private var isProductListVisible: Bool = false
//    // State for draggable product list
//    @State private var productListOffset: CGFloat = 0
//    @State private var productListDragOffset: CGFloat = 0
//
//    private let collapsedSize = CGSize(width: 120, height: 200)
//
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // Expanded Player View (background)
//                if playerState == .expanded {
//                    PlayerSwiftUIView(viewModel: playerViewModel, isProductListVisible: $isProductListVisible)
//                        .edgesIgnoringSafeArea(.all)
//                        .onAppear {
//                            if productListOffset == 0 {
//                                productListOffset = geometry.size.height - 250
//                            }
//                            playerViewModel.products = productsViewModel.products
//                        }
//                } else {
//                    Color.black.edgesIgnoringSafeArea(.all)
//                }
//
//                // Product List
//                if isProductListVisible {
//                    ProductListView(products: productsViewModel.products, playerState: $playerState, homeButtonAction: {
//                        withAnimation(.spring()) {
//                            isProductListVisible = false
//                        }
//                    })
//                    .background(Color.black.opacity(0.8))
//                    .cornerRadius(30)
//                    .animation(.spring(), value: playerState)
//                    .transition(.asymmetric(
//                        insertion: .identity,
//                        removal: .move(edge: .bottom).combined(with: .opacity)
//                    ))
//                    .ignoresSafeArea(edges: .bottom)
//                }
//
//                // Collapsed Player View
//                if playerState == .collapsed {
//                    PlayerSwiftUIView(viewModel: playerViewModel, isProductListVisible: .constant(false))
//                        .frame(width: collapsedSize.width, height: collapsedSize.height)
//                        .cornerRadius(10)
//                        .shadow(radius: 5)
//                        .offset(playerDragOffset)
//                        .position(
//                            x: geometry.size.width - (collapsedSize.width / 2) - 20 + playerEndDragOffset.width,
//                            y: geometry.size.height - (collapsedSize.height / 2) - 50 - geometry.safeAreaInsets.bottom + playerEndDragOffset.height
//                        )
//                        .gesture(
//                            DragGesture()
//                                .onChanged { value in
//                                    self.playerDragOffset = value.translation
//                                }
//                                .onEnded { value in
//                                    self.playerEndDragOffset.width += value.translation.width
//                                    self.playerEndDragOffset.height += value.translation.height
//                                    self.playerDragOffset = .zero
//                                }
//                        )
//                        .onTapGesture {
//                            withAnimation {
//                                playerState = .expanded
//                            }
//                        }
//                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity))
//                }
//            }
//        }
//    }
//}

struct ProductListView: View {
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
