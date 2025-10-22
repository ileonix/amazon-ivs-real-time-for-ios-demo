//
//  WelcomeView.swift
//  IVS Real-time
//
//  Created by Uldis Zingis on 28/03/2023.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appModel: AppModel
    @State var isCodeInputPresent = false
    @State var isRoleSelectionPresent = false
    @State var customerCodeInput: String = ""
    @State var selectedRole: UserRole = .customer

    private func setCustomerCodeAndApiKey() {
        print("ℹ scanned qr '\(customerCodeInput)'")
        let codeParts = customerCodeInput.split(separator: "-")
        var customerCode: String?
        var apiKey: String?
        if codeParts.count == 2 {
            customerCode = codeParts.first.map { String($0) }
            apiKey = codeParts.last.map { String($0) }
        } else {
            appModel.appendErrorMessage("Invalid code")
            return
        }

        guard let customerCode = customerCode, let apiKey = apiKey else { return }
        print("ℹ Entered customer code: '\(customerCode)', api key: '\(apiKey)'")

        UserDefaults.standard.set(customerCode.lowercased(), forKey: Constants.kCustomerCode)
        UserDefaults.standard.set(apiKey, forKey: Constants.kApiKey)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(decorative: "APP_BG")
                .resizable()
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading) {
                Text("Welcome to")
                    .font(Constants.fInterBlack42)
                    .foregroundColor(.black)
                Text("BBTV Live Shopping") //IVS Real-time
                    .font(Constants.fInterBlack42)
                    .foregroundColor(.black)
                    .padding(.bottom, 60)

                Button(action: {
                    withAnimation {
                        //isCodeInputPresent = true
                        isRoleSelectionPresent = true
                    }
                }) {
                    Text("Get started")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .modifier(PrimaryButton(color: .white, font: Constants.fInterExtraBold18))
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
            
            if isRoleSelectionPresent {
                RoleSelectionView(
                    showBottomSheet: $isRoleSelectionPresent,
                    selectedRole: $selectedRole,
                    submitAction: {
                        /*
                         CloudFormation stacks
                         IVS-Realtime-Chat-Shop-2
                         - ddqs04nk76rcv.cloudfront.net
                         - gtc2T2d4mlkY9O6UnDJC
                         IVS-Realtime-Chat-Shop
                         let customerCode = "d2xcfozmvpjoaq"
                         let apiKey = "8bLC1rUNEaVF8qyz2XbG"
                         ddqs04nk76rcv-gtc2T2d4mlkY9O6UnDJC
                         */
                        let customerCode = "ddqs04nk76rcv"
                        let apiKey = "gtc2T2d4mlkY9O6UnDJC"
                        UserDefaults.standard.set(customerCode.lowercased(), forKey: Constants.kCustomerCode)
                        UserDefaults.standard.set(apiKey, forKey: Constants.kApiKey)
                        appModel.userRole = selectedRole
                        UserDefaults.standard.set(selectedRole.rawValue, forKey: Constants.kUserRole)
                        appModel.verify { _ in }
                    }
                )
            }
            
            /*
            if isCodeInputPresent {
                CustomerCodeInputView(
                    isPresent: $isCodeInputPresent,
                    inputText: $customerCodeInput,
                    submitAction: {
                        if customerCodeInput.isEmpty {
                            appModel.appendErrorMessage("Invalid code")
                            return
                        }

                        setCustomerCodeAndApiKey()

                        appModel.verify { _ in }
                    }
                )
                .onTapGesture {
                    withAnimation {
                        isCodeInputPresent.toggle()
                    }
                }
            }
             */
        }
        .onAppear {
            if let customerCode = UserDefaults.standard.string(forKey: Constants.kCustomerCode),
               let apiKey = UserDefaults.standard.string(forKey: Constants.kApiKey),
               let userRole = UserDefaults.standard.string(forKey: Constants.kUserRole){
                customerCodeInput = customerCode + "-" + apiKey
                appModel.userRole = .init(rawValue: userRole)
            }

            withAnimation(.easeOut.delay(0.3)) {
                isCodeInputPresent = appModel.wasConnected
            }
        }
    }
}
