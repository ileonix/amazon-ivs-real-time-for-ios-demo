//
//  CustomerShopLanding.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 10/10/2568 BE.
//

import SwiftUI
import SDWebImageSwiftUI
import UIKit

struct BannerItem {
    let imgUrl: String
}

// Small cell view that prefers a locally cached preview image for a stage.
struct ShopPreviewCell: View {
    @ObservedObject var stage: Stage
    @State private var previewImage: UIImage? = nil

    var body: some View {
        VStack {
            Group {
                if let uiImage = previewImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(9/16, contentMode: .fit)
                        .cornerRadius(8, corners: .allCorners)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.black)
                        .cornerRadius(8, corners: .allCorners)
                        .aspectRatio(9/16, contentMode: .fit)
                        .overlay(
                            Text(stage.hostId)
                                .foregroundColor(.white)
                                .font(.caption)
                                .bold()
                        )
                }
            }
            .onAppear {
                // Try memory cache first
                if let img = LocalPreviewCache.shared.image(for: stage.hostId) {
                    previewImage = img
                    return
                }

                // Otherwise try loading from disk asynchronously
                LocalPreviewCache.shared.load(for: stage.hostId) { img in
                    if let img = img {
                        previewImage = img
                    }
                }
            }
            .contextMenu {
                Button(action: {
                    LocalPreviewCache.shared.generateTestPreview(for: stage.hostId)
                    // Immediately set previewImage from memory
                    if let img = LocalPreviewCache.shared.image(for: stage.hostId) {
                        previewImage = img
                    }
                }) {
                    Text("Generate test preview")
                }
            }
        }
    }
}

struct BrandAvatar {
    let name: String
    let imgUrl: String
}

struct CustomerShopLanding: View {
    @EnvironmentObject var appModel: AppModel
    @ObservedObject var stagesModel: StagesModel
    @ObservedObject var stageModel: StageModel
    @State private var isStagesListEmpty: Bool = false
    
    @State private var currentBannerIndex = 0
    @State private var bannerTimer: Timer?
    
    let avatars: [BrandAvatar] = [
        .init(name: "Apple", imgUrl: "https://down-zl-th.img.susercontent.com/th-11134216-7quky-ljf59eurynwx9a_tn"),
        .init(name: "Samsung", imgUrl: "https://down-zl-th.img.susercontent.com/th-11134216-7rasm-m0infg7jcdzs27_tn"),
        .init(name: "B2S", imgUrl: "https://down-zl-th.img.susercontent.com/e03dcf32f09f422153728e3be3bfc3d3_tn"),
        .init(name: "Giordano", imgUrl: "https://down-bs-th.img.susercontent.com/2b8f15818fa8e7c6f71596756a059de8_tn"),
        .init(name: "Power Buy", imgUrl: "https://down-bs-th.img.susercontent.com/510ac9e549ab30cf152b51132a97be26_tn"),
        .init(name: "GQ", imgUrl: "https://down-zl-th.img.susercontent.com/th-11134216-7r98w-lydc022ughbde7_tn"),
        .init(name: "Microsoft", imgUrl: "https://down-zl-th.img.susercontent.com/02544499961fe50b1a84378405322ac3_tn"),
        .init(name: "Mi", imgUrl: "https://down-zl-th.img.susercontent.com/th-11134216-81ztq-mdwt2s91n0n701_tn")
    ]
    let banners: [BannerItem] = [
        .init(imgUrl: "https://down-th.img.susercontent.com/file/th-11134258-81zti-mfksxkpz22h9e3@resize_w796_nl.webp"),
        .init(imgUrl: "https://down-th.img.susercontent.com/file/th-11134258-81zth-mfktga88sefj61@resize_w1594_nl.webp"),
        .init(imgUrl: "https://down-th.img.susercontent.com/file/th-11134258-81zth-mfktv9n1d53df5@resize_w1594_nl.webp"),
        .init(imgUrl: "https://down-th.img.susercontent.com/file/th-11134258-81zti-mfksxkpz22h9e3@resize_w796_nl.webp"),
        .init(imgUrl: "https://down-th.img.susercontent.com/file/th-11134258-81zth-mfktga88sefj61@resize_w1594_nl.webp"),
        .init(imgUrl: "https://down-th.img.susercontent.com/file/th-11134258-81zth-mfktv9n1d53df5@resize_w1594_nl.webp")
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ShopAvatarView(avatars: avatars)
                PromotionBannerSectionView(banners: banners, currentIndex: $currentBannerIndex)
                ShopLivePreviewView(stagesModel: stagesModel, stageModel: stageModel)
                    .environmentObject(appModel)
                    .task {
                        isStagesListEmpty = stagesModel.logicalStages.isEmpty
                    }
            }
        }
        .onAppear {
            startBannerTimer()
        }
        .onDisappear {
            bannerTimer?.invalidate()
        }
    }
    
    // Start banner timer
    private func startBannerTimer() {
        bannerTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            withAnimation {
                currentBannerIndex = (currentBannerIndex + 1) % banners.count
            }
        }
    }
}

struct ShopAvatarView: View {
    let avatars: [BrandAvatar]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<avatars.count, id: \.self) { index in
                    VStack(spacing: 2) {
                        WebImage(url: URL(string: avatars[index].imgUrl))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                            //.overlay(Circle().stroke(.black, lineWidth: 1))
                            .shadow(radius: 1)
                            .overlay(
                                Text("LIVE")
                                    .foregroundColor(.white)
                                    .font(.system(size: 8))
                                    .padding(1.5)
                                    .background(.red)
                                    .offset(x: 0, y: 30)
                            )
                            .padding(.top, 2)
                            .onTapGesture {
                                
                            }
                        Text(avatars[index].name)
                            .bold()
                            .lineLimit(1)
                            .foregroundColor(.black)
                            .font(.system(size: 12))
                            .padding(1)
                    }
                    
                }
            }
            .padding(.horizontal)
        }
    }
}

struct PromotionBannerSectionView: View {
    let banners: [BannerItem]//[String]
    @Binding var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentIndex) {
                ForEach(0..<banners.count, id: \.self) { index in
                    WebImage(url: URL(string: banners[index].imgUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width - 24)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(16)
                        .overlay(
                            Text("Banner \(index + 1)")
                                .foregroundColor(.green)
                                .font(.title)
                                .bold()
                        )
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .menuIndicator(.hidden) //hide and use outside view custom indicator
            .frame(width: UIScreen.main.bounds.width - 16)
            .aspectRatio(16/9, contentMode: .fit)
            
//            HStack {
//                ForEach(0..<banners.count, id: \.self) { index in
//                    Circle()
//                        .fill(index == currentIndex ? Color.orange : Color.gray)
//                        .frame(width: 8, height: 8)
//                }
//            }
//            .padding(.top, 2)
        }
        .frame(width: UIScreen.main.bounds.width - 16)
        .padding(.horizontal)
    }
}

struct OldPromotionBannerSectionView: View {
    let banners: [BannerItem]
    @Binding var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    var body: some View {
        ZStack {
            ForEach(0..<banners.count, id: \.self) { index in
                if index == currentIndex {
                    WebImage(url: URL(string: banners[index].imgUrl))
                        .resizable()
                        .scaledToFit()
                        .frame(width: UIScreen.main.bounds.width - 16)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(16)
                        .overlay(
                            Text("Banner \(index + 1)")
                                .foregroundColor(.red)
                                .font(.title)
                                .bold()
                        )
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: currentIndex)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width  // Track the horizontal drag offset
                }
                .onEnded { value in
                    // Determine if the drag was large enough to change the index
                    if dragOffset > 100 {
                        // Dragged to the right
                        currentIndex = max(currentIndex - 1, 0)
                    } else if dragOffset < -100 {
                        // Dragged to the left
                        currentIndex = min(currentIndex + 1, banners.count - 1)
                    }
                    dragOffset = 0  // Reset the drag offset
                }
        )
        
        HStack {
            ForEach(0..<banners.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.orange : Color.gray)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 8)
    }
}

struct ShopLivePreviewView: View {
    @EnvironmentObject var appModel: AppModel
    @ObservedObject var stagesModel: StagesModel
    @ObservedObject var stageModel: StageModel
    @State private var isStagesListEmpty: Bool = false
    @State var timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    //let items: [String] = Array(repeating: "Channel", count: 10)
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(appModel.stagesModel.logicalStages, id: \.self) { stage in
                if stage.type == .video {
                    ShopPreviewCell(stage: stage)
                        .onTapGesture {
                            appModel.isSetupCompleted = true
                        }
                }
            }
        }
        .padding()
        .onAppear {
            _ = timer.upstream.autoconnect()
        }
        .onDisappear {
            timer.upstream.connect().cancel()
        }
            .onReceive(timer) { _ in
                appModel.getStages { isSuccess in
                    print("CPK: Stages fetched success \(isSuccess)  count:\(appModel.stagesModel.logicalStages.count)")
                }
            }
    }
}
