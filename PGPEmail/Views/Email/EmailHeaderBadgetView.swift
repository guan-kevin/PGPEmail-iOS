//
//  EmailHeaderBadgetView.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/12/21.
//

import SwiftUI

struct EmailHeaderBadgetView: View {
    var flag: Int
    var encrypted: Bool?

    var body: some View {
        HStack {
            if (flag & MCOMessageFlag.deleted.rawValue) != 0 {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            if (flag & MCOMessageFlag.flagged.rawValue) != 0 {
                Image(systemName: "flag.fill")
                    .foregroundColor(.orange)
                    .font(.caption)
            }

            if encrypted ?? false {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            } else {
                Image(systemName: "lock.open.fill")
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
}
