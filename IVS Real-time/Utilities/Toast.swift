import SwiftUI

struct Toast<Presenting>: View where Presenting: View {
    @Binding var isShowing: Bool
    let presenting: () -> Presenting
    let text: String

    var body: some View {
        ZStack(alignment: .bottom) {
            presenting()
            if isShowing {
                Text(text)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom))
                    .animation(.easeInOut, value: isShowing)
            }
        }
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, text: String) -> some View {
        Toast(isShowing: isShowing, presenting: { self }, text: text)
    }
}