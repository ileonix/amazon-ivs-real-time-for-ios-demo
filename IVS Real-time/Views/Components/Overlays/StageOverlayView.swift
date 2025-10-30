//
//  StageOverlayView.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI

struct StageOverlayView: View {

    enum TapState {
        case inactive, active
    }

    @EnvironmentObject var appModel: AppModel

    @ObservedObject var stage: Stage

    @GestureState private var state = TapState.inactive

    @State private var overlayHidden: Bool = false
    
    //Products
    @State private var playerState: PlayerState = .expanded
//    @StateObject private var productsViewModel = ProductsViewModel()
    @StateObject private var allProducts: ProductsViewModel = ProductsViewModel()
    @StateObject private var cartViewModel = CartViewModel()
    @State private var isCustomerProductListVisible: Bool = false
    @State private var isMerchantProductListVisible: Bool = false
    
    // State for draggable product list
    @State private var productListOffset: CGFloat = 0
    @State private var productListDragOffset: CGFloat = 0
    private let collapsedSize = CGSize(width: 120, height: 200)
    
    //Single product
    @State private var currentPinProduct: Product?
    @State private var productControlsVisible = true
    @State private var productDragOffset: CGSize = .zero
    @State private var productPosition: CGPoint = CGPoint(x: 100, y: 150) // Default top-left-ish
    
    //ProductList drag control
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
//            if stage.type == .video {
//                MultiTapView {
//                    withAnimation {
//                        overlayHidden.toggle()
//                    }
//                }
//            }

            VStack {
                OverlayHeaderView()
                    .opacity(overlayHidden ? 0 : 1)
                Spacer()
                StageButtonsOverlayView(stage: stage)
                    .opacity(overlayHidden ? 0 : 1)
            }
            
            if appModel.user.isHost, stage.isJoined {
                ZStack {
                    Spacer().frame(height: 50)
                    //Button for trigger Product List
                    if productControlsVisible {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    isMerchantProductListVisible.toggle()
                                }
                            }) {
                                Image(systemName: "storefront")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding([.top, .trailing], 8)
                    }
                    
                    if isMerchantProductListVisible {
                        MerchantLiveProductListView(products: allProducts.products, playerState: $playerState, homeButtonAction: {
                            withAnimation(.spring()) {
                                isMerchantProductListVisible = false
                            }
                        }, productsViewModel: allProducts)
                        .offset(y: dragOffset > 0 ? dragOffset : 0) // Only drag downward
                        .gesture(
                            DragGesture()
                                .updating($isDragging) { _, state, _ in
                                    state = true
                                }
                                .onChanged { value in
                                    // Only allow downward dragging
                                    if value.translation.height > 0 {
                                        dragOffset = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 100 {
                                        // Custom action on drag down
                                        withAnimation(.spring()) {
                                            isMerchantProductListVisible = false
                                        }
                                    }
                                    dragOffset = 0
                                }
                        )
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(30)
                        .animation(.spring(), value: playerState)
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .ignoresSafeArea(edges: .bottom)
                    } else {
                        //Single Product
                        if let product = allProducts.products.first(where: {$0.isPinned}),
                            appModel.isConnected {
                            VStack(spacing: 12) {
                                VerticalProductSwiftUIView(product: product,
                                                           showBottomSeparator: false,
                                                           isCompact: true)
                                VStack {
                                    Button("Unpin") {
                                        for (index, _product) in allHostProducts.products.enumerated() {
                                            if _product.id == product.id {
                                                allHostProducts.products[index].isPinned = false
                                            }
                                        }
                                        appModel.webSocketManager.clientToServerUnpinAll(hostId: appModel.user.hostId)
                                    }.buttonStyle(CommerceButtonStyle(backgroundColor: .red))
                                }
                            }
                            .frame(width: UIScreen.main.bounds.width / 3)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .scaleEffect(0.5)
                            .position(x: productPosition.x + productDragOffset.width,
                                      y: productPosition.y + productDragOffset.height)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        productDragOffset = value.translation
                                        let realtimePosition = CGPoint(x: productPosition.x + productDragOffset.width, y: productPosition.y + productDragOffset.height)
        //                                appModel.chatModel?.hostUpdatePinProductPosition(position: realtimePosition)
                                    }
                                    .onEnded { value in
                                        productPosition.x += value.translation.width
                                        productPosition.y += value.translation.height
                                        productDragOffset = .zero
                                        //If need less resource use this
                                        appModel.chatModel?.hostUpdatePinProductPosition(position: productPosition)
                                    }
                            )
                        }
                    }
                }.onAppear {
                    print("CPK: HOST onAppear - isHost: \(appModel.user.isHost), isConnected: \(appModel.isConnected)")
                    appModel.getProductList { products in
                        print("CPK: HOST products fetched \(products.count)")
                        self.allProducts.setProducts(products)
                        //self.viewModelForPin.setCurrentPin(products.first)
                        //products.first(where: { $0.isPinned })
                        self.currentPinProduct = products.first
                        print("CPK: HOST after setCurrentPin \(self.currentPinProduct?.name ?? "nil")")
                    }
                }
            } else {
                VStack {
                    Spacer().frame(height: 50)
                    //Button for trigger Product List
                    if productControlsVisible {
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation {
                                    isCustomerProductListVisible.toggle()
                                }
                            }) {
                                Image(systemName: "storefront")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        .padding([.top, .trailing], 8)
                    }
                    
                    Spacer()
                    
                    // Product List
                    if isCustomerProductListVisible {
                        CustomerProductListView(products: allProducts.products, playerState: $playerState, homeButtonAction: {
                            withAnimation(.spring()) {
                                isCustomerProductListVisible = false
                            }
                        }, cartViewModel: cartViewModel)
                        .offset(y: dragOffset > 0 ? dragOffset : 0) // Only drag downward
                        .gesture(
                            DragGesture()
                                .updating($isDragging) { _, state, _ in
                                    state = true
                                }
                                .onChanged { value in
                                    // Only allow downward dragging
                                    if value.translation.height > 0 {
                                        dragOffset = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 100 {
                                        // Custom action on drag down
                                        withAnimation(.spring()) {
                                            isCustomerProductListVisible = false
                                        }
                                    }
                                    dragOffset = 0
                                }
                        )
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(30)
                        .animation(.spring(), value: playerState)
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                        .ignoresSafeArea(edges: .bottom)
                    } else {
                        //Single Product
                        if let product = currentPinProduct,
                            appModel.isConnected {
                            VStack(spacing: 12) {
                                VerticalProductSwiftUIView(product: product,
                                                           showBottomSeparator: false,
                                                           isCompact: true)
                                VStack {
                                    Button("Add to Cart") {
                                        cartViewModel.addToCart(product)
                                    }.buttonStyle(CommerceButtonStyle(backgroundColor: .gray))
                                    Button("Buy Now") {
                                        isCustomerProductListVisible.toggle()
                                    }.buttonStyle(CommerceButtonStyle(backgroundColor: .orange))
                                }
                            }
                            .frame(width: UIScreen.main.bounds.width / 3)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .scaleEffect(0.5)
                            .position(x: appModel.pinProductPosition.x, y: appModel.pinProductPosition.y)
                            
                        }
                    }
                }.onAppear {
                    print("CPK: VIEWER onAppear - isHost: \(appModel.user.isHost), isConnected: \(appModel.isConnected)")
                    appModel.getProductListInLive(hostId: appModel.user.hostId) { products in
                        self.allCustomerProducts.setProducts(products)
                        self.currentPinProduct = products.first(where: { $0.isPinned })
                        print("CPK: VIEWER products fetched \(products.count)")
                        print("CPK: VIEWER after setCurrentPin \(self.currentPinProduct?.name ?? "nil")")
                    }
                    
                    appModel.webSocketManager.serverToClientTopicPinProduct(callback: { productId in
                        print("CPK: websocket to client pin product: \(productId)")
                        currentPinProduct = allCustomerProducts.products.first(where: { $0.id == productId })
                    })
                    
                    appModel.webSocketManager.serverToClientTopicUnpinAll {
                        currentPinProduct = nil
                    }
                }
            }
        }
        .frame(maxWidth: 889, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

struct OverlayHeaderView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        HStack {
            Button {
                // Clear selectedStage first if it exists
                if appModel.selectedStage != nil {
                    appModel.selectedStage = nil
                    appModel.isReadyToGoCustomerLanding = appModel.user.userRole == .customer
                    return
                }
                
                withAnimation {
                    appModel.isSetupCompleted.toggle()
                }

                if appModel.user.isOnStage {
                    appModel.endPublishingToStage {
                        appModel.leaveActiveStage {}
                    }
                } else {
                    appModel.leaveActiveStage {}
                }
                
                appModel.isReadyToGoCustomerLanding = appModel.user.userRole == .customer
            } label: {
                Image("arrow-small-left")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 150)
        .padding(.leading, 20)
        .padding(.top, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }
}
