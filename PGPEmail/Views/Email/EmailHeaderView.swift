//
//  EmailHeaderView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/11/21.
//

import SwiftUI

struct EmailHeaderView: View {
    let message: Message
    @ObservedObject var viewModel: EmailViewModel
    @Binding var showFullHeader: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(message.subject)
                    .font(.headline)
                Spacer()

                EmailHeaderBadgetView(flag: message.flags, encrypted: viewModel.content?.encrypted)
            }
            .contentShape(Rectangle())
            .padding(5)
            .onTapGesture {
                withAnimation {
                    showFullHeader = true
                }
            }

            if showFullHeader {
                HStack {
                    Group {
                        Circle()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                            .overlay(
                                Text(String(message.from.name.first ?? "?"))
                                    .foregroundColor(.white)
                            )
                            .padding(.leading, 5)
                    }

                    VStack(alignment: .leading) {
                        Text(message.from.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text("To: \(message.to.first?.email ?? "You")")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(EmailDateFormatter().string(for: message.sendDate) ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(5)
                }
                .padding(.bottom, 5)
            }
        }
        .background(Color(UIColor.secondarySystemBackground).cornerRadius(5))
    }
}
