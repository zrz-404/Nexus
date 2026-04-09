//
//  CardBlock.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

enum CardBlockType: String, Codable, CaseIterable {
    case text    = "Text"
    case heading = "Heading"
    case divider = "Divider"
}

struct CardBlock: Identifiable, Codable {
    var id: UUID = UUID()
    var type: CardBlockType
    var content: String = ""
    var createdAt: Date = Date()
}
