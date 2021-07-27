//
//  AccountSetupView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/10/21.
//

import SwiftUI

struct AccountSetupView: View {
    @EnvironmentObject var model: PGPEmailViewModel
    
    @State var imapServer = ""
    @State var smtpServer = ""
    
    @State var imapPort = "993"
    @State var smtpPort = "587"
    
    @State var imapAccount = ""
    @State var smtpAccount = ""
    
    @State var imapPassword = ""
    @State var smtpPassword = ""
    
    @State var errorType = LoginError.noError
    @State var showError = false
    
    var body: some View {
        Form {
            Section(header: Text("IMAP")) {
                TextField("IMAP Server", text: $imapServer)
                    .keyboardType(.URL)
                TextField("IMAP Port", text: $imapPort)
                    .keyboardType(.numberPad)
                TextField("IMAP Username", text: $imapAccount)
                    .keyboardType(.emailAddress)
                SecureField("IMAP Password", text: $imapPassword)
                    .keyboardType(.default)
            }
                
            Section(header: Text("SMTP")) {
                TextField("SMTP Server", text: $smtpServer)
                    .keyboardType(.URL)
                TextField("SMTP Port", text: $smtpPort)
                    .keyboardType(.numberPad)
                TextField("SMTP Username", text: $smtpAccount)
                    .keyboardType(.emailAddress)
                SecureField("SMTP Password", text: $smtpPassword)
                    .keyboardType(.default)
            }
                
            Button(action: {
                if imapServer == "" || smtpServer == "" || Int(imapPort) ?? 0 <= 0 || Int(smtpPort) ?? 0 <= 0 || imapAccount == "" || smtpAccount == "" || imapPassword == "" || smtpPassword == "" {
                    errorType = .invalidInput
                    showError = true
                    return
                }
                    
                do {
                    try KeychainManager.getValet().setString(imapServer, forKey: "imapServer")
                    try KeychainManager.getValet().setString(smtpServer, forKey: "smtpServer")
                    try KeychainManager.getValet().setString(imapPort, forKey: "imapPort")
                    try KeychainManager.getValet().setString(smtpPort, forKey: "smtpPort")
                    try KeychainManager.getValet().setString(imapAccount, forKey: "imapAccount")
                    try KeychainManager.getValet().setString(smtpAccount, forKey: "smtpAccount")
                    try KeychainManager.getValet().setString(imapPassword, forKey: "imapPassword")
                    try KeychainManager.getValet().setString(smtpPassword, forKey: "smtpPassword")
                } catch {
                    errorType = .unknown
                    showError = true
                }
                    
                MailCoreManager.shared.checkAccount(mailbox: smtpAccount) { error in
                    if error == .noError {
                        try? KeychainManager.getValet().setString("true", forKey: "enable")
                        self.model.isSetupCompleted = true
                    } else {
                        errorType = error
                        showError = true
                    }
                }
                    
            }) {
                Text("Login")
            }
        }
        .navigationBarTitle("Account Setup", displayMode: .inline)
        .alert(isPresented: self.$showError, content: {
            switch errorType {
            case .noError:
                return Alert(title: Text("Error"), message: Text("Error because there is no error but some how showError is true"))
            case .invalidInput:
                return Alert(title: Text("Error"), message: Text("Invalid inputs"))
            case .invalidIMAP:
                return Alert(title: Text("Error"), message: Text("IMAP infomation is incorrect"))
            case .invalidSMTP:
                return Alert(title: Text("Error"), message: Text("SMTP infomation is incorrect"))
            case .invalidBoth:
                return Alert(title: Text("Error"), message: Text("Both IMAP and SMTP infomation are incorrect"))
            case .unknown:
                return Alert(title: Text("Error"), message: Text("IDK what happened, maybe try again later?"))
            }
        })
    }
}

enum LoginError: Error {
    case noError
    case unknown
    case invalidInput
    case invalidIMAP
    case invalidSMTP
    case invalidBoth
}
