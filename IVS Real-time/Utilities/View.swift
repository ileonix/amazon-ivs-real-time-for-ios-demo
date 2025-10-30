//
//  View.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI
import Combine

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

            ZStack(alignment: alignment) {
                self
                placeholder()
                    .font(Constants.fInterSemiBold16)
                    .opacity(shouldShow ? 1 : 0)
                    .allowsHitTesting(false)
                    .frame(alignment: alignment)
                    .padding(.leading, 15)
            }
        }

    func onFirstAppear(_ action: @escaping () -> Void) -> some View {
        modifier(FirstAppear(action: action))
    }

    func keyboardAwarePadding() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAwareModifier())
    }

    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    @inlinable
    public func reverseMask<Mask: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: alignment) {
                    mask().blendMode(.destinationOut)
                }
        }
    }

    func cutout<S: Shape>(_ shape: S) -> some View {
        self.clipShape(CutoutShape(bottom: Rectangle(), top: shape), style: FillStyle(eoFill: true))
    }
}

struct CutoutShape<Bottom: Shape, Top: Shape>: Shape {
    var bottom: Bottom
    var top: Top

    func path(in rect: CGRect) -> Path {
        return Path { path in
            path.addPath(bottom.path(in: rect))
            path.addPath(top.path(in: rect))
        }
    }
}

private struct FirstAppear: ViewModifier {
    let action: () -> Void

    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content.onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            action()
        }
    }
}

struct KeyboardAwareModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    private var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        Publishers.Merge(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification)
                .compactMap { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect }
                .map { $0.height },
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillHideNotification)
                .map { _ in CGFloat(0) }
        )
        .eraseToAnyPublisher()
    }

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onReceive(keyboardHeightPublisher) { height in
                withAnimation(.easeInOut(duration: 0.3)) {
                    if height > 0 {
                            let safeAreaBottom = UIApplication.shared.connectedScenes
                                .compactMap { $0 as? UIWindowScene }
                                .first?.windows.first?.safeAreaInsets.bottom ?? 34
                        self.keyboardHeight = adjustedResult(height: height, safeAreaBottom: safeAreaBottom)
                    } else {
                        self.keyboardHeight = 0
                    }
                }
            }
    }
    
    /*
     Case    height    safeAreaBottom    screenHeight    extraOffset    result (height - safeAreaBottom - extraOffset)
     1    336    34    812    -16    286
     2    336    34    874    16    318
     3    320    0    1112    -120    200
     */
    func extraOffsetCubic(screenHeight h: CGFloat) -> CGFloat {
        if h <= 812 {
            // extrapolate with slope of first segment
            return -16 + 0.516 * (h - 812)
        } else if h <= 874 {
            let t = (h - 812) / (874 - 812)
            let y0: CGFloat = -16
            let y1: CGFloat = 16
            let m0: CGFloat = 0.516 * (874 - 812)
            let m1: CGFloat = 0.516 * (874 - 812)
            let t2 = t*t
            let t3 = t2*t
            return (2*t3 - 3*t2 + 1)*y0 + (t3 - 2*t2 + t)*m0 + (-2*t3 + 3*t2)*y1 + (t3 - t2)*m1
        } else if h <= 1112 {
            let t = (h - 874) / (1112 - 874)
            let y0: CGFloat = 16
            let y1: CGFloat = -145.954
            let m0: CGFloat = -0.571 * (1112 - 874)
            let m1: CGFloat = -0.571 * (1112 - 874)
            let t2 = t*t
            let t3 = t2*t
            return (2*t3 - 3*t2 + 1)*y0 + (t3 - 2*t2 + t)*m0 + (-2*t3 + 3*t2)*y1 + (t3 - t2)*m1
        } else {
            // extrapolate with slope of last segment
            return -145.954 - 0.571 * (h - 1112)
        }
    }

    func adjustedResult(height: CGFloat, safeAreaBottom: CGFloat) -> CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let offset = extraOffsetCubic(screenHeight: screenHeight)
        let result = height - safeAreaBottom + offset
        print("CCPP: screenH:\(screenHeight) height:\(height) - safeAreaBootm:\(safeAreaBottom) offset:\(offset) result\(result)")
        return result
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
