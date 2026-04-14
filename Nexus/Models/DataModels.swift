//
//  DataModels.swift
//  Nexus - Phase 5
//
//  Updated with per-world document scoping, Mind Map nodes, and Echo card models
//

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
    var worldId: UUID? = nil  // Per-world scoping
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

// MARK: - Study Document with World Scoping
struct StudyDocument: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var worldId: UUID? = nil  // Per-world scoping - documents belong to a world
    var title: String
    var type: String
    var parentId: UUID? = nil        // parent folder id
    var folderId: UUID? = nil        // explicit folder membership
    var content: String = ""         // JSON-encoded content based on type
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Helper to decode card content
    var cardContent: CardContent? {
        guard type == DocumentType.card.rawValue else { return nil }
        return try? JSONDecoder().decode(CardContent.self, from: content.data(using: .utf8) ?? Data())
    }
    
    // Helper to decode mind map nodes
    var mindMapNodes: [MindMapNode]? {
        guard type == DocumentType.mindmap.rawValue else { return nil }
        return try? JSONDecoder().decode([MindMapNode].self, from: content.data(using: .utf8) ?? Data())
    }
    
    // Helper to decode echo cards
    var echoCards: [EchoCard]? {
        guard type == DocumentType.card.rawValue else { return nil }
        return try? JSONDecoder().decode([EchoCard].self, from: content.data(using: .utf8) ?? Data())
    }
}

// MARK: - Card Content Model
struct CardContent: Codable, Equatable {
    var front: String
    var back: String
    var tags: [String] = []
    var source: String? = nil  // AI-generated or manual
    
    static func empty() -> CardContent {
        CardContent(front: "", back: "", tags: [])
    }
}

// MARK: - Mind Map Node Model
struct MindMapNode: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var text: String
    var x: Double
    var y: Double
    var parentId: UUID? = nil  // nil = root node
    var color: String = "#6366F1"  // Default indigo
    var createdAt: Date = Date()
    
    // For tree layout calculations
    var children: [UUID]? = nil  // Computed, not persisted
}

// MARK: - Echo Spaced Repetition Card
struct EchoCard: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var documentId: UUID  // Links to parent document
    var front: String
    var back: String
    
    // SRS Algorithm Data (SM-2 inspired)
    var interval: Int = 0           // Current interval in days
    var repetitions: Int = 0        // Number of successful reviews
    var easeFactor: Double = 2.5    // Ease factor (starts at 2.5)
    var nextReviewDate: Date = Date()
    var lastReviewDate: Date? = nil
    
    // Review quality (0-5): 0=complete blackout, 5=perfect
    var reviewHistory: [ReviewEntry] = []
    
    var isDue: Bool {
        nextReviewDate <= Date()
    }
    
    var isNew: Bool {
        repetitions == 0
    }
    
    var isLearning: Bool {
        repetitions > 0 && repetitions < 3
    }
    
    var isMature: Bool {
        repetitions >= 3
    }
}

// MARK: - Review Entry for History
struct ReviewEntry: Codable, Equatable {
    var date: Date
    var quality: Int  // 0-5
    var interval: Int
    var easeFactor: Double
}

// MARK: - Echo Session Stats
struct EchoSessionStats: Codable {
    var cardsStudied: Int = 0
    var correctAnswers: Int = 0
    var streakDays: Int = 0
    var lastStudyDate: Date? = nil
    var totalReviews: Int = 0
}

// MARK: - Radio
struct RadioStation: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let streamURL: String?
    let isPlaylist: Bool  // Whether URL is a PLS/M3U playlist
    let fallbackURL: String?  // Backup stream URL
}

let defaultStations: [RadioStation] = [
    RadioStation(name: "Fireplace", icon: "flame", description: "Cozy crackling fire", 
                 streamURL: "https://assets.mixkit.co/sfx/preview/mixkit-fireplace-crackling-1330.mp3", 
                 isPlaylist: false, fallbackURL: nil),
    RadioStation(name: "Rain", icon: "cloud.rain", description: "Gentle rainfall", 
                 streamURL: "https://assets.mixkit.co/sfx/preview/mixkit-rain-and-thunder-ambiance-1291.mp3", 
                 isPlaylist: false, fallbackURL: nil),
    RadioStation(name: "Lofi Study", icon: "headphones", description: "Chill hip-hop beats", 
                 streamURL: "https://stream.laut.fm/lofi", 
                 isPlaylist: false, fallbackURL: "https://streams.fluxfm.de/live/mp3-320/streams.fluxfm.de/"),
    RadioStation(name: "Deep Space", icon: "sparkles", description: "Ambient cosmos", 
                 streamURL: "https://somafm.com/deepspaceone130.pls", 
                 isPlaylist: true, fallbackURL: "https://ice4.somafm.com/deepspaceone-128-mp3"),
    RadioStation(name: "Café", icon: "cup.and.saucer", description: "Coffee shop ambience", 
                 streamURL: "https://stream.laut.fm/cafe-del-mar-chillout-mix", 
                 isPlaylist: false, fallbackURL: nil),
    RadioStation(name: "Skyrim", icon: "mountain.2", description: "Nordic adventure", 
                 streamURL: nil, isPlaylist: false, fallbackURL: nil),  // Placeholder for local/Spotify
    RadioStation(name: "Lord of Rings", icon: "leaf", description: "Epic orchestral", 
                 streamURL: nil, isPlaylist: false, fallbackURL: nil),
    RadioStation(name: "Harry Potter", icon: "wand.and.stars", description: "Magical wonder", 
                 streamURL: nil, isPlaylist: false, fallbackURL: nil),
]

// MARK: - AI Generation Request/Response Models
struct AIGenerationRequest: Codable {
    let topic: String
    let cardCount: Int
    let difficulty: String  // beginner, intermediate, advanced
    let includeExamples: Bool
}

struct AIGeneratedCard: Codable {
    let front: String
    let back: String
    let tags: [String]
}

// MARK: - Radio Player State
enum RadioPlayerState: Equatable {
    case idle
    case loading
    case playing(station: RadioStation)
    case error(message: String)
    case buffering
}
