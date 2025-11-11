//
//  AvatarView.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 31/03/2023.
//

import SwiftUI

struct AvatarView: View {
    @EnvironmentObject var appModel: AppModel
    var avatar: Avatar?
    var withBorder: Bool = false
    var borderColor: Color = .white
    var size: CGFloat = 42
    var profileImage: String?

    var body: some View {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(uiColor: avatar?.bottomColor ?? .white)
                        .opacity(avatar == nil ? 0.4 : 1)
                    )
                    .frame(width: size, height: size)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(uiColor: avatar?.rightColor ?? .white)
                            .opacity(avatar == nil ? 0.4 : 1)
                        )
                        .frame(width: size/2, height: size/2)
                    Rectangle()
                        .fill(Color(uiColor: avatar?.leftColor ?? .white)
                            .opacity(avatar == nil ? 0.4 : 1)
                        )
                        .frame(width: size/2, height: size/2)
                }
                .offset(y: avatar == nil ? 0 : -size/4)
            }
            .rotationEffect(Angle(degrees: 180))
            .frame(width: size, height: size)
            .clipShape(Circle())
            .transition(.opacity)
            .overlay {
                if avatar == nil {
                    Image("no_avatar")
                        .resizable()
                        .frame(width: size, height: size)
                } else {
                    if let profileImage = profileImage {
                        Image(profileImage)
                            .resizable()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    }
                }

                if withBorder {
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(borderColor, lineWidth: 2)
                }
            }
    }
}

#Preview("With avatar") {
    ZStack {
        Rectangle()
            .fill(.gray)
        AvatarView(avatar: Avatar(colLeft: "#FFF001",
                                  colRight: "#01F0F1",
                                  colBottom: "#FF1102"),
                   withBorder: true,
                   borderColor: .white,
                   size: 60)
    }
}

#Preview("No avatar") {
    ZStack {
        Rectangle()
            .fill(.gray)
        AvatarView(avatar: nil,
                   withBorder: true,
                   borderColor: .white,
                   size: 60)
    }
}
