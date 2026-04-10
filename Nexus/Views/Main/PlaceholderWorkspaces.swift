//
//  PlaceholderWorkspaces.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//


import SwiftUI

// MARK: - Shared placeholder
struct PlaceholderWorkspaceView: View {
    let icon: String; let title: String; let description: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 36, weight: .ultraLight)).foregroundColor(.white.opacity(0.16))
            Text(title).font(.system(size: 17, weight: .light)).foregroundColor(.white.opacity(0.36))
            Text(description).font(.system(size: 12)).foregroundColor(.white.opacity(0.22))
                .multilineTextAlignment(.center).frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Quill
struct QuillView: View {
    @EnvironmentObject var appState: AppState
    @State private var text = ""
    @State private var bold = false
    @State private var italic = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Spacer()
                FmtBtn("B", .system(size: 13, weight: .bold), active: bold)   { bold.toggle()   }
                FmtBtn("I", .system(size: 13).italic(),       active: italic) { italic.toggle() }
                Divider().frame(height: 16).opacity(0.25)
                Button("Save as Note") {
                    let firstLine = text.components(separatedBy: "\n").first ?? "Untitled"
                    appState.createDocument(title: firstLine.isEmpty ? "Untitled Note" : firstLine, type: .note)
                }
                .font(.system(size: 11, weight: .medium)).foregroundColor(.black)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.85)))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28).padding(.vertical, 10)
            .background(Color.black.opacity(0.2))
            .overlay(Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1), alignment: .bottom)

            ScrollView {
                TextEditor(text: $text)
                    .font(.system(size: 15, weight: bold ? .bold : .regular).italic(italic))
                    .foregroundColor(.white.opacity(0.85))
                    .scrollContentBackground(.hidden).background(Color.clear)
                    .frame(minHeight: 500).focused($focused)
            }
            .frame(maxWidth: 680).frame(maxWidth: .infinity).padding(.top, 36)
        }
        .onAppear { focused = true }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FmtBtn: View {
    let label: String; let font: Font; let active: Bool; let action: () -> Void
    init(_ l: String, _ f: Font, active: Bool, action: @escaping () -> Void) {
        label = l; font = f; self.active = active; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(label).font(font)
                .foregroundColor(active ? .white : .white.opacity(0.35))
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(active ? Color.white.opacity(0.11) : Color.clear))
        }.buttonStyle(.plain)
    }
}

// MARK: - Wiki
struct WikiView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedDoc: StudyDocument? = nil
    @State private var searchText = ""
    @State private var showSearch = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        HStack(spacing: 0) {
            // Left nav panel
            wikiSidebar
                .frame(width: 220)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Color.black.opacity(0.08)).frame(width: 1)
                }

            // Main content
            if let doc = selectedDoc {
                WikiArticleView(document: doc, onBack: { selectedDoc = nil })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WikiLandingView(onSelect: { selectedDoc = $0 })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Left sidebar
    private var wikiSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // World title
            HStack(spacing: 8) {
                if let world = appState.currentWorld {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.08))
                            .frame(width: 28, height: 28)
                        Text(String(world.name.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black.opacity(0.7))
                    }
                    Text(world.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10)).foregroundColor(.black.opacity(0.3))
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain).font(.system(size: 11))
                    .foregroundColor(.black.opacity(0.7))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
            .padding(.horizontal, 10).padding(.bottom, 8)

            Divider()

            // Document list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if !appState.documents.isEmpty {
                        Text("PAGES")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.black.opacity(0.3))
                            .tracking(0.8)
                            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                        let filtered = searchText.isEmpty
                            ? appState.documents
                            : appState.documents.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

                        ForEach(filtered) { doc in
                            WikiSidebarRow(
                                doc: doc,
                                isSelected: selectedDoc?.id == doc.id,
                                onTap: { selectedDoc = doc }
                            )
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Sidebar row
struct WikiSidebarRow: View {
    let doc: StudyDocument
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hovered = false
    var dtype: DocumentType { DocumentType(rawValue: doc.type) ?? .card }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: dtype.icon)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .black.opacity(0.7) : .black.opacity(0.3))
                    .frame(width: 14)
                Text(doc.title)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .black.opacity(0.85) : .black.opacity(0.55))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected
                        ? Color.black.opacity(0.07)
                        : (hovered ? Color.black.opacity(0.04) : Color.clear))
            )
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Landing page (no doc selected)
struct WikiLandingView: View {
    @EnvironmentObject var appState: AppState
    let onSelect: (StudyDocument) -> Void
    @State private var search = ""

    var cards: [StudyDocument] {
        appState.documents.filter { $0.type == DocumentType.card.rawValue }
    }

    var shown: [StudyDocument] {
        search.isEmpty ? cards : cards.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // Banner area
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 160)

                    VStack(alignment: .leading, spacing: 4) {
                        if let world = appState.currentWorld {
                            Text(world.name)
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(.black.opacity(0.82))
                            if !world.genre.isEmpty {
                                Text(world.genre)
                                    .font(.system(size: 13))
                                    .foregroundColor(.black.opacity(0.4))
                            }
                        }
                    }
                    .padding(24)
                }

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13)).foregroundColor(.black.opacity(0.35))
                    TextField("Search through \(appState.currentWorld?.name ?? "wiki")...", text: $search)
                        .textFieldStyle(.plain).font(.system(size: 13))
                        .foregroundColor(.black.opacity(0.75))
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1))
                )
                .padding(24)

                if appState.documents.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundColor(.black.opacity(0.15))
                        Text("No cards to display")
                            .font(.system(size: 14))
                            .foregroundColor(.black.opacity(0.35))
                        Text("Create cards in World to populate the wiki.")
                            .font(.system(size: 12))
                            .foregroundColor(.black.opacity(0.25))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    // Cards grid
                    VStack(alignment: .leading, spacing: 12) {
                        if !search.isEmpty {
                            Text("Results for: \(search)")
                                .font(.system(size: 11))
                                .foregroundColor(.black.opacity(0.4))
                                .padding(.horizontal, 24)
                        }

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                            spacing: 12
                        ) {
                            ForEach(shown) { doc in
                                WikiGridCard(doc: doc, onTap: { onSelect(doc) })
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color.white)
    }
}

// MARK: - Grid card on the landing page
struct WikiGridCard: View {
    let doc: StudyDocument
    let onTap: () -> Void
    @State private var hovered = false
    var dtype: DocumentType { DocumentType(rawValue: doc.type) ?? .card }

    // Try to parse cover image from card blocks if present
    var previewText: String {
        if let data = doc.content.data(using: .utf8),
           let blocks = try? JSONDecoder().decode([CardBlock].self, from: data) {
            let textBlocks = blocks.filter { $0.type == .text || $0.type == .heading }
            return textBlocks.first(where: { !$0.content.isEmpty })?.content ?? ""
        }
        return doc.content
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image placeholder / header
                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(hovered ? 0.07 : 0.04))
                        .frame(height: 100)
                    Image(systemName: dtype.icon)
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundColor(.black.opacity(0.18))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(doc.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black.opacity(0.8))
                        .lineLimit(1)

                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(.system(size: 10))
                            .foregroundColor(.black.opacity(0.45))
                            .lineLimit(2)
                    } else {
                        Text(dtype.rawValue)
                            .font(.system(size: 10))
                            .foregroundColor(.black.opacity(0.3))
                    }
                }
                .padding(10)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(hovered ? 0.15 : 0.09), lineWidth: 1)
            )
            .shadow(color: .black.opacity(hovered ? 0.06 : 0.02), radius: hovered ? 8 : 2, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(hovered ? 1.01 : 1)
        .animation(.spring(response: 0.2), value: hovered)
        .onHover { hovered = $0 }
    }
}

// MARK: - Full article view
struct WikiArticleView: View {
    @EnvironmentObject var appState: AppState
    let document: StudyDocument
    let onBack: () -> Void

    var dtype: DocumentType { DocumentType(rawValue: document.type) ?? .card }

    var blocks: [CardBlock] {
        if let data = document.content.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([CardBlock].self, from: data) {
            return decoded
        }
        return []
    }

    // Related documents (same type, different id)
    var related: [StudyDocument] {
        appState.documents.filter { $0.id != document.id && $0.type == document.type }.prefix(4).map { $0 }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Main article column
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Top breadcrumb
                    HStack(spacing: 6) {
                        Button(action: onBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left").font(.system(size: 10))
                                Text(appState.currentWorld?.name ?? "Wiki")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.black.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundColor(.black.opacity(0.25))
                        Text(document.title).font(.system(size: 11)).foregroundColor(.black.opacity(0.5))
                    }
                    .padding(.horizontal, 36).padding(.top, 24).padding(.bottom, 20)

                    Divider().padding(.horizontal, 36)

                    // Title
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(document.title)
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundColor(.black.opacity(0.85))

                            HStack(spacing: 6) {
                                Image(systemName: dtype.icon)
                                    .font(.system(size: 10)).foregroundColor(.black.opacity(0.35))
                                Text(dtype.rawValue)
                                    .font(.system(size: 11))
                                    .foregroundColor(.black.opacity(0.4))
                                Text("·")
                                    .foregroundColor(.black.opacity(0.2))
                                Text(document.updatedAt, style: .date)
                                    .font(.system(size: 11))
                                    .foregroundColor(.black.opacity(0.3))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 36).padding(.top, 20).padding(.bottom, 16)

                    Divider().padding(.horizontal, 36)

                    // Article body
                    VStack(alignment: .leading, spacing: 0) {
                        if blocks.isEmpty {
                            Text("This page has no content yet.")
                                .font(.system(size: 14))
                                .foregroundColor(.black.opacity(0.35))
                                .italic()
                                .padding(.top, 24)
                        } else {
                            ForEach(blocks) { block in
                                WikiBlockView(block: block)
                            }
                        }
                    }
                    .padding(.horizontal, 36).padding(.vertical, 20)
                }
            }

            // Right info panel
            VStack(alignment: .leading, spacing: 0) {
                // Info box header
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 36)
                    .overlay(
                        Text(dtype.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.black.opacity(0.6))
                            .padding(.horizontal, 14),
                        alignment: .leading
                    )

                Divider()

                VStack(alignment: .leading, spacing: 0) {
                    infoRow("Type", dtype.rawValue)
                    infoRow("Created", document.createdAt.formatted(date: .abbreviated, time: .omitted))
                    infoRow("Updated", document.updatedAt.formatted(date: .abbreviated, time: .omitted))
                }

                if !related.isEmpty {
                    Divider().padding(.top, 8)
                    Text("RELATED")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.black.opacity(0.3))
                        .tracking(0.7)
                        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)

                    ForEach(related) { rel in
                        Button {
                            // handled by WikiView's selectedDoc binding via onBack + re-select
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: dtype.icon)
                                    .font(.system(size: 9)).foregroundColor(.black.opacity(0.3))
                                Text(rel.title)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.blue.opacity(0.7))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .frame(width: 200)
            .background(Color.black.opacity(0.02))
            .overlay(alignment: .leading) {
                Rectangle().fill(Color.black.opacity(0.08)).frame(width: 1)
            }
        }
        .background(Color.white)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.black.opacity(0.45))
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.system(size: 10))
                .foregroundColor(.black.opacity(0.6))
        }
        .padding(.horizontal, 14).padding(.vertical, 5)
    }
}

// MARK: - Block renderer (read-only)
struct WikiBlockView: View {
    let block: CardBlock

    var body: some View {
        switch block.type {
        case .heading:
            Text(block.content)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(.black.opacity(0.82))
                .padding(.top, 20).padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .text:
            Text(block.content)
                .font(.system(size: 14))
                .foregroundColor(.black.opacity(0.72))
                .lineSpacing(5)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .divider:
            Divider()
                .padding(.vertical, 12)
        }
    }
}

// MARK: - Echo
struct EchoView: View {
    @EnvironmentObject var appState: AppState
    var cards: [StudyDocument] { appState.documents.filter { $0.type == DocumentType.card.rawValue } }

    var body: some View {
        if cards.isEmpty {
            PlaceholderWorkspaceView(icon: "waveform", title: "Echo",
                description: "Spaced repetition for your study cards.\nCreate cards in World first, then review them here.")
        } else {
            VStack(spacing: 20) {
                Spacer()
                Text("Review Queue")
                    .font(.system(size: 20, weight: .light, design: .serif)).foregroundColor(.white.opacity(0.72))
                Text("\(cards.count) card\(cards.count == 1 ? "" : "s") available")
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.32))

                ZStack {
                    ForEach(Array(cards.prefix(3).enumerated()), id: \.element.id) { i, doc in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(doc.title).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.78))
                        }
                        .padding(20).frame(width: 290, height: 170, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.55))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1)))
                        .offset(x: CGFloat(i * 5), y: CGFloat(i * 5))
                        .zIndex(Double(3 - i))
                    }
                }
                .frame(height: 185)

                HStack(spacing: 12) {
                    Button("Start Session") {}.buttonStyle(PrimaryButtonStyle())
                    Button("Manage Decks")  {}.buttonStyle(SecondaryButtonStyle())
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Home
struct HomeView: View {
    @EnvironmentObject var appState: AppState
    let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back\(appState.user.map { ", \($0.username)" } ?? "")")
                        .font(.system(size: 22, weight: .light, design: .serif)).foregroundColor(.white.opacity(0.84))
                    Text("Where will your imagination take you today?")
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.32))
                }
                .padding(.top, 4)

                if appState.recentItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 30, weight: .ultraLight)).foregroundColor(.white.opacity(0.14))
                        Text("No recent items yet").font(.system(size: 12)).foregroundColor(.white.opacity(0.26))
                        Text("Create your first card in the World workspace")
                            .font(.system(size: 10)).foregroundColor(.white.opacity(0.18))
                    }
                    .frame(maxWidth: .infinity).padding(.top, 50)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RECENTLY OPENED")
                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.26)).tracking(0.9)
                        LazyVGrid(columns: cols, spacing: 11) {
                            ForEach(appState.recentItems) { item in RecentTile(item: item) }
                        }
                    }
                }

                if !appState.documents.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("WORLD AT A GLANCE")
                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.26)).tracking(0.9)
                        HStack(spacing: 8) {
                            ForEach(DocumentType.allCases) { t in
                                let n = appState.documents.filter { $0.type == t.rawValue }.count
                                if n > 0 {
                                    HStack(spacing: 5) {
                                        Image(systemName: t.icon).font(.system(size: 10)).foregroundColor(.white.opacity(0.38))
                                        Text("\(n) \(t.rawValue)\(n == 1 ? "" : "s")")
                                            .font(.system(size: 10)).foregroundColor(.white.opacity(0.52))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 7)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.07), lineWidth: 1)))
                                }
                            }
                        }
                    }
                }
            }
            .padding(30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct RecentTile: View {
    @EnvironmentObject var appState: AppState
    let item: StudyDocument
    @State private var hovered = false
    var dtype: DocumentType { DocumentType(rawValue: item.type) ?? .card }

    var body: some View {
        Button { appState.openDocument(item) } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.04))
                    Image(systemName: dtype.icon)
                        .font(.system(size: 20, weight: .ultraLight)).foregroundColor(.white.opacity(0.16))
                }
                .frame(height: 68)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.7)).lineLimit(1)
                    Text(item.type).font(.system(size: 8)).foregroundColor(.white.opacity(0.26))
                }
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(hovered ? 0.07 : 0.04))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.06), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .scaleEffect(hovered ? 1.02 : 1).animation(.spring(response: 0.2), value: hovered)
        .onHover { hovered = $0 }
    }
}






//import SwiftUI
//
//// MARK: - Shared placeholder
//struct PlaceholderWorkspaceView: View {
//    let icon: String; let title: String; let description: String
//    var body: some View {
//        VStack(spacing: 14) {
//            Image(systemName: icon).font(.system(size: 36, weight: .ultraLight)).foregroundColor(.white.opacity(0.16))
//            Text(title).font(.system(size: 17, weight: .light)).foregroundColor(.white.opacity(0.36))
//            Text(description).font(.system(size: 12)).foregroundColor(.white.opacity(0.22))
//                .multilineTextAlignment(.center).frame(maxWidth: 300)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
//
//// MARK: - Quill
//struct QuillView: View {
//    @EnvironmentObject var appState: AppState
//    @State private var text = ""
//    @State private var bold = false
//    @State private var italic = false
//    @FocusState private var focused: Bool
//
//    var body: some View {
//        VStack(spacing: 0) {
//            HStack(spacing: 8) {
//                Spacer()
//                FmtBtn("B", .system(size: 13, weight: .bold), active: bold)   { bold.toggle()   }
//                FmtBtn("I", .system(size: 13).italic(),       active: italic) { italic.toggle() }
//                Divider().frame(height: 16).opacity(0.25)
//                Button("Save as Note") {
//                    let firstLine = text.components(separatedBy: "\n").first ?? "Untitled"
//                    appState.createDocument(title: firstLine.isEmpty ? "Untitled Note" : firstLine, type: .note)
//                }
//                .font(.system(size: 11, weight: .medium)).foregroundColor(.black)
//                .padding(.horizontal, 14).padding(.vertical, 6)
//                .background(Capsule().fill(Color.white.opacity(0.85)))
//                .buttonStyle(.plain)
//            }
//            .padding(.horizontal, 28).padding(.vertical, 10)
//            .background(Color.black.opacity(0.2))
//            .overlay(Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1), alignment: .bottom)
//
//            ScrollView {
//                TextEditor(text: $text)
//                    .font(.system(size: 15, weight: bold ? .bold : .regular).italic(italic))
//                    .foregroundColor(.white.opacity(0.85))
//                    .scrollContentBackground(.hidden).background(Color.clear)
//                    .frame(minHeight: 500).focused($focused)
//            }
//            .frame(maxWidth: 680).frame(maxWidth: .infinity).padding(.top, 36)
//        }
//        .onAppear { focused = true }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
//
//private struct FmtBtn: View {
//    let label: String; let font: Font; let active: Bool; let action: () -> Void
//    init(_ l: String, _ f: Font, active: Bool, action: @escaping () -> Void) {
//        label = l; font = f; self.active = active; self.action = action
//    }
//    var body: some View {
//        Button(action: action) {
//            Text(label).font(font)
//                .foregroundColor(active ? .white : .white.opacity(0.35))
//                .frame(width: 26, height: 26)
//                .background(RoundedRectangle(cornerRadius: 6).fill(active ? Color.white.opacity(0.11) : Color.clear))
//        }.buttonStyle(.plain)
//    }
//}
//
//// MARK: - Wiki
//struct WikiView: View {
//    @EnvironmentObject var appState: AppState
//    @State private var search = ""
//
//    var shown: [StudyDocument] {
//        search.isEmpty ? appState.documents
//        : appState.documents.filter { $0.title.localizedCaseInsensitiveContains(search) }
//    }
//
//    var body: some View {
//        if appState.documents.isEmpty {
//            PlaceholderWorkspaceView(icon: "book.closed.fill", title: "Wiki",
//                description: "Every card, concept & connection — organized as a wiki.\nCreate documents in World to populate this space.")
//        } else {
//            VStack(spacing: 0) {
//                HStack(spacing: 9) {
//                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(.white.opacity(0.32))
//                    TextField("Search wiki...", text: $search)
//                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
//                }
//                .padding(.horizontal, 14).padding(.vertical, 10)
//                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06))
//                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.1), lineWidth: 1)))
//                .frame(maxWidth: 560).padding(.top, 22).padding(.bottom, 18)
//
//                ScrollView {
//                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3), spacing: 11) {
//                        ForEach(shown) { doc in WikiCard(doc: doc) }
//                    }
//                    .frame(maxWidth: 860).padding(.horizontal, 22)
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
//    }
//}
//
//struct WikiCard: View {
//    @EnvironmentObject var appState: AppState
//    let doc: StudyDocument
//    @State private var hovered = false
//    var dtype: DocumentType { DocumentType(rawValue: doc.type) ?? .card }
//
//    var body: some View {
//        Button { appState.openDocument(doc) } label: {
//            VStack(alignment: .leading, spacing: 8) {
//                HStack(spacing: 6) {
//                    Image(systemName: dtype.icon).font(.system(size: 10)).foregroundColor(.white.opacity(0.35))
//                    Text(dtype.rawValue).font(.system(size: 9, weight: .semibold))
//                        .foregroundColor(.white.opacity(0.25)).tracking(0.5)
//                    Spacer()
//                    Text(doc.updatedAt, style: .date).font(.system(size: 8)).foregroundColor(.white.opacity(0.2))
//                }
//                Text(doc.title).font(.system(size: 12, weight: .medium))
//                    .foregroundColor(.white.opacity(0.8)).lineLimit(2)
//                if !doc.content.isEmpty {
//                    Text(doc.content).font(.system(size: 10)).foregroundColor(.white.opacity(0.35)).lineLimit(3)
//                }
//                Spacer()
//            }
//            .padding(12)
//            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
//            .background(RoundedRectangle(cornerRadius: 11)
//                .fill(Color.white.opacity(hovered ? 0.07 : 0.04))
//                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.07), lineWidth: 1)))
//        }
//        .buttonStyle(.plain)
//        .scaleEffect(hovered ? 1.02 : 1).animation(.spring(response: 0.2), value: hovered)
//        .onHover { hovered = $0 }
//    }
//}
//
//// MARK: - Echo
//struct EchoView: View {
//    @EnvironmentObject var appState: AppState
//    var cards: [StudyDocument] { appState.documents.filter { $0.type == DocumentType.card.rawValue } }
//
//    var body: some View {
//        if cards.isEmpty {
//            PlaceholderWorkspaceView(icon: "waveform", title: "Echo",
//                description: "Spaced repetition for your study cards.\nCreate cards in World first, then review them here.")
//        } else {
//            VStack(spacing: 20) {
//                Spacer()
//                Text("Review Queue")
//                    .font(.system(size: 20, weight: .light, design: .serif)).foregroundColor(.white.opacity(0.72))
//                Text("\(cards.count) card\(cards.count == 1 ? "" : "s") available")
//                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.32))
//
//                ZStack {
//                    ForEach(Array(cards.prefix(3).enumerated()), id: \.element.id) { i, doc in
//                        VStack(alignment: .leading, spacing: 8) {
//                            Text(doc.title).font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.78))
//                        }
//                        .padding(20).frame(width: 290, height: 170, alignment: .topLeading)
//                        .background(RoundedRectangle(cornerRadius: 16)
//                            .fill(Color.black.opacity(0.55))
//                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1)))
//                        .offset(x: CGFloat(i * 5), y: CGFloat(i * 5))
//                        .zIndex(Double(3 - i))
//                    }
//                }
//                .frame(height: 185)
//
//                HStack(spacing: 12) {
//                    Button("Start Session") {}.buttonStyle(PrimaryButtonStyle())
//                    Button("Manage Decks")  {}.buttonStyle(SecondaryButtonStyle())
//                }
//                Spacer()
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//        }
//    }
//}
//
//// MARK: - Home
//struct HomeView: View {
//    @EnvironmentObject var appState: AppState
//    let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 30) {
//                VStack(alignment: .leading, spacing: 4) {
//                    Text("Welcome back\(appState.user.map { ", \($0.username)" } ?? "")")
//                        .font(.system(size: 22, weight: .light, design: .serif)).foregroundColor(.white.opacity(0.84))
//                    Text("Where will your imagination take you today?")
//                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.32))
//                }
//                .padding(.top, 4)
//
//                if appState.recentItems.isEmpty {
//                    VStack(spacing: 10) {
//                        Image(systemName: "clock.arrow.circlepath")
//                            .font(.system(size: 30, weight: .ultraLight)).foregroundColor(.white.opacity(0.14))
//                        Text("No recent items yet").font(.system(size: 12)).foregroundColor(.white.opacity(0.26))
//                        Text("Create your first card in the World workspace")
//                            .font(.system(size: 10)).foregroundColor(.white.opacity(0.18))
//                    }
//                    .frame(maxWidth: .infinity).padding(.top, 50)
//                } else {
//                    VStack(alignment: .leading, spacing: 12) {
//                        Text("RECENTLY OPENED")
//                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.26)).tracking(0.9)
//                        LazyVGrid(columns: cols, spacing: 11) {
//                            ForEach(appState.recentItems) { item in RecentTile(item: item) }
//                        }
//                    }
//                }
//
//                if !appState.documents.isEmpty {
//                    VStack(alignment: .leading, spacing: 10) {
//                        Text("WORLD AT A GLANCE")
//                            .font(.system(size: 9, weight: .semibold)).foregroundColor(.white.opacity(0.26)).tracking(0.9)
//                        HStack(spacing: 8) {
//                            ForEach(DocumentType.allCases) { t in
//                                let n = appState.documents.filter { $0.type == t.rawValue }.count
//                                if n > 0 {
//                                    HStack(spacing: 5) {
//                                        Image(systemName: t.icon).font(.system(size: 10)).foregroundColor(.white.opacity(0.38))
//                                        Text("\(n) \(t.rawValue)\(n == 1 ? "" : "s")")
//                                            .font(.system(size: 10)).foregroundColor(.white.opacity(0.52))
//                                    }
//                                    .padding(.horizontal, 10).padding(.vertical, 6)
//                                    .background(RoundedRectangle(cornerRadius: 7)
//                                        .fill(Color.white.opacity(0.05))
//                                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.07), lineWidth: 1)))
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//            .padding(30)
//        }
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//    }
//}
//
//struct RecentTile: View {
//    @EnvironmentObject var appState: AppState
//    let item: StudyDocument
//    @State private var hovered = false
//    var dtype: DocumentType { DocumentType(rawValue: item.type) ?? .card }
//
//    var body: some View {
//        Button { appState.openDocument(item) } label: {
//            VStack(alignment: .leading, spacing: 7) {
//                ZStack {
//                    RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.04))
//                    Image(systemName: dtype.icon)
//                        .font(.system(size: 20, weight: .ultraLight)).foregroundColor(.white.opacity(0.16))
//                }
//                .frame(height: 68)
//                VStack(alignment: .leading, spacing: 1) {
//                    Text(item.title).font(.system(size: 10, weight: .medium))
//                        .foregroundColor(.white.opacity(0.7)).lineLimit(1)
//                    Text(item.type).font(.system(size: 8)).foregroundColor(.white.opacity(0.26))
//                }
//            }
//            .padding(9)
//            .background(RoundedRectangle(cornerRadius: 9)
//                .fill(Color.white.opacity(hovered ? 0.07 : 0.04))
//                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.06), lineWidth: 1)))
//        }
//        .buttonStyle(.plain)
//        .scaleEffect(hovered ? 1.02 : 1).animation(.spring(response: 0.2), value: hovered)
//        .onHover { hovered = $0 }
//    }
//}
