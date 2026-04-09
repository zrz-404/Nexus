//
//  ConnectionsGraphView.swift
//  Nexus
//
//  Created by José Roseiro on 09/04/2026.
//

import SwiftUI

struct ConnectionsGraphView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = GraphViewModel()

    @State private var panOffset: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var zoom: CGFloat = 1.0
    @State private var selectedId: UUID? = nil
    @State private var isConnecting = false
    @State private var connectSourceId: UUID? = nil
    @State private var showAddSheet = false
    @State private var newNodeTitle = ""

    var body: some View {
        ZStack {
            CanvasGrid()

            GeometryReader { geo in
                ZStack {
                    // ── Edge drawing layer ──────────────────────────
                    Canvas { ctx, _ in
                        for edge in vm.edges {
                            guard
                                let src = vm.nodes.first(where: { $0.id == edge.sourceId }),
                                let dst = vm.nodes.first(where: { $0.id == edge.targetId })
                            else { continue }
                            var p = Path()
                            p.move(to: src.position)
                            p.addLine(to: dst.position)
                            ctx.stroke(p, with: .color(.white.opacity(0.2)),
                                       style: StrokeStyle(lineWidth: 1, lineCap: .round))
                        }
                    }
                    .allowsHitTesting(false)

                    // ── Node layer ──────────────────────────────────
                    ForEach($vm.nodes) { $node in
                        GraphNodeBubble(
                            node: $node,
                            isSelected: selectedId == node.id,
                            isConnectSource: connectSourceId == node.id
                        )
                        .position(node.position)
                        .onTapGesture {
                            if isConnecting, let src = connectSourceId, src != node.id {
                                vm.addEdge(from: src, to: node.id)
                                isConnecting = false
                                connectSourceId = nil
                            } else {
                                selectedId = selectedId == node.id ? nil : node.id
                                if isConnecting { connectSourceId = node.id }
                            }
                        }
                    }
                }
                .coordinateSpace(name: "graphCanvas")
                .scaleEffect(zoom, anchor: .center)
                .offset(panOffset)
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { v in
                            panOffset = CGSize(
                                width: lastPan.width + v.translation.width,
                                height: lastPan.height + v.translation.height
                            )
                        }
                        .onEnded { _ in lastPan = panOffset }
                )
                .gesture(
                    MagnifyGesture()
                        .onChanged { v in zoom = max(0.2, min(4, v.magnification)) }
                )
            }

            // ── Connect mode banner ─────────────────────────────
            if isConnecting {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.system(size: 11))
                        Text(connectSourceId == nil
                             ? "Tap a node to start the connection"
                             : "Now tap the destination node")
                            .font(.system(size: 12))
                        Spacer()
                        Button("Cancel") { isConnecting = false; connectSourceId = nil }
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.45))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.purple.opacity(0.18))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.purple.opacity(0.25), lineWidth: 1))
                    )
                    .padding(.horizontal, 20).padding(.top, 12)
                    Spacer()
                }
                .buttonStyle(.plain)
            }

            // ── Bottom toolbar ──────────────────────────────────
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    GraphBtn(icon: "plus",  tip: "Add Node")    { showAddSheet = true }
                    GraphBtn(icon: "link",  tip: "Connect",
                             active: isConnecting)              { isConnecting.toggle(); if !isConnecting { connectSourceId = nil } }
                    Divider().frame(height: 16).opacity(0.25)
                    GraphBtn(icon: "minus", tip: "Zoom out")    { withAnimation { zoom = max(0.2, zoom - 0.2) } }
                    GraphBtn(icon: "plus.magnifyingglass",
                             tip: "Zoom in")                    { withAnimation { zoom = min(4, zoom + 0.2) } }
                    GraphBtn(icon: "arrow.up.left.and.down.right.magnifyingglass",
                             tip: "Reset view")                 { withAnimation(.spring(response: 0.4)) { zoom = 1; panOffset = .zero; lastPan = .zero } }
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
        .onAppear { vm.populate(from: appState.documents) }
        .onChange(of: appState.documents) { vm.populate(from: appState.documents) }
        .sheet(isPresented: $showAddSheet) {
            AddNodeSheet(title: $newNodeTitle) { title, type in
                vm.addNode(title: title, type: type, at: CGPoint(x: 500, y: 380))
                appState.createDocument(title: title, type: type)
            }
        }
    }
}

// MARK: - Node bubble
struct GraphNodeBubble: View {
    @Binding var node: GraphNode
    let isSelected: Bool
    let isConnectSource: Bool
    @State private var dragStart: CGPoint = .zero

    var docType: DocumentType { DocumentType(rawValue: node.type) ?? .card }

    var border: Color {
        if isConnectSource { return .purple.opacity(0.8) }
        if isSelected      { return .white.opacity(0.6)  }
        return .white.opacity(0.12)
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.65))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(border, lineWidth: isSelected || isConnectSource ? 1.5 : 1))
                    .shadow(color: isSelected ? .white.opacity(0.12) : .clear, radius: 10)
                Image(systemName: docType.icon)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.72))
            }
            .frame(width: 42, height: 42)

            Text(node.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.52))
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(maxWidth: 72)
        }
        .gesture(
            DragGesture(coordinateSpace: .named("graphCanvas"))
                .onChanged { v in
                    if dragStart == .zero { dragStart = node.position }
                    node.x = dragStart.x + v.translation.width
                    node.y = dragStart.y + v.translation.height
                }
                .onEnded { _ in dragStart = .zero }
        )
        .scaleEffect(isSelected ? 1.08 : 1)
        .animation(.spring(response: 0.22), value: isSelected)
    }
}

// MARK: - Toolbar button
struct GraphBtn: View {
    let icon: String; let tip: String
    var active: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(active ? .white : .white.opacity(0.48))
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7)
                    .fill(active ? Color.white.opacity(0.12) : Color.clear))
        }
        .buttonStyle(.plain).help(tip)
    }
}

// MARK: - Add node sheet
struct AddNodeSheet: View {
    @Binding var title: String
    @State private var selectedType: DocumentType = .card
    let onCreate: (String, DocumentType) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Node")
                .font(.system(size: 15, weight: .semibold)).foregroundColor(.white.opacity(0.8))

            NexusTextField(placeholder: "Node title", text: $title, icon: "text.cursor")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(DocumentType.allCases) { type in
                    Button { selectedType = type } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 16, weight: .light))
                            Text(type.rawValue).font(.system(size: 10))
                        }
                        .foregroundColor(selectedType == type ? .white : .white.opacity(0.42))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(selectedType == type ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1)))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }.buttonStyle(SecondaryButtonStyle())
                Button("Create") {
                    guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    onCreate(title, selectedType); title = ""; dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24).frame(width: 360)
        .background(Color(red: 0.07, green: 0.07, blue: 0.1))
        .preferredColorScheme(.dark)
    }
}
