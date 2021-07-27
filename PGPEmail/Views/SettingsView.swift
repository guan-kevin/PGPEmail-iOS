//
//  SettingsView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/16/21.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: PGPEmailViewModel
    @Environment(\.presentationMode) var presentationMode
    @State var privateKey = ""
    @State var keyPassword = ""
    @State var error = false
    @State var errorReason = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("PGP Private Key:")
                    .padding(10)
                Spacer()
            }

            TextEditor(text: $privateKey)
                .padding(5)

            Divider()

            HStack {
                Text("Password:")
                    .padding(.horizontal, 10)
                Spacer()
            }
            
            SecureField("Password", text: $keyPassword)
                .padding()

            Button(action: {
                if privateKey == "" {
                    self.errorReason = "Private key is EMPTY"
                    self.error = true
                    return
                }
                do {
                    try KeychainManager.getValet().setString(privateKey, forKey: "privateKey")
                    if keyPassword != "" {
                        try KeychainManager.getValet().setString(keyPassword, forKey: "keyPassword")
                    }
                    if PGPManager.isKeyValid(checkAgain: true) {
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        self.errorReason = "Unable to read your PGP key"
                        self.error = true
                    }
                } catch {
                    self.errorReason = error.localizedDescription
                    self.error = true
                }
            }) {
                HStack {
                    Spacer()
                    Text("Save")
                        .padding(13)
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            .background(Color.blue)
            .cornerRadius(8)
            .padding(.horizontal, 15)
            .padding(.vertical, 5)

            Button(action: {
                KeychainManager.deleteAll()
                presentationMode.wrappedValue.dismiss()
                self.model.isSetupCompleted = false
            }) {
                HStack {
                    Spacer()
                    Text("Logout")
                        .padding(13)
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            .background(Color.red)
            .cornerRadius(8)
            .padding(.horizontal, 15)
        }
        .alert(isPresented: $error, content: {
            Alert(title: Text("Error"), message: Text(errorReason), dismissButton: .cancel())
        })
        .onAppear {
            privateKey = KeychainManager.getString(forKey: "privateKey") ?? ""
            keyPassword = KeychainManager.getString(forKey: "keyPassword") ?? ""
        }
    }
}
