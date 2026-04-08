//
//  Item.swift
//  Nexus
//
//  Created by José Roseiro on 08/04/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
