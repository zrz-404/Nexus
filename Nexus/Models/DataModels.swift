//
//  DataModels.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

import SwiftUI

// MARK: - Navigation
enum AppScreen { case userCreation, worldCreation, genrePicker, radioStation, main }

enum WorkspaceTab: String, CaseIterable {
    case home = "Home", world = "World", wiki = "Wiki", quill = "Quill", echo = "Echo"
    var icon: String {
        switch self {
        case .home:   return "house.fill"
        case .world:  return "globe"
        case .wiki:   return "book.closed.fill"
        case .quill:  return "pencil"
        case .echo:   return "waveform"
        }
    }
}

// MARK: - User & World
struct StudyUser: Codable, Equatable { var username: String }

struct StudyWorld: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var genre: String
    var createdAt: Date = Date()
}

// MARK: - Folder
struct StudyFolder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var parentId: UUID? = nil
    var isExpanded: Bool = true
    var createdAt: Date = Date()
}

// MARK: - Genres
enum StudyGenre: String, CaseIterable {
    case medicine = "Medicine", sciences = "Sciences", humanities = "Humanities"
    case visualArts = "Visual Arts", music = "Music", linguistics = "Linguistics"
    case mathematics = "Mathematics", engineering = "Engineering"
    case computerScience = "Computer Science", history = "History"
    case philosophy = "Philosophy", psychology = "Psychology"
    case law = "Law", economics = "Economics", literature = "Literature"

    var icon: String {
        switch self {
        case .medicine:        return "cross.circle"
        case .sciences:        return "atom"
        case .humanities:      return "person.3"
        case .visualArts:      return "paintpalette"
        case .music:           return "music.note"
        case .linguistics:     return "character.bubble"
        case .mathematics:     return "function"
        case .engineering:     return "wrench.and.screwdriver"
        case .computerScience: return "laptopcomputer"
        case .history:         return "clock.arrow.circlepath"
        case .philosophy:      return "lightbulb"
        case .psychology:      return "brain.head.profile"
        case .law:             return "building.columns"
        case .economics:       return "chart.line.uptrend.xyaxis"
        case .literature:      return "book"
        }
    }
}

// MARK: - Documents
enum DocumentType: String, CaseIterable, Identifiable {
    case card = "Card", canvas = "Canvas", mindmap = "Mind Map"
    case connections = "Connections", note = "Note"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .card:        return "rectangle.on.rectangle"
        case .canvas:      return "square.grid.2x2"
        case .mindmap:     return "circle.hexagongrid"
        case .connections: return "point.3.connected.trianglepath.dotted"
        case .note:        return "note.text"
        }
    }
}

struct StudyDocument: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var type: String
    var parentId: UUID? = nil        // parent folder id
    var folderId: UUID? = nil        // explicit folder membership
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

// MARK: - Radio
struct RadioStation: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
}

let defaultStations: [RadioStation] = [
    RadioStation(name: "Fireplace",      icon: "flame",              description: "Cozy crackling fire"),
    RadioStation(name: "Skyrim",         icon: "mountain.2",         description: "Nordic adventure"),
    RadioStation(name: "Lofi Study",     icon: "headphones",         description: "Chill hip-hop beats"),
    RadioStation(name: "Lord of Rings",  icon: "leaf",               description: "Epic orchestral"),
    RadioStation(name: "Harry Potter",   icon: "wand.and.stars",     description: "Magical wonder"),
    RadioStation(name: "Rain",           icon: "cloud.rain",         description: "Gentle rainfall"),
    RadioStation(name: "Café",           icon: "cup.and.saucer",     description: "Coffee shop ambience"),
    RadioStation(name: "Deep Space",     icon: "sparkles",           description: "Ambient cosmos"),
]
