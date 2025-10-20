//
//  CommerceButtonStyle.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 20/10/2568 BE.
//
import SwiftUI

struct CommerceButtonStyle: ButtonStyle {
    var backgroundColor: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
