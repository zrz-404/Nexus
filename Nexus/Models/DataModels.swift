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

// MARK: - Folder (world-scoped)
struct StudyFolder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var worldId: UUID
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

// MARK: - Documents (world-scoped)
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
    var worldId: UUID
    var title: String
    var type: String
    var folderId: UUID? = nil
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

// MARK: - Echo / SM-2 spaced repetition
enum EchoRating: Int, Codable, CaseIterable {
    case again = 0, hard = 1, good = 2, easy = 3
    var label: String {
        switch self {
        case .again: return "Again"
        case .hard:  return "Hard"
        case .good:  return "Good"
        case .easy:  return "Easy"
        }
    }
    var color: Color {
        switch self {
        case .again: return Color(hex: "#E24B4A")
        case .hard:  return Color(hex: "#EF9F27")
        case .good:  return Color(hex: "#1D9E75")
        case .easy:  return Color(hex: "#378ADD")
        }
    }
}

struct EchoReview: Identifiable, Codable {
    var id: UUID = UUID()
    var documentId: UUID
    var worldId: UUID
    // SM-2 fields
    var interval: Int = 1        // days until next review
    var easeFactor: Double = 2.5
    var repetitions: Int = 0
    var nextReview: Date = Date()
    var lastReview: Date? = nil
}

// SM-2 algorithm
extension EchoReview {
    mutating func apply(rating: EchoRating) {
        let q = rating.rawValue
        lastReview = Date()
        if q < 2 {
            // Failed — reset
            repetitions = 0
            interval = 1
        } else {
            switch repetitions {
            case 0: interval = 1
            case 1: interval = 6
            default: interval = Int((Double(interval) * easeFactor).rounded())
            }
            repetitions += 1
        }
        // Update ease factor (minimum 1.3)
        easeFactor = max(1.3, easeFactor + 0.1 - Double(3 - q) * (0.08 + Double(3 - q) * 0.02))
        nextReview = Calendar.current.date(byAdding: .day, value: interval, to: Date()) ?? Date()
    }
}

// MARK: - Radio
struct RadioStation: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let streamURL: String
}

let defaultStations: [RadioStation] = [
    RadioStation(name: "Fireplace",     icon: "flame",          description: "Cozy crackling fire",
                 streamURL: "https://assets.mixkit.co/sfx/preview/mixkit-fireplace-crackling-1330.mp3"),
    RadioStation(name: "Rain",          icon: "cloud.rain",     description: "Gentle rainfall",
                 streamURL: "https://assets.mixkit.co/sfx/preview/mixkit-rain-and-thunder-ambiance-1291.mp3"),
    RadioStation(name: "Lofi Study",    icon: "headphones",     description: "Chill hip-hop beats",
                 streamURL: "https://stream.laut.fm/lofi"),
    RadioStation(name: "Deep Space",    icon: "sparkles",       description: "Ambient cosmos",
                 streamURL: "https://somafm.com/deepspaceone130.pls"),
    RadioStation(name: "Café",          icon: "cup.and.saucer", description: "Coffee shop ambience",
                 streamURL: "https://stream.laut.fm/cafe-del-mar-chillout-mix"),
    RadioStation(name: "Skyrim",        icon: "mountain.2",     description: "Nordic adventure",      streamURL: ""),
    RadioStation(name: "Lord of Rings", icon: "leaf",           description: "Epic orchestral",       streamURL: ""),
    RadioStation(name: "Harry Potter",  icon: "wand.and.stars", description: "Magical wonder",        streamURL: ""),
]
