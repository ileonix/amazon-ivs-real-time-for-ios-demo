//
//  StageOverlayView.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI

class ProductListViewModel: NSObject, ObservableObject {
    @Published var currentProduct: Product?
    @Published var receivedProductsLine: [Product] = []

    var products: [Product] = []
    private let jsonDecoder = JSONDecoder()
    private var productTimer: Timer?
    @Published var productTimeLeft: Int = 0
    
    func showNextProduct() {
//        guard !receivedProductsLine.isEmpty else {
//            currentProduct = nil
//            productTimer?.invalidate()
//            return
//        }
        let nextProduct = products.randomElement()//receivedProductsLine.removeFirst()
        currentProduct = nextProduct
        startProductCountdown()
    }

    private func startProductCountdown() {
        productTimer?.invalidate()
        productTimeLeft = 10
        productTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.productTimeLeft > 0 {
                self.productTimeLeft -= 1
            } else {
                self.productTimer?.invalidate()
                self.showNextProduct()
            }
        }
    }
}

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
    @StateObject private var productsViewModel = ProductsViewModel()
    @StateObject private var cartViewModel = CartViewModel()
    @State private var isProductListVisible: Bool = false
    // State for draggable product list
    @State private var productListOffset: CGFloat = 0
    @State private var productListDragOffset: CGFloat = 0
    private let collapsedSize = CGSize(width: 120, height: 200)
    
    //Single product
    @ObservedObject var viewModelForPick: ProductListViewModel = ProductListViewModel()
    @State private var productControlsVisible = true
    @State private var productDragOffset: CGSize = .zero
    @State private var productPosition: CGPoint = CGPoint(x: 100, y: 150) // Default top-left-ish
    
    //ProductList drag control
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            if stage.type == .video {
                MultiTapView {
                    withAnimation {
                        overlayHidden.toggle()
                    }
                }
            }

            VStack {
                OverlayHeaderView()
                    .opacity(overlayHidden ? 0 : 1)
                Spacer()
                StageButtonsOverlayView(stage: stage)
                    .opacity(overlayHidden ? 0 : 1)
            }
            
            if appModel.user.isHost {
                //Single Product
                if let product = viewModelForPick.currentProduct ?? productsViewModel.products.randomElement(),
                    appModel.isConnected {
                    VStack(spacing: 12) {
                        VerticalProductSwiftUIView(product: product,
                                                   showBottomSeparator: false,
                                                   isCompact: true)
                        VStack {
                            Button("Add to Cart") {
                                cartViewModel.addToCart(product)
                            }
                                .buttonStyle(CommerceButtonStyle(backgroundColor: .gray))
                            Button("Buy Now") {
                                isProductListVisible.toggle()
                            }.buttonStyle(CommerceButtonStyle(backgroundColor: .orange))
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
                            }
                            .onEnded { value in
                                productPosition.x += value.translation.width
                                productPosition.y += value.translation.height
                                productDragOffset = .zero
                                appModel.chatModel?.hostUpdatePinProductPosition(position: productPosition)
                            }
                    )
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
                                    isProductListVisible.toggle()
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
                    if isProductListVisible {
                        ProductListView(products: productsViewModel.products, playerState: $playerState, homeButtonAction: {
                            withAnimation(.spring()) {
                                isProductListVisible = false
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
                                            isProductListVisible = false
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
                        if let product = viewModelForPick.currentProduct ?? productsViewModel.products.randomElement(),
                            appModel.isConnected {
                            VStack(spacing: 12) {
                                VerticalProductSwiftUIView(product: product,
                                                           showBottomSeparator: false,
                                                           isCompact: true)
                                VStack {
                                    Button("Add to Cart") {
                                        cartViewModel.addToCart(product)
                                    }
                                        .buttonStyle(CommerceButtonStyle(backgroundColor: .gray))
                                    Button("Buy Now") {
                                        isProductListVisible.toggle()
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
                    viewModelForPick.products = productsViewModel.products
                    viewModelForPick.showNextProduct()
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
