//
//  AppState.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
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

    // MARK: - Document CRUD
    func createDocument(title: String, type: DocumentType, folderId: UUID? = nil) {
        let doc = StudyDocument(title: title, type: type.rawValue, folderId: folderId)
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

    // MARK: - Folder CRUD
    func createFolder(name: String, parentId: UUID? = nil) {
        let folder = StudyFolder(name: name, parentId: parentId)
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

    // MARK: - Documents in a folder / at root
    func documents(inFolder folderId: UUID?) -> [StudyDocument] {
        documents.filter { $0.folderId == folderId }
    }

    func subfolders(of parentId: UUID?) -> [StudyFolder] {
        folders.filter { $0.parentId == parentId }
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
        openDocuments = []
    }

    func deleteWorld(id: UUID) {
        worlds.removeAll { $0.id == id }
        if let data = try? JSONEncoder().encode(worlds) {
            UserDefaults.standard.set(data, forKey: "nexus_worlds")
        }
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
}
