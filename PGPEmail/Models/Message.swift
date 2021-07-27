//
//  Message.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/10/21.
//

import Foundation

struct Message: Identifiable, Codable {
    var id: UInt32
    var flags: Int

    let sendDate: Date
    let from: Mailbox
    let to: [Mailbox]
    let cc: [Mailbox]
    let bcc: [Mailbox]
    let subject: String
    var unsubscribe: String = ""
}

struct Mailbox: Codable {
    let name: String
    let email: String
}
