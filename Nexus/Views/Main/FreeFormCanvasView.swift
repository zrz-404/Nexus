//
//  FreeFormCanvasView.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

// MARK: - Canvas tile model
struct CanvasTile: Identifiable, Codable {
    var id: UUID = UUID()
    var documentId: UUID
    var title: String
    var type: String
    var x: Double = 100
    var y: Double = 100
    var width: Double = 260
    var height: Double = 160
}

// MARK: - Free-form canvas view
struct FreeformCanvasView: View {
    @EnvironmentObject var appState: AppState
    let canvasDocumentId: UUID

    @State private var tiles: [CanvasTile] = []
    @State private var panOffset: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var zoom: CGFloat = 1.0
    @State private var showDocPicker = false
    @State private var selectedTileId: UUID? = nil

    var body: some View {
        ZStack {
            CanvasGrid()
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { v in
                            panOffset = CGSize(width: lastPan.width + v.translation.width,
                                              height: lastPan.height + v.translation.height)
                        }
                        .onEnded { _ in lastPan = panOffset }
                )
                .gesture(MagnifyGesture().onChanged { v in
                    zoom = max(0.25, min(3, v.magnification))
                })
                .onTapGesture { selectedTileId = nil }

            // Tiles
            ForEach($tiles) { $tile in
                CanvasTileView(
                    tile: $tile,
                    isSelected: selectedTileId == tile.id,
                    onSelect: { selectedTileId = tile.id },
                    onOpen: {
                        if let doc = appState.documents.first(where: { $0.id == tile.documentId }) {
                            appState.openDocument(doc)
                        }
                    },
                    onRemove: { removeTile(tile.id) }
                )
                .offset(
                    x: tile.x * zoom + panOffset.width,
                    y: tile.y * zoom + panOffset.height
                )
                .scaleEffect(zoom, anchor: .topLeading)
            }

            // Bottom toolbar
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    GraphBtn(icon: "plus",  tip: "Add document") { showDocPicker = true }
                    Divider().frame(height: 16).opacity(0.25)
                    GraphBtn(icon: "minus", tip: "Zoom out") { withAnimation { zoom = max(0.25, zoom - 0.2) } }
                    GraphBtn(icon: "plus.magnifyingglass", tip: "Zoom in") { withAnimation { zoom = min(3, zoom + 0.2) } }
                    GraphBtn(icon: "arrow.up.left.and.down.right.magnifyingglass", tip: "Reset") {
                        withAnimation(.spring(response: 0.4)) { zoom = 1; panOffset = .zero; lastPan = .zero }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.55))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
                .padding(.bottom, 14)
            }
        }
        .onAppear { loadTiles() }
        .sheet(isPresented: $showDocPicker) {
            CanvasDocPickerSheet { doc in addTile(for: doc) }
        }
    }

    // MARK: - Tile management
    private func addTile(for doc: StudyDocument) {
        let existingCount = tiles.count
        let tile = CanvasTile(
            documentId: doc.id,
            title: doc.title,
            type: doc.type,
            x: Double(100 + existingCount * 30),
            y: Double(100 + existingCount * 30)
        )
        withAnimation(.spring(response: 0.35)) { tiles.append(tile) }
        saveTiles()
    }

    private func removeTile(_ id: UUID) {
        withAnimation(.spring(response: 0.3)) { tiles.removeAll { $0.id == id } }
        saveTiles()
    }

    // MARK: - Persistence (stored in the canvas document's content field)
    private func saveTiles() {
        if let data = try? JSONEncoder().encode(tiles),
           let json = String(data: data, encoding: .utf8) {
            appState.updateDocumentContent(id: canvasDocumentId, content: json)
        }
    }

    private func loadTiles() {
        guard let doc = appState.documents.first(where: { $0.id == canvasDocumentId }),
              !doc.content.isEmpty,
              let data = doc.content.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([CanvasTile].self, from: data)
        else { return }
        tiles = decoded
    }
}

// MARK: - Single draggable tile
struct CanvasTileView: View {
    @Binding var tile: CanvasTile
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void

    @State private var dragStart: CGPoint = .zero
    @State private var hovered = false
    var dtype: DocumentType { DocumentType(rawValue: tile.type) ?? .card }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title bar
            HStack(spacing: 6) {
                Image(systemName: dtype.icon).font(.system(size: 9)).foregroundColor(.white.opacity(0.35))
                Text(tile.title).font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.65)).lineLimit(1)
                Spacer()
                if hovered || isSelected {
                    HStack(spacing: 4) {
                        Button(action: onOpen) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 9)).foregroundColor(.white.opacity(0.4))
                        }.buttonStyle(.plain)
                        Button(action: onRemove) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8)).foregroundColor(.white.opacity(0.35))
                                .frame(width: 14, height: 14).background(Circle().fill(Color.white.opacity(0.06)))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.black.opacity(0.35))

            // Content preview
            ZStack {
                Color.white.opacity(0.02)
                if tile.type == DocumentType.connections.rawValue {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 22, weight: .ultraLight)).foregroundColor(.white.opacity(0.1))
                } else if tile.type == DocumentType.mindmap.rawValue {
                    Image(systemName: "circle.hexagongrid")
                        .font(.system(size: 22, weight: .ultraLight)).foregroundColor(.white.opacity(0.1))
                } else {
                    Text("Open to edit")
                        .font(.system(size: 9)).foregroundColor(.white.opacity(0.14))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: tile.width, height: tile.height)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1))
        )
        .shadow(color: isSelected ? .white.opacity(0.08) : .clear, radius: 14)
        .scaleEffect(isSelected ? 1.01 : 1)
        .animation(.spring(response: 0.22), value: isSelected)
        .onTapGesture { onSelect() }
        .onHover { hovered = $0 }
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { v in
                    if dragStart == .zero { dragStart = CGPoint(x: tile.x, y: tile.y) }
                    tile.x = dragStart.x + v.translation.width
                    tile.y = dragStart.y + v.translation.height
                }
                .onEnded { _ in dragStart = .zero }
        )
    }
}

// MARK: - Doc picker sheet
struct CanvasDocPickerSheet: View {
    @EnvironmentObject var appState: AppState
    let onPick: (StudyDocument) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var filtered: [StudyDocument] {
        search.isEmpty ? appState.documents
        : appState.documents.filter { $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Add to Canvas").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 11)).foregroundColor(.white.opacity(0.4))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)

            // Search
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundColor(.white.opacity(0.28))
                TextField("Search documents...", text: $search).textFieldStyle(.plain)
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06)))
            .padding(.horizontal, 18).padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.07))

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text").font(.system(size: 28, weight: .ultraLight)).foregroundColor(.white.opacity(0.14))
                    Text("No documents yet").font(.system(size: 12)).foregroundColor(.white.opacity(0.28))
                    Text("Create cards in World first").font(.system(size: 10)).foregroundColor(.white.opacity(0.18))
                }
                .frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filtered) { doc in
                            let dtype = DocumentType(rawValue: doc.type) ?? .card
                            Button {
                                onPick(doc)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: dtype.icon).font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.35)).frame(width: 18)
                                    Text(doc.title).font(.system(size: 12)).foregroundColor(.white.opacity(0.75))
                                    Spacer()
                                    Text(dtype.rawValue).font(.system(size: 9))
                                        .foregroundColor(.white.opacity(0.28))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(Color.white.opacity(0.06)))
                                }
                                .padding(.horizontal, 18).padding(.vertical, 9)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 380, height: 420)
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .preferredColorScheme(.dark)
    }
}
