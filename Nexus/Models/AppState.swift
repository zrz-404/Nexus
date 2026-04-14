//
//  AppState.swift
//  Nexus - Phase 5
//
//  Updated with per-world document scoping and Echo SRS
//

import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .userCreation
    @Published var currentTab: WorkspaceTab = .world
    @Published var user: StudyUser?
    @Published var worlds: [StudyWorld] = []
    @Published var currentWorld: StudyWorld?

    // Onboarding staging
    @Published var pendingWorldName: String = ""
    @Published var pendingGenre: String = ""

    // Workspace
    @Published var sidebarVisible: Bool = true
    @Published var documents: [StudyDocument] = []
    @Published var folders: [StudyFolder] = []
    @Published var openDocuments: [StudyDocument] = []
    @Published var recentItems: [StudyDocument] = []
    
    // Echo SRS
    @Published var echoCards: [EchoCard] = []
    @Published var echoStats: EchoSessionStats = EchoSessionStats()

    struct DocumentWindowState {
        var position: CGPoint   // CENTER of the window in workspace coords
        var size: CGSize
    }
    @Published var windowStates: [UUID: DocumentWindowState] = [:]

    init() { bootstrap() }

    // MARK: - Persistence
    private func bootstrap() {
        if let data = UserDefaults.standard.data(forKey: "nexus_user"),
           let saved = try? JSONDecoder().decode(StudyUser.self, from: data) {
            user = saved
            loadWorlds()
            loadDocuments()
            loadFolders()
            loadEchoCards()
            loadEchoStats()
            currentScreen = worlds.isEmpty ? .worldCreation : .main
        }
    }

    private func loadWorlds() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_worlds"),
              let saved = try? JSONDecoder().decode([StudyWorld].self, from: data) else { return }
        worlds = saved
        currentWorld = saved.first
    }

    private func loadDocuments() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_documents"),
              let saved = try? JSONDecoder().decode([StudyDocument].self, from: data) else { return }
        documents = saved
    }

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_folders"),
              let saved = try? JSONDecoder().decode([StudyFolder].self, from: data) else { return }
        folders = saved
    }
    
    private func loadEchoCards() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_echo_cards"),
              let saved = try? JSONDecoder().decode([EchoCard].self, from: data) else { return }
        echoCards = saved
    }
    
    private func loadEchoStats() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_echo_stats"),
              let saved = try? JSONDecoder().decode(EchoSessionStats.self, from: data) else { return }
        echoStats = saved
    }

    private func persistDocuments() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: "nexus_documents")
        }
    }

    private func persistFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: "nexus_folders")
        }
    }
    
    private func persistEchoCards() {
        if let data = try? JSONEncoder().encode(echoCards) {
            UserDefaults.standard.set(data, forKey: "nexus_echo_cards")
        }
    }
    
    private func persistEchoStats() {
        if let data = try? JSONEncoder().encode(echoStats) {
            UserDefaults.standard.set(data, forKey: "nexus_echo_stats")
        }
    }

    // MARK: - Window state
    func windowState(for id: UUID, workspaceSize: CGSize) -> DocumentWindowState {
        if let s = windowStates[id] { return s }
        let idx = openDocuments.firstIndex(where: { $0.id == id }) ?? 0
        let offset = CGFloat(idx % 6) * 28
        let s = DocumentWindowState(
            position: CGPoint(
                x: workspaceSize.width  * 0.5 + offset,
                y: workspaceSize.height * 0.5 + offset
            ),
            size: CGSize(width: 520, height: 600)
        )
        windowStates[id] = s
        return s
    }

    func updateWindowPosition(for id: UUID, position: CGPoint) {
        if windowStates[id] != nil {
            windowStates[id]!.position = position
        } else {
            windowStates[id] = DocumentWindowState(position: position, size: CGSize(width: 520, height: 600))
        }
    }

    func updateWindowSize(for id: UUID, size: CGSize) {
        if windowStates[id] != nil {
            windowStates[id]!.size = size
        } else {
            windowStates[id] = DocumentWindowState(position: .zero, size: size)
        }
    }

    // MARK: - Per-World Document Scoping
    
    /// Returns documents for the current world only
    var currentWorldDocuments: [StudyDocument] {
        guard let worldId = currentWorld?.id else { return [] }
        return documents.filter { $0.worldId == worldId }
    }
    
    /// Returns folders for the current world only
    var currentWorldFolders: [StudyFolder] {
        guard let worldId = currentWorld?.id else { return [] }
        return folders.filter { $0.worldId == worldId }
    }

    // MARK: - Document CRUD with World Scoping
    func createDocument(title: String, type: DocumentType, folderId: UUID? = nil, content: String? = nil) {
        let doc = StudyDocument(
            worldId: currentWorld?.id,  // Automatically scope to current world
            title: title,
            type: type.rawValue,
            folderId: folderId,
            content: content ?? ""
        )
        documents.append(doc)
        openDocuments.append(doc)
        addToRecents(doc)
        persistDocuments()
    }
    
    /// Create a document with specific worldId (for AI generation, etc.)
    func createDocumentInWorld(worldId: UUID, title: String, type: DocumentType, folderId: UUID? = nil, content: String? = nil) {
        let doc = StudyDocument(
            worldId: worldId,
            title: title,
            type: type.rawValue,
            folderId: folderId,
            content: content ?? ""
        )
        documents.append(doc)
        openDocuments.append(doc)
        addToRecents(doc)
        persistDocuments()
    }

    func deleteDocument(id: UUID) {
        openDocuments.removeAll { $0.id == id }
        documents.removeAll { $0.id == id }
        windowStates.removeValue(forKey: id)
        persistDocuments()
    }

    func moveDocuments(from: IndexSet, to: Int) {
        documents.move(fromOffsets: from, toOffset: to)
        persistDocuments()
    }

    func moveDocument(_ id: UUID, toFolder folderId: UUID?) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].folderId = folderId
        persistDocuments()
    }

    func openDocument(_ doc: StudyDocument) {
        // Only allow opening documents from current world
        guard doc.worldId == currentWorld?.id else { return }
        
        if !openDocuments.contains(where: { $0.id == doc.id }) {
            openDocuments.append(doc)
        }
        addToRecents(doc)
        currentTab = .world
    }

    func closeDocument(_ doc: StudyDocument) {
        openDocuments.removeAll { $0.id == doc.id }
        windowStates.removeValue(forKey: doc.id)
    }

    func updateDocumentContent(id: UUID, title: String? = nil, content: String? = nil) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        if let t = title   { documents[idx].title = t }
        if let c = content { documents[idx].content = c }
        documents[idx].updatedAt = Date()
        
        // Update open documents too
        if let openIdx = openDocuments.firstIndex(where: { $0.id == id }) {
            if let t = title   { openDocuments[openIdx].title = t }
            if let c = content { openDocuments[openIdx].content = c }
            openDocuments[openIdx].updatedAt = Date()
        }
        persistDocuments()
    }
    
    /// Update document with decoded content (for Mind Map, Cards, etc.)
    func updateDocumentTypedContent<T: Codable>(id: UUID, typedContent: T) {
        guard let data = try? JSONEncoder().encode(typedContent),
              let jsonString = String(data: data, encoding: .utf8) else { return }
        updateDocumentContent(id: id, content: jsonString)
    }

    // MARK: - Folder CRUD with World Scoping
    func createFolder(name: String, parentId: UUID? = nil) {
        let folder = StudyFolder(
            name: name,
            worldId: currentWorld?.id,  // Automatically scope to current world
            parentId: parentId
        )
        folders.append(folder)
        persistFolders()
    }

    func deleteFolder(id: UUID) {
        // Move all documents in this folder to root
        for idx in documents.indices where documents[idx].folderId == id {
            documents[idx].folderId = nil
        }
        // Delete child folders recursively
        let children = folders.filter { $0.parentId == id }
        for child in children { deleteFolder(id: child.id) }
        folders.removeAll { $0.id == id }
        persistFolders()
        persistDocuments()
    }

    func renameFolder(id: UUID, name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = name
        persistFolders()
    }

    func toggleFolderExpanded(id: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].isExpanded.toggle()
        persistFolders()
    }

    // MARK: - Documents in a folder / at root (filtered by current world)
    func documents(inFolder folderId: UUID?) -> [StudyDocument] {
        guard let worldId = currentWorld?.id else { return [] }
        return documents.filter { $0.worldId == worldId && $0.folderId == folderId }
    }

    func subfolders(of parentId: UUID?) -> [StudyFolder] {
        guard let worldId = currentWorld?.id else { return [] }
        return folders.filter { $0.worldId == worldId && $0.parentId == parentId }
    }

    private func addToRecents(_ doc: StudyDocument) {
        recentItems.removeAll { $0.id == doc.id }
        recentItems.insert(doc, at: 0)
        recentItems = Array(recentItems.prefix(5))
    }

    // MARK: - User
    func saveUser(_ username: String) {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let u = StudyUser(username: username)
        user = u
        if let data = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(data, forKey: "nexus_user")
        }
        currentScreen = .worldCreation
    }

    // MARK: - World
    func createWorld() {
        guard !pendingWorldName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let w = StudyWorld(name: pendingWorldName, genre: pendingGenre)
        worlds.append(w)
        currentWorld = w
        if let data = try? JSONEncoder().encode(worlds) {
            UserDefaults.standard.set(data, forKey: "nexus_worlds")
        }
        pendingWorldName = ""
        pendingGenre = ""
        currentScreen = .main
    }

    func switchToWorld(_ world: StudyWorld) {
        currentWorld = world
        openDocuments = []  // Clear open documents when switching worlds
    }

    func deleteWorld(id: UUID) {
        // Delete all documents and folders in this world
        documents.removeAll { $0.worldId == id }
        folders.removeAll { $0.worldId == id }
        echoCards.removeAll { card in
            documents.first { $0.id == card.documentId }?.worldId == id
        }
        
        worlds.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(worlds) {
            UserDefaults.standard.set(data, forKey: "nexus_worlds")
        }
        persistDocuments()
        persistFolders()
        persistEchoCards()
        
        if currentWorld?.id == id {
            if let next = worlds.first {
                currentWorld = next
                openDocuments = []
            } else {
                currentWorld = nil
                openDocuments = []
                pendingWorldName = ""
                pendingGenre = ""
                currentScreen = .worldCreation
            }
        }
    }
    
    // MARK: - Echo Spaced Repetition
    
    /// Get all due cards for the current world
    var dueEchoCards: [EchoCard] {
        guard let worldId = currentWorld?.id else { return [] }
        return echoCards.filter { card in
            card.isDue && documents.first { $0.id == card.documentId }?.worldId == worldId
        }
    }
    
    /// Get new cards for the current world
    var newEchoCards: [EchoCard] {
        guard let worldId = currentWorld?.id else { return [] }
        return echoCards.filter { card in
            card.isNew && documents.first { $0.id == card.documentId }?.worldId == worldId
        }
    }
    
    /// Get learning cards for the current world
    var learningEchoCards: [EchoCard] {
        guard let worldId = currentWorld?.id else { return [] }
        return echoCards.filter { card in
            card.isLearning && documents.first { $0.id == card.documentId }?.worldId == worldId
        }
    }
    
    /// Add echo cards from a document
    func addEchoCards(from documentId: UUID, cards: [CardContent]) {
        let newCards = cards.map { content in
            EchoCard(
                documentId: documentId,
                front: content.front,
                back: content.back
            )
        }
        echoCards.append(contentsOf: newCards)
        persistEchoCards()
    }
    
    /// Create a single echo card
    func createEchoCard(documentId: UUID, front: String, back: String) {
        let card = EchoCard(documentId: documentId, front: front, back: back)
        echoCards.append(card)
        persistEchoCards()
    }
    
    /// Review a card with quality rating (0-5)
    func reviewEchoCard(cardId: UUID, quality: Int) {
        guard let idx = echoCards.firstIndex(where: { $0.id == cardId }) else { return }
        
        var card = echoCards[idx]
        let oldInterval = card.interval
        let oldEaseFactor = card.easeFactor
        
        // SM-2 Algorithm
        if quality < 3 {
            // Failed - reset repetitions, keep interval small
            card.repetitions = 0
            card.interval = 1
        } else {
            // Success - increase repetitions and interval
            card.repetitions += 1
            
            if card.repetitions == 1 {
                card.interval = 1
            } else if card.repetitions == 2 {
                card.interval = 6
            } else {
                card.interval = Int(Double(card.interval) * card.easeFactor)
            }
        }
        
        // Update ease factor
        card.easeFactor = max(1.3, card.easeFactor + 0.1 - (5.0 - Double(quality)) * (0.08 + (5.0 - Double(quality)) * 0.02))
        
        // Set next review date
        card.nextReviewDate = Calendar.current.date(byAdding: .day, value: card.interval, to: Date()) ?? Date()
        card.lastReviewDate = Date()
        
        // Add review history
        let entry = ReviewEntry(
            date: Date(),
            quality: quality,
            interval: oldInterval,
            easeFactor: oldEaseFactor
        )
        card.reviewHistory.append(entry)
        
        echoCards[idx] = card
        persistEchoCards()
        
        // Update stats
        updateEchoStats(quality: quality)
    }
    
    /// Delete an echo card
    func deleteEchoCard(id: UUID) {
        echoCards.removeAll { $0.id == id }
        persistEchoCards()
    }
    
    private func updateEchoStats(quality: Int) {
        echoStats.cardsStudied += 1
        echoStats.totalReviews += 1
        if quality >= 3 {
            echoStats.correctAnswers += 1
        }
        
        // Update streak
        let calendar = Calendar.current
        if let lastDate = echoStats.lastStudyDate {
            if calendar.isDateInYesterday(lastDate) {
                echoStats.streakDays += 1
            } else if !calendar.isDateInToday(lastDate) {
                echoStats.streakDays = 1  // Reset streak
            }
        } else {
            echoStats.streakDays = 1
        }
        echoStats.lastStudyDate = Date()
        
        persistEchoStats()
    }
    
    /// Reset all echo data (for testing)
    func resetEchoData() {
        echoCards = []
        echoStats = EchoSessionStats()
        persistEchoCards()
        persistEchoStats()
    }
}
