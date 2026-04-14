//
//  PlaceholderWorkspaces.swift
//  Nexus - Phase 5
//
//  Wiki and Quill views
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

            // Document list - scoped to current world
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if !appState.currentWorldDocuments.isEmpty {
                        Text("PAGES")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.black.opacity(0.3))
                            .tracking(0.8)
                            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)

                        let filtered = searchText.isEmpty
                            ? appState.currentWorldDocuments
                            : appState.currentWorldDocuments.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

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
        appState.currentWorldDocuments.filter { $0.type == DocumentType.card.rawValue }
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

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.35))
                    TextField("Search cards...", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.05))
                )
                .padding(24)

                // Cards grid
                if shown.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 34, weight: .light))
                            .foregroundColor(.black.opacity(0.25))
                        Text("No cards found")
                            .font(.system(size: 13))
                            .foregroundColor(.black.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                        ForEach(shown) { doc in
                            WikiCardTile(doc: doc) { onSelect(doc) }
                        }
                    }
                    .padding(24)
                }

                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Wiki card tile
struct WikiCardTile: View {
    let doc: StudyDocument
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.5))
                    Spacer()
                }
                Text(doc.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !doc.content.isEmpty {
                    Text(doc.content.prefix(100))
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.5))
                        .lineLimit(3)
                }

                Spacer()
            }
            .padding(14)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(hovered ? 0.12 : 0.06), radius: hovered ? 12 : 6, x: 0, y: 2)
            .scaleEffect(hovered ? 1.01 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Article view
struct WikiArticleView: View {
    let document: StudyDocument
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.black.opacity(0.6))
                }
                .padding(.bottom, 8)

                Text(document.title)
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(.black.opacity(0.85))

                Divider()

                if !document.content.isEmpty {
                    Text(document.content)
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.75))
                        .lineSpacing(5)
                } else {
                    Text("No content yet.")
                        .font(.system(size: 14))
                        .foregroundColor(.black.opacity(0.45))
                        .italic()
                }

                Spacer(minLength: 40)
            }
            .padding(28)
        }
    }
}
