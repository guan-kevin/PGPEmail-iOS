//
//  Content.swift
//  PGPEmail
//
//  Created by Kevin Guan on 6/11/21.
//

import Foundation

struct Content: Identifiable, Codable {
    var id: UInt32
    let encrypted: Bool
    let content: String
    let isHTML: Bool
}
