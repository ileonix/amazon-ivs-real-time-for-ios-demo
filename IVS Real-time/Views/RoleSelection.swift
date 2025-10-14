//
//  RoleSelection.swift
//  IVS Real-time
//
//  Created by Chanon Purananunak on 10/10/2568 BE.
//
import SwiftUI

enum UserRole: String {
    case customer = "Customer"
    case merchant = "Merchant"
}

struct RoleSelectionView: View {
    @Binding var showBottomSheet: Bool
    @Binding var selectedRole: UserRole
    var submitAction: () -> Void

    var body: some View {
        ZStack {
//            VStack(spacing: 20) {
//                Button("Choose Role") {
//                    withAnimation {
//                        showBottomSheet.toggle()
//                    }
//                }
//                .font(.title)
//                .padding()
//                .foregroundColor(.white)
//                .background(Color.orange)
//                .cornerRadius(10)
//
//                Text("Selected Role: \(selectedRole.rawValue)")
//                    .font(.headline)
//                    .padding()
//            }

            // Fallback for iOS 15 – custom bottom sheet
            if showBottomSheet, !isAtLeastIOS16() {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showBottomSheet = false
                        }
                    }

                BottomSheetView {
                    RoleBottomSheetContent(
                        selectedRole: $selectedRole,
                        isPresented: $showBottomSheet,
                        submitAction: {
                            submitAction()
                        }
                    )
                }
                .transition(.move(edge: .bottom))
            }
        }
        // Native iOS 16+ sheet
        .sheet(isPresented: $showBottomSheet) {
            if #available(iOS 16.0, *) {
                RoleBottomSheetContent(
                    selectedRole: $selectedRole,
                    isPresented: $showBottomSheet,
                    submitAction: {
                        submitAction()
                    })
                    .presentationDetents([.height(250)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // Helper function to check system version
    func isAtLeastIOS16() -> Bool {
        if #available(iOS 16, *) {
            return true
        } else {
            return false
        }
    }
}
struct BottomSheetView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack {
            Spacer()
            VStack {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)

                content
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .frame(maxHeight: 300)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct RoleBottomSheetContent: View {
    @Binding var selectedRole: UserRole
    @Binding var isPresented: Bool
    var submitAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Please select")
                .font(.headline)
                .padding(.top)

            Button(action: {
                selectedRole = .customer
                isPresented = false
                submitAction()
            }) {
                Text("Customer")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding([.leading, .trailing], 16)

            Button(action: {
                selectedRole = .merchant
                isPresented = false
                submitAction()
            }) {
                Text("Merchant")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding([.leading, .trailing], 16)

            Spacer()
        }
    }
}

