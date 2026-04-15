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

    // All data — filtered by currentWorld at point of use
    @Published var documents: [StudyDocument] = []
    @Published var folders: [StudyFolder] = []
    @Published var echoReviews: [EchoReview] = []

    // Open windows (per-session, not persisted)
    @Published var openDocuments: [StudyDocument] = []
    @Published var recentItems: [StudyDocument] = []

    struct DocumentWindowState {
        var position: CGPoint   // CENTER of window in workspace coords
        var size: CGSize
    }
    @Published var windowStates: [UUID: DocumentWindowState] = [:]

    init() { bootstrap() }

    // MARK: - Current-world convenience filters
    var currentDocuments: [StudyDocument] {
        guard let wid = currentWorld?.id else { return [] }
        return documents.filter { $0.worldId == wid }
    }

    var currentFolders: [StudyFolder] {
        guard let wid = currentWorld?.id else { return [] }
        return folders.filter { $0.worldId == wid }
    }

    var currentEchoReviews: [EchoReview] {
        guard let wid = currentWorld?.id else { return [] }
        return echoReviews.filter { $0.worldId == wid }
    }

    /// Cards due for review today (or overdue) in the current world
    var echoQueue: [StudyDocument] {
        let now = Date()
        let dueIds = Set(
            currentEchoReviews
                .filter { $0.nextReview <= now }
                .map { $0.documentId }
        )
        // Also include cards that have never been reviewed
        let reviewedIds = Set(currentEchoReviews.map { $0.documentId })
        let cardDocs = currentDocuments.filter { $0.type == DocumentType.card.rawValue }
        let neverReviewed = cardDocs.filter { !reviewedIds.contains($0.id) }
        let dueCards = cardDocs.filter { dueIds.contains($0.id) }
        return (dueCards + neverReviewed).uniqued(by: \.id)
    }

    // MARK: - Bootstrap
    private func bootstrap() {
        if let data = UserDefaults.standard.data(forKey: "nexus_user"),
           let saved = try? JSONDecoder().decode(StudyUser.self, from: data) {
            user = saved
            loadWorlds()
            loadDocuments()
            loadFolders()
            loadEchoReviews()
            currentScreen = worlds.isEmpty ? .worldCreation : .main
        }
    }

    // MARK: - Persistence helpers
    private func loadWorlds() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_worlds"),
              let saved = try? JSONDecoder().decode([StudyWorld].self, from: data) else { return }
        worlds = saved
        currentWorld = saved.first
    }

    private func loadDocuments() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_documents_v2") else {
            migrateOldDocuments()
            return
        }
        guard let saved = try? JSONDecoder().decode([StudyDocument].self, from: data) else { return }
        documents = saved
    }

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_folders_v2"),
              let saved = try? JSONDecoder().decode([StudyFolder].self, from: data) else { return }
        folders = saved
    }

    private func loadEchoReviews() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_echo_reviews"),
              let saved = try? JSONDecoder().decode([EchoReview].self, from: data) else { return }
        echoReviews = saved
    }

    /// One-time migration: old documents had no worldId — assign them to the first world
    private func migrateOldDocuments() {
        guard let data = UserDefaults.standard.data(forKey: "nexus_documents"),
              let raw = try? JSONDecoder().decode([LegacyDocument].self, from: data),
              let firstWorld = worlds.first else { return }
        documents = raw.map { old in
            StudyDocument(
                id: old.id,
                worldId: firstWorld.id,
                title: old.title,
                type: old.type,
                folderId: nil,
                content: old.content,
                createdAt: old.createdAt,
                updatedAt: old.updatedAt
            )
        }
        persistDocuments()
    }

    private func persistDocuments() {
        if let data = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(data, forKey: "nexus_documents_v2")
        }
    }

    private func persistFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: "nexus_folders_v2")
        }
    }

    private func persistEchoReviews() {
        if let data = try? JSONEncoder().encode(echoReviews) {
            UserDefaults.standard.set(data, forKey: "nexus_echo_reviews")
        }
    }

    // MARK: - Window state
    func windowState(for id: UUID, workspaceSize: CGSize) -> DocumentWindowState {
        if let s = windowStates[id] { return s }
        let idx = openDocuments.firstIndex(where: { $0.id == id }) ?? 0
        let offset = CGFloat(idx % 6) * 28
        let s = DocumentWindowState(
            position: CGPoint(x: workspaceSize.width * 0.5 + offset,
                              y: workspaceSize.height * 0.5 + offset),
            size: CGSize(width: 520, height: 600)
        )
        windowStates[id] = s
        return s
    }

    func updateWindowPosition(for id: UUID, position: CGPoint) {
        if windowStates[id] != nil { windowStates[id]!.position = position }
        else { windowStates[id] = DocumentWindowState(position: position, size: CGSize(width: 520, height: 600)) }
    }

    func updateWindowSize(for id: UUID, size: CGSize) {
        if windowStates[id] != nil { windowStates[id]!.size = size }
        else { windowStates[id] = DocumentWindowState(position: .zero, size: size) }
    }

    // MARK: - Document CRUD
    func createDocument(title: String, type: DocumentType, folderId: UUID? = nil) {
        guard let worldId = currentWorld?.id else { return }
        let doc = StudyDocument(worldId: worldId, title: title, type: type.rawValue, folderId: folderId)
        documents.append(doc)
        openDocuments.append(doc)
        addToRecents(doc)
        persistDocuments()
    }

    func deleteDocument(id: UUID) {
        openDocuments.removeAll { $0.id == id }
        documents.removeAll { $0.id == id }
        echoReviews.removeAll { $0.documentId == id }
        windowStates.removeValue(forKey: id)
        persistDocuments()
        persistEchoReviews()
    }

    func moveDocument(_ id: UUID, toFolder folderId: UUID?) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].folderId = folderId
        persistDocuments()
    }

    func openDocument(_ doc: StudyDocument) {
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
        persistDocuments()
    }

    // MARK: - Folder CRUD (world-scoped)
    func createFolder(name: String, parentId: UUID? = nil) {
        guard let worldId = currentWorld?.id else { return }
        let folder = StudyFolder(name: name, worldId: worldId, parentId: parentId)
        folders.append(folder)
        persistFolders()
    }

    func deleteFolder(id: UUID) {
        // Move child documents to root
        for idx in documents.indices where documents[idx].folderId == id {
            documents[idx].folderId = nil
        }
        // Recurse into subfolders
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

    // MARK: - Tree queries (current world only)
    func documents(inFolder folderId: UUID?) -> [StudyDocument] {
        currentDocuments.filter { $0.folderId == folderId }
    }

    func subfolders(of parentId: UUID?) -> [StudyFolder] {
        currentFolders.filter { $0.parentId == parentId }
    }

    // MARK: - Echo / spaced repetition
    func echoReview(for documentId: UUID) -> EchoReview? {
        echoReviews.first(where: { $0.documentId == documentId })
    }

    func applyEchoRating(documentId: UUID, rating: EchoRating) {
        guard let worldId = currentWorld?.id else { return }
        if let idx = echoReviews.firstIndex(where: { $0.documentId == documentId }) {
            echoReviews[idx].apply(rating: rating)
        } else {
            var review = EchoReview(documentId: documentId, worldId: worldId)
            review.apply(rating: rating)
            echoReviews.append(review)
        }
        persistEchoReviews()
    }

    // MARK: - World CRUD
    func saveUser(_ username: String) {
        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let u = StudyUser(username: username)
        user = u
        if let data = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(data, forKey: "nexus_user")
        }
        currentScreen = .worldCreation
    }

    func createWorld() {
        guard !pendingWorldName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let w = StudyWorld(name: pendingWorldName, genre: pendingGenre)
        worlds.append(w)
        currentWorld = w
        persistWorlds()
        pendingWorldName = ""
        pendingGenre = ""
        currentScreen = .main
    }

    func switchToWorld(_ world: StudyWorld) {
        currentWorld = world
        openDocuments = []
        windowStates = [:]
        recentItems = []
    }

    func deleteWorld(id: UUID) {
        // Delete all documents, folders, reviews belonging to this world
        documents.removeAll { $0.worldId == id }
        folders.removeAll { $0.worldId == id }
        echoReviews.removeAll { $0.worldId == id }
        worlds.removeAll { $0.id == id }
        persistWorlds()
        persistDocuments()
        persistFolders()
        persistEchoReviews()

        if currentWorld?.id == id {
            if let next = worlds.first {
                switchToWorld(next)
            } else {
                currentWorld = nil
                openDocuments = []
                pendingWorldName = ""
                pendingGenre = ""
                currentScreen = .worldCreation
            }
        }
    }

    private func persistWorlds() {
        if let data = try? JSONEncoder().encode(worlds) {
            UserDefaults.standard.set(data, forKey: "nexus_worlds")
        }
    }

    private func addToRecents(_ doc: StudyDocument) {
        recentItems.removeAll { $0.id == doc.id }
        recentItems.insert(doc, at: 0)
        recentItems = Array(recentItems.prefix(8))
    }
}

// MARK: - Legacy migration shim
private struct LegacyDocument: Codable {
    var id: UUID = UUID()
    var title: String
    var type: String
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

// MARK: - Array unique helper
extension Array {
    func uniqued<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
}
