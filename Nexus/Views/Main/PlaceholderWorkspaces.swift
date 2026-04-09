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
    @State private var search = ""

    var shown: [StudyDocument] {
        search.isEmpty ? appState.documents
        : appState.documents.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        if appState.documents.isEmpty {
            PlaceholderWorkspaceView(icon: "book.closed.fill", title: "Wiki",
                description: "Every card, concept & connection — organized as a wiki.\nCreate documents in World to populate this space.")
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundColor(.white.opacity(0.32))
                    TextField("Search wiki...", text: $search)
                        .textFieldStyle(.plain).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.1), lineWidth: 1)))
                .frame(maxWidth: 560).padding(.top, 22).padding(.bottom, 18)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 11), count: 3), spacing: 11) {
                        ForEach(shown) { doc in WikiCard(doc: doc) }
                    }
                    .frame(maxWidth: 860).padding(.horizontal, 22)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct WikiCard: View {
    @EnvironmentObject var appState: AppState
    let doc: StudyDocument
    @State private var hovered = false
    var dtype: DocumentType { DocumentType(rawValue: doc.type) ?? .card }

    var body: some View {
        Button { appState.openDocument(doc) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: dtype.icon).font(.system(size: 10)).foregroundColor(.white.opacity(0.35))
                    Text(dtype.rawValue).font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25)).tracking(0.5)
                    Spacer()
                    Text(doc.updatedAt, style: .date).font(.system(size: 8)).foregroundColor(.white.opacity(0.2))
                }
                Text(doc.title).font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8)).lineLimit(2)
                if !doc.content.isEmpty {
                    Text(doc.content).font(.system(size: 10)).foregroundColor(.white.opacity(0.35)).lineLimit(3)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 11)
                .fill(Color.white.opacity(hovered ? 0.07 : 0.04))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.07), lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .scaleEffect(hovered ? 1.02 : 1).animation(.spring(response: 0.2), value: hovered)
        .onHover { hovered = $0 }
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
