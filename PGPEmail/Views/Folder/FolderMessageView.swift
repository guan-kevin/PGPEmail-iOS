//
//  FolderMessageView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/10/21.
//

import SwiftUI

struct FolderMessageView: View {
    let message: Message
    let folder: String
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let color = getBadgeColor() {
                Circle()
                    .foregroundColor(color)
                    .frame(width: 10, height: 10)
                    .offset(x: -15)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading) {
                HStack {
                    let name = message.from.name
                    Text(name == "" ? message.from.email : name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer(minLength: 20)

                    Text(EmailDateFormatter().string(for: message.sendDate) ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Text(message.subject + "\n")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .foregroundColor(.gray)
            }
        }
    }

    func getBadgeColor() -> Color? {
        // blue = not read
        if message.flags == 0 {
            return .blue
        }

        // orange = flag
        if (message.flags & MCOMessageFlag.flagged.rawValue) != 0 {
            return .orange
        }

        // red = deleted
        if (message.flags & MCOMessageFlag.deleted.rawValue) != 0 {
            return .red
        }

        return nil
    }
}
