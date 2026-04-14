//
//  SidebarView.swift
//  Nexus - Phase 5
//
//  Updated with per-world document scoping
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Sidebar root
struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var search = ""
    @State private var showFilterMenu = false
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 0) {
            // World header
            HStack(spacing: 8) {
                if let world = appState.currentWorld {
                    ZStack {
                        Circle().fill(theme.accentSoft).frame(width: 26, height: 26)
                        Text(String(world.name.prefix(1)).uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(theme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(world.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                        Text("\(appState.currentWorldDocuments.count) documents")
                            .font(.system(size: 10))
                            .foregroundColor(theme.textTertiary)
                    }
                }
                Spacer()
                SidebarIconBtn(icon: "folder.badge.plus") {
                    isCreatingFolder = true
                }
                SidebarIconBtn(icon: "slider.horizontal.3") {
                    withAnimation(.spring(response: 0.25)) { showFilterMenu.toggle() }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .overlay(alignment: .topTrailing) {
                if showFilterMenu {
                    SidebarFilterMenu(dismiss: { showFilterMenu = false })
                        .offset(x: 0, y: 44)
                        .zIndex(100)
                }
            }
            .zIndex(showFilterMenu ? 100 : 0)

            // Inline new folder creation
            if isCreatingFolder {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(theme.accent)
                        .frame(width: 14)
                    TextField("Folder name", text: $newFolderName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textPrimary)
                        .onSubmit {
                            let name = newFolderName.trimmingCharacters(in: .whitespaces)
                            if !name.isEmpty { appState.createFolder(name: name) }
                            newFolderName = ""
                            isCreatingFolder = false
                        }
                    Button {
                        newFolderName = ""
                        isCreatingFolder = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundColor(theme.textTertiary)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(theme.accentSoft.opacity(0.5))
            }

            // Search
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11)).foregroundColor(theme.textTertiary)
                TextField("Search...", text: $search)
                    .textFieldStyle(.plain).font(.system(size: 11))
                    .foregroundColor(theme.textPrimary)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11)).foregroundColor(theme.textTertiary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.panelSoft)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(theme.border, lineWidth: 1))
            )
            .padding(.horizontal, 10).padding(.bottom, 8)

            // File tree - now scoped to current world
            if !search.isEmpty {
                // Flat search results (filtered by current world)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        let results = appState.currentWorldDocuments.filter {
                            $0.title.localizedCaseInsensitiveContains(search)
                        }
                        if results.isEmpty {
                            Text("No results")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textTertiary)
                                .padding(.top, 20)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(results) { doc in
                                SidebarDocRow(document: doc, depth: 0)
                                    .listRowBackground(Color.clear)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // Full tree (scoped to current world)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Root-level folders for current world
                        ForEach(appState.subfolders(of: nil)) { folder in
                            SidebarFolderRow(folder: folder, depth: 0)
                        }
                        // Root-level documents (no folder, current world only)
                        let rootDocs = appState.documents(inFolder: nil)
                        if !rootDocs.isEmpty || appState.subfolders(of: nil).isEmpty {
                            if !appState.subfolders(of: nil).isEmpty && !rootDocs.isEmpty {
                                Rectangle()
                                    .fill(theme.border.opacity(0.5))
                                    .frame(height: 1)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 4)
                            }
                            ForEach(rootDocs) { doc in
                                SidebarDocRow(document: doc, depth: 0)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .dropDestination(for: String.self) { items, _ in
                        guard let idStr = items.first,
                              let id = UUID(uuidString: idStr) else { return false }
                        appState.moveDocument(id, toFolder: nil)
                        return true
                    }
                }
            }

            Spacer(minLength: 0)

            // New document button
            Button {
                appState.createDocument(title: "Untitled Card", type: .card)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .medium))
                    Text("New Document").font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
                Rectangle().fill(theme.border).frame(height: 1)
            }
        }
    }
}

// MARK: - Folder row (recursive)
struct SidebarFolderRow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let folder: StudyFolder
    let depth: Int

    @State private var hovered = false
    @State private var isRenaming = false
    @State private var renameDraft = ""
    @State private var isDropTarget = false

    private var theme: AppTheme { themeManager.current }
    private var indent: CGFloat { CGFloat(depth) * 14 + 8 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Folder header row
            HStack(spacing: 6) {
                // Expand/collapse chevron
                Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .frame(width: 10)
                    .onTapGesture { appState.toggleFolderExpanded(id: folder.id) }

                Image(systemName: folder.isExpanded ? "folder.fill" : "folder")
                    .font(.system(size: 10))
                    .foregroundColor(theme.accent)
                    .frame(width: 14)

                if isRenaming {
                    TextField("Folder name", text: $renameDraft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(theme.textPrimary)
                        .onSubmit {
                            let name = renameDraft.trimmingCharacters(in: .whitespaces)
                            if !name.isEmpty { appState.renameFolder(id: folder.id, name: name) }
                            isRenaming = false
                        }
                } else {
                    Text(folder.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                // Add subfolder button (visible on hover)
                if hovered {
                    Button {
                        appState.createFolder(name: "New Folder", parentId: folder.id)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9))
                            .foregroundColor(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, indent)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovered ? theme.panelSoft : Color.clear)
            )
            .padding(.horizontal, 6)
            .onHover { hovered = $0 }
            .contextMenu {
                Button("Rename") {
                    renameDraft = folder.name
                    isRenaming = true
                }
                Button("New Subfolder") {
                    appState.createFolder(name: "New Folder", parentId: folder.id)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    appState.deleteFolder(id: folder.id)
                }
            }
            .dropDestination(for: String.self) { items, _ in
                guard let idStr = items.first,
                      let id = UUID(uuidString: idStr) else { return false }
                appState.moveDocument(id, toFolder: folder.id)
                return true
            } isTargeted: { targeted in
                isDropTarget = targeted
            }
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(theme.accent.opacity(0.5), lineWidth: isDropTarget ? 1.5 : 0)
                    .padding(.horizontal, 6)
            )

            // Children (if expanded)
            if folder.isExpanded {
                // Subfolders (recursive)
                ForEach(appState.subfolders(of: folder.id)) { subfolder in
                    SidebarFolderRow(folder: subfolder, depth: depth + 1)
                }
                
                // Documents in this folder
                let folderDocs = appState.documents(inFolder: folder.id)
                if !folderDocs.isEmpty {
                    ForEach(folderDocs) { doc in
                        SidebarDocRow(document: doc, depth: depth + 1)
                    }
                }
            }
        }
    }
}

// MARK: - Document row
struct SidebarDocRow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let document: StudyDocument
    let depth: Int

    @State private var hovered = false
    @State private var isDragging = false

    private var theme: AppTheme { themeManager.current }
    private var indent: CGFloat { CGFloat(depth) * 14 + 8 }
    var dtype: DocumentType { DocumentType(rawValue: document.type) ?? .card }
    
    var isOpen: Bool {
        appState.openDocuments.contains { $0.id == document.id }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: dtype.icon)
                .font(.system(size: 10))
                .foregroundColor(isOpen ? theme.accent : theme.textTertiary)
                .frame(width: 14)

            Text(document.title)
                .font(.system(size: 11))
                .foregroundColor(isOpen ? theme.accent : theme.textPrimary)
                .lineLimit(1)

            Spacer()
            
            // Open indicator
            if isOpen {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.leading, indent + 16) // Extra indent for doc under folder
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(hovered ? theme.panelSoft : Color.clear)
        )
        .padding(.horizontal, 6)
        .onHover { hovered = $0 }
        .onTapGesture {
            appState.openDocument(document)
        }
        .contextMenu {
            Button("Open") {
                appState.openDocument(document)
            }
            
            if document.type == DocumentType.card.rawValue {
                Button("Study in Echo") {
                    appState.openDocument(document)
                    appState.currentTab = .echo
                }
            }
            
            Divider()
            
            Button("Rename") {
                // TODO: Implement rename
            }
            
            Button("Duplicate") {
                let newDoc = StudyDocument(
                    worldId: document.worldId,
                    title: "\(document.title) Copy",
                    type: document.type,
                    folderId: document.folderId,
                    content: document.content
                )
                appState.documents.append(newDoc)
                appState.persistDocuments()
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                appState.deleteDocument(id: document.id)
            }
        }
        .draggable(document.id.uuidString) {
            HStack {
                Image(systemName: dtype.icon)
                Text(document.title)
            }
            .padding(8)
            .background(theme.panel)
            .cornerRadius(8)
        }
    }
}

// MARK: - Sidebar icon button
struct SidebarIconBtn: View {
    let icon: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(hovered ? .white : .white.opacity(0.6))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovered ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Filter menu
struct SidebarFilterMenu: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let dismiss: () -> Void
    
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FilterMenuItem(icon: "arrow.up.arrow.down", label: "Sort by Name") {
                // TODO: Implement sort
                dismiss()
            }
            FilterMenuItem(icon: "calendar", label: "Sort by Date") {
                // TODO: Implement sort
                dismiss()
            }
            Divider().padding(.vertical, 4)
            FilterMenuItem(icon: "eye", label: "Show All") {
                dismiss()
            }
            FilterMenuItem(icon: "doc", label: "Show Documents Only") {
                dismiss()
            }
            FilterMenuItem(icon: "folder", label: "Show Folders Only") {
                dismiss()
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .frame(width: 180)
    }
}

struct FilterMenuItem: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 12))
                Spacer()
            }
            .foregroundColor(hovered ? .white : .white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovered ? Color.white.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Preview
struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
            .frame(width: 250)
    }
}
