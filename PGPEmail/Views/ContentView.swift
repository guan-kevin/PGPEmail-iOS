//
//  ContentView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/9/21.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var model: PGPEmailViewModel

    var body: some View {
        NavigationView {
            if model.isSetupCompleted {
                FolderView(folder: "INBOX")
                Text("Select a Conversation to Read")
            } else {
                AccountSetupView()
                Text("Please Setup Your Account First")
            }
        }
    }
}
