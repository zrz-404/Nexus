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
                    Text(world.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)
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

            // File tree
            if !search.isEmpty {
                // Flat search results
                ScrollView {
                    LazyVStack(spacing: 0) {
                        let results = appState.documents.filter {
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
                // Full tree
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Root-level folders
                        ForEach(appState.subfolders(of: nil)) { folder in
                            SidebarFolderRow(folder: folder, depth: 0)
                        }
                        // Root-level documents (no folder)
                        let rootDocs = appState.documents(inFolder: nil)
                        if !rootDocs.isEmpty || appState.subfolders(of: nil).isEmpty {
                            if !appState.subfolders(of: nil).isEmpty && !rootDocs.isEmpty {
                                // Divider between folders and loose docs
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
                    // Accept drops of doc IDs to move to root
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

                // + button on hover
                if hovered && !isRenaming {
                    Button {
                        appState.createDocument(title: "Untitled Card", type: .card, folderId: folder.id)
                        if !folder.isExpanded { appState.toggleFolderExpanded(id: folder.id) }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 9))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 16, height: 16)
                            .background(RoundedRectangle(cornerRadius: 4).fill(theme.panelSoft))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, indent)
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isDropTarget
                            ? theme.accentSoft
                            : (hovered ? theme.panelSoft : Color.clear)
                    )
                    .overlay(
                        isDropTarget
                            ? RoundedRectangle(cornerRadius: 6).stroke(theme.accent.opacity(0.4), lineWidth: 1)
                            : nil
                    )
                    .padding(.horizontal, 4)
            )
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.1)) { hovered = isHovered }
            }
            .contentShape(Rectangle())
            .onTapGesture { appState.toggleFolderExpanded(id: folder.id) }
            .contextMenu {
                Button { isRenaming = true; renameDraft = folder.name } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    appState.createDocument(title: "Untitled Card", type: .card, folderId: folder.id)
                    if !folder.isExpanded { appState.toggleFolderExpanded(id: folder.id) }
                } label: {
                    Label("New Document Inside", systemImage: "plus")
                }
                Button {
                    appState.createFolder(name: "New Folder")
                    // Note: ideally set parentId = folder.id — simplified for now
                } label: {
                    Label("New Subfolder", systemImage: "folder.badge.plus")
                }
                Divider()
                Button(role: .destructive) {
                    appState.deleteFolder(id: folder.id)
                } label: {
                    Label("Delete Folder", systemImage: "trash")
                }
            }
            // Accept drops of document IDs
            .dropDestination(for: String.self) { items, _ in
                guard let idStr = items.first, let id = UUID(uuidString: idStr) else { return false }
                appState.moveDocument(id, toFolder: folder.id)
                if !folder.isExpanded { appState.toggleFolderExpanded(id: folder.id) }
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: 0.15)) { isDropTarget = targeted }
            }

            // Children (when expanded)
            if folder.isExpanded {
                // Subfolders
                ForEach(appState.subfolders(of: folder.id)) { sub in
                    SidebarFolderRow(folder: sub, depth: depth + 1)
                }
                // Documents in this folder
                ForEach(appState.documents(inFolder: folder.id)) { doc in
                    SidebarDocRow(document: doc, depth: depth + 1)
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
    private var theme: AppTheme { themeManager.current }
    private var indent: CGFloat { CGFloat(depth) * 14 + 8 }
    var docType: DocumentType { DocumentType(rawValue: document.type) ?? .card }

    var body: some View {
        Button { appState.openDocument(document) } label: {
            HStack(spacing: 7) {
                // Indent spacer
                Color.clear.frame(width: indent, height: 1)

                Image(systemName: docType.icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 14)

                Text(document.title)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.trailing, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovered ? theme.panelSoft : Color.clear)
                    .padding(.horizontal, 4)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.1)) { hovered = isHovered }
        }
        .contextMenu {
            Button {
                appState.openDocument(document)
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }
            Button(role: .destructive) {
                appState.deleteDocument(id: document.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        // Drag to workspace: carry doc UUID string
        .draggable(document.id.uuidString)
    }
}

// MARK: - Icon button
struct SidebarIconBtn: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String
    let action: () -> Void
    @State private var hovered = false
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovered ? theme.panelSoft : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Filter menu
struct SidebarFilterMenu: View {
    @EnvironmentObject var themeManager: ThemeManager
    let dismiss: () -> Void
    @State private var sortMode: String = "Manual order"
    private var theme: AppTheme { themeManager.current }

    let sortOptions = ["Manual order", "Newest first", "Oldest first", "Alphabetical"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuSection("DOCUMENT TYPES") {
                ForEach(DocumentType.allCases) { type in
                    menuRow(icon: type.icon, label: type.rawValue + "s")
                }
            }
            Divider().background(theme.border)
            menuSection("SORT BY") {
                ForEach(sortOptions, id: \.self) { opt in
                    Button {
                        sortMode = opt
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sortMode == opt ? "checkmark" : "")
                                .font(.system(size: 10))
                                .foregroundColor(theme.accent)
                                .frame(width: 12)
                            Text(opt)
                                .font(.system(size: 11))
                                .foregroundColor(theme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.09, green: 0.08, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.border, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 6)
    }

    private func menuSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .tracking(0.7)
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
            content()
        }
    }

    private func menuRow(icon: String, label: String) -> some View {
        Button { } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 11))
                    .foregroundColor(theme.textSecondary).frame(width: 16)
                Text(label).font(.system(size: 11)).foregroundColor(theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
