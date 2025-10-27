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
            .padding()
        }
        .navigationTitle("Shop Landing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    appModel.isReadyToGoCustomerLanding = false
                    appModel.isSetupCompleted = false
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

//MARK: - Geometry Fallback for iOS 15–16 for ShopLivePreviewView

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]

    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

struct TrackOffset: ViewModifier {
    let index: Int

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: ViewOffsetKey.self,
                        value: [index: geo.frame(in: .global).minY]
                    )
                }
            )
    }
}

extension View {
    func trackOffset(index: Int) -> some View {
        self.modifier(TrackOffset(index: index))
    }
}

//MARK: - Multiple track offset
struct TrackOffsetModifier: ViewModifier {
    let index: Int
    @Binding var visibleIndices: Set<Int>
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            updateVisibility(in: geo)
                        }
                        .onChange(of: geo.frame(in: .global)) { _ in
                            updateVisibility(in: geo)
                        }
                        .onDisappear {
                            visibleIndices.remove(index)
                        }
                }
            )
    }
    
    private func updateVisibility(in geo: GeometryProxy) {
        let frame = geo.frame(in: .global)
        let screenHeight = UIScreen.main.bounds.height
        let isVisible = frame.maxY > 0 && frame.minY < screenHeight
        DispatchQueue.main.async {
            if isVisible {
                visibleIndices.insert(index)
            } else {
                visibleIndices.remove(index)
            }
        }
    }
}

extension View {
    func trackOffset(index: Int, visibleIndices: Binding<Set<Int>>) -> some View {
        self.modifier(TrackOffsetModifier(index: index, visibleIndices: visibleIndices))
    }
}

//MARK: - Shimmer and skeleton
extension View {
    func shimmering(active: Bool = true, duration: Double = 1.5) -> some View {
        self
            .overlay(
                ShimmerView()
                    .opacity(active ? 1 : 0)
            )
    }
}

struct ShimmerView: View {
    @State private var move = false

    var body: some View {
        GeometryReader { geo in
            LinearGradient(gradient: Gradient(colors: [Color.clear, Color.white.opacity(0.4), Color.clear]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .rotationEffect(.degrees(30))
                .offset(x: move ? geo.size.width : -geo.size.width)
                .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: move)
                .onAppear { move = true }
        }
        .clipped()
    }
}

//MARK: - ShopLivePreviewView
struct ShopLivePreviewView: View {
    @EnvironmentObject var appModel: AppModel
    @ObservedObject var stagesModel: StagesModel
    @ObservedObject var stageModel: StageModel
    @State private var isStagesListEmpty: Bool = false
    @State var timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    @State private var visibleIndex: Int = -1
    @State private var isLoading: Bool = true
    private let skeletonCount = 6
    
    //TODO: remove mock duplicate stages for test many stage
    var mockStages: [Stage] {
        var duplicated = appModel.stagesModel.logicalStages
//        duplicated += duplicated // Duplicate entire array
//        duplicated += duplicated
//        duplicated += duplicated
//        duplicated += duplicated
        return duplicated
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            if isLoading {
                ForEach(0..<skeletonCount, id: \.self) { _ in
                    skeletonCell
                }
            } else {
                ForEach(Array(appModel.stagesModel.logicalStages.enumerated()), id: \.offset) { index, stage in
//                ForEach(Array(mockStages.enumerated()), id: \.offset) { index, stage in
                    if stage.type == .video {
                        ShopPreviewCell(
                            stage: stage,
                            isEnableVideoPreview: visibleIndex == index
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: ViewOffsetKey.self,
                                        value: [index: geo.frame(in: .global).minY]
                                    )
                            }
                        )
                        .environmentObject(appModel)
                        //.shadow(color: visibleIndex == index ? .green : .red, radius: 8)
                        .trackOffset(index: index)
                        .onTapGesture {
                            appModel.isReadyToGoCustomerLanding = false
                            appModel.selectedStage = stage
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            _ = timer.upstream.autoconnect()
            fetchData()
        }
        .onDisappear {
            timer.upstream.connect().cancel()
        }
        .onReceive(timer) { _ in
            fetchData()
        }
        .onPreferenceChange(ViewOffsetKey.self) { offsets in
            if let closest = offsets.min(by: { abs($0.value) < abs($1.value) }) {
                visibleIndex = closest.key
            }
        }
    }
    
    private func fetchData() {
        appModel.getStages { isSuccess in
            print("CPK: Fetched stages: \(isSuccess), count: \(appModel.stagesModel.logicalStages.count)")
            if isSuccess {
                withAnimation {
                    isLoading = false
                }
            }
        }
    }
    
    private var skeletonCell: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(9/16, contentMode: .fit)
            .cornerRadius(8)
            .shimmering()
    }
}

struct ShopPreviewCell: View {
    @EnvironmentObject var appModel: AppModel
    @ObservedObject var stage: Stage
    @State private var previewImageUrl: String? = nil
    @State private var previewVideoUrl: String? = nil
    @State private var isVideoReady: Bool = false
    @State private var preLoadViewEnable: Bool = true
    var isEnableVideoPreview: Bool = false

    var body: some View {
        ZStack {
           Rectangle()
               .border(Color.green, width: 1)
               .background(Color.clear)
               .aspectRatio(9/16, contentMode: .fit)
               .cornerRadius(8)
               .overlay(Text(stage.hostId).foregroundColor(.white))
            if let imgURL = previewImageUrl.flatMap(URL.init) {
                WebImage(url: imgURL)
                    .resizable()
                    .aspectRatio(9/16, contentMode: .fit)
                    .cornerRadius(8)
                    .opacity((isEnableVideoPreview && isVideoReady) ? 0 : 1)
                    .animation(.easeInOut(duration: 0.3), value: isVideoReady)
            } else if isEnableVideoPreview, let videoURL = previewVideoUrl.flatMap(URL.init) {
                VideoPreview(url: videoURL, isMuted: true, isReady: $isVideoReady)
                    .aspectRatio(9/16, contentMode: .fit)
                    .cornerRadius(8)
                    .clipped()
                    .opacity(isVideoReady ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isVideoReady)
            }
        }
        .onAppear {
            if let imgUrl = stage.imagePreviewUrl?.components(separatedBy: "?").first {
                previewImageUrl = imgUrl
            }
            if let videoUrl = stage.videoPreviewUrl?.components(separatedBy: "?").first {
                previewVideoUrl = videoUrl
            }
        }
    }
}
