import SwiftUI

// MARK: - Mind map node model
struct MindNode: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var x: Double = 0
    var y: Double = 0
    var color: MindNodeColor = .default_
    var isRoot: Bool = false

    var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set { x = newValue.x; y = newValue.y }
    }
}

enum MindNodeColor: String, Codable, CaseIterable {
    case default_ = "default"
    case purple = "purple"
    case teal   = "teal"
    case coral  = "coral"
    case amber  = "amber"
    case blue   = "blue"

    func fill(for theme: AppTheme) -> Color {
        switch self {
        case .default_: return theme.panel
        case .purple:   return Color(hex: "#7F77DD").opacity(0.22)
        case .teal:     return Color(hex: "#1D9E75").opacity(0.22)
        case .coral:    return Color(hex: "#D85A30").opacity(0.22)
        case .amber:    return Color(hex: "#EF9F27").opacity(0.22)
        case .blue:     return Color(hex: "#378ADD").opacity(0.22)
        }
    }

    func stroke(for theme: AppTheme) -> Color {
        switch self {
        case .default_: return theme.border
        case .purple:   return Color(hex: "#7F77DD").opacity(0.55)
        case .teal:     return Color(hex: "#1D9E75").opacity(0.55)
        case .coral:    return Color(hex: "#D85A30").opacity(0.55)
        case .amber:    return Color(hex: "#EF9F27").opacity(0.55)
        case .blue:     return Color(hex: "#378ADD").opacity(0.55)
        }
    }

    func edgeColor() -> Color {
        switch self {
        case .default_: return Color.white.opacity(0.18)
        case .purple:   return Color(hex: "#7F77DD").opacity(0.45)
        case .teal:     return Color(hex: "#1D9E75").opacity(0.45)
        case .coral:    return Color(hex: "#D85A30").opacity(0.45)
        case .amber:    return Color(hex: "#EF9F27").opacity(0.45)
        case .blue:     return Color(hex: "#378ADD").opacity(0.45)
        }
    }
}

struct MindEdge: Identifiable, Codable {
    var id: UUID = UUID()
    var fromId: UUID
    var toId: UUID
}

// MARK: - ViewModel
class MindMapViewModel: ObservableObject {
    @Published var nodes: [MindNode] = []
    @Published var edges: [MindEdge] = []
    @Published var selectedId: UUID? = nil
    @Published var editingId: UUID? = nil
    @Published var connectingFrom: UUID? = nil

    // Load from JSON content string
    func load(from content: String) {
        guard !content.isEmpty,
              let data = content.data(using: .utf8),
              let saved = try? JSONDecoder().decode(MindMapData.self, from: data)
        else {
            if nodes.isEmpty { addRootNode() }
            return
        }
        nodes = saved.nodes
        edges = saved.edges
        if nodes.isEmpty { addRootNode() }
    }

    func encode() -> String {
        let data = MindMapData(nodes: nodes, edges: edges)
        return (try? String(data: JSONEncoder().encode(data), encoding: .utf8)) ?? ""
    }

    // MARK: Node ops
    func addRootNode() {
        var n = MindNode(text: "Central idea", x: 420, y: 300, isRoot: true)
        n.color = .purple
        nodes.append(n)
    }

    func addChild(to parentId: UUID) {
        guard let parent = nodes.first(where: { $0.id == parentId }) else { return }
        let childCount = edges.filter { $0.fromId == parentId }.count
        let angle = Double(childCount) * (Double.pi / 4) - Double.pi / 2
        let radius: Double = 160
        var child = MindNode(
            text: "New node",
            x: parent.x + cos(angle) * radius,
            y: parent.y + sin(angle) * radius
        )
        child.color = parent.color == .default_ ? .teal : parent.color
        nodes.append(child)
        edges.append(MindEdge(fromId: parentId, toId: child.id))
        selectedId = child.id
        editingId = child.id
    }

    func deleteNode(_ id: UUID) {
        // Don't delete root if it's the only node
        if nodes.count == 1 { return }
        nodes.removeAll { $0.id == id }
        edges.removeAll { $0.fromId == id || $0.toId == id }
        if selectedId == id { selectedId = nil }
        if editingId == id { editingId = nil }
    }

    func connectNodes(from: UUID, to: UUID) {
        guard from != to,
              !edges.contains(where: { $0.fromId == from && $0.toId == to }) else { return }
        edges.append(MindEdge(fromId: from, toId: to))
    }

    func updateText(_ id: UUID, text: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].text = text
    }

    func updateColor(_ id: UUID, color: MindNodeColor) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].color = color
    }
}

private struct MindMapData: Codable {
    var nodes: [MindNode]
    var edges: [MindEdge]
}

// MARK: - Main view
struct MindMapView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let document: StudyDocument

    @StateObject private var vm = MindMapViewModel()
    @State private var pan: CGSize = .zero
    @State private var lastPan: CGSize = .zero
    @State private var zoom: CGFloat = 1.0
    @State private var connectMode = false

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            CanvasGrid()
                .gesture(panGesture)
                .gesture(MagnifyGesture().onChanged { v in zoom = max(0.3, min(3, v.magnification)) })
                .onTapGesture { vm.selectedId = nil; vm.editingId = nil }

            GeometryReader { geo in
                ZStack {
                    // Edges
                    Canvas { ctx, _ in
                        for edge in vm.edges {
                            guard
                                let from = vm.nodes.first(where: { $0.id == edge.fromId }),
                                let to   = vm.nodes.first(where: { $0.id == edge.toId })
                            else { continue }

                            let p1 = transformedPoint(from.position, geo: geo)
                            let p2 = transformedPoint(to.position,   geo: geo)
                            let fromNode = from

                            var path = Path()
                            let cp1 = CGPoint(x: p1.x + (p2.x - p1.x) * 0.4, y: p1.y)
                            let cp2 = CGPoint(x: p1.x + (p2.x - p1.x) * 0.6, y: p2.y)
                            path.move(to: p1)
                            path.addCurve(to: p2, control1: cp1, control2: cp2)
                            ctx.stroke(path,
                                with: .color(fromNode.color.edgeColor()),
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        }
                    }
                    .allowsHitTesting(false)

                    // Nodes
                    ForEach($vm.nodes) { $node in
                        MindNodeView(
                            node: $node,
                            isSelected: vm.selectedId == node.id,
                            isEditing: vm.editingId == node.id,
                            isConnectSource: vm.connectingFrom == node.id,
                            connectMode: connectMode,
                            theme: theme,
                            onTap: {
                                if connectMode {
                                    if let src = vm.connectingFrom, src != node.id {
                                        vm.connectNodes(from: src, to: node.id)
                                        vm.connectingFrom = nil
                                        connectMode = false
                                    } else {
                                        vm.connectingFrom = node.id
                                    }
                                } else {
                                    vm.selectedId = vm.selectedId == node.id ? nil : node.id
                                }
                            },
                            onDoubleTap: {
                                vm.selectedId = node.id
                                vm.editingId  = node.id
                            },
                            onTextCommit: { text in
                                vm.updateText(node.id, text: text)
                                vm.editingId = nil
                                save()
                            },
                            onDragEnd: { _ in save() }
                        )
                        .position(transformedPoint(node.position, geo: geo))
                    }
                }
            }

            // Selection toolbar
            if let selId = vm.selectedId, vm.editingId == nil {
                VStack {
                    HStack(spacing: 8) {
                        // Color chips
                        ForEach(MindNodeColor.allCases, id: \.self) { color in
                            Circle()
                                .fill(color.fill(for: theme))
                                .overlay(Circle().stroke(color.stroke(for: theme), lineWidth: 1))
                                .frame(width: 16, height: 16)
                                .onTapGesture { vm.updateColor(selId, color: color); save() }
                        }
                        Divider().frame(height: 16).opacity(0.3)
                        toolbarBtn(icon: "plus.circle", tip: "Add child")  { vm.addChild(to: selId); save() }
                        toolbarBtn(icon: "link",        tip: "Connect",
                                   active: connectMode)                    { connectMode.toggle(); if connectMode { vm.connectingFrom = selId } }
                        toolbarBtn(icon: "trash",       tip: "Delete",
                                   destructive: true)                      { vm.deleteNode(selId); save() }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.6))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1))
                    )
                    Spacer()
                }
                .padding(.top, 10)
            }

            // Bottom toolbar
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    toolbarBtn(icon: "plus", tip: "Add node") {
                        if let sel = vm.selectedId {
                            vm.addChild(to: sel)
                        } else if let root = vm.nodes.first(where: { $0.isRoot }) {
                            vm.addChild(to: root.id)
                        } else {
                            vm.addRootNode()
                        }
                        save()
                    }
                    Divider().frame(height: 16).opacity(0.3)
                    toolbarBtn(icon: "minus",                          tip: "Zoom out") { withAnimation { zoom = max(0.3, zoom - 0.15) } }
                    toolbarBtn(icon: "plus.magnifyingglass",           tip: "Zoom in")  { withAnimation { zoom = min(3, zoom + 0.15) } }
                    toolbarBtn(icon: "arrow.up.left.and.down.right.magnifyingglass",
                               tip: "Reset view") {
                        withAnimation(.spring(response: 0.4)) { zoom = 1; pan = .zero; lastPan = .zero }
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
        .onAppear { vm.load(from: document.content) }
    }

    // Coordinate transform: map canvas coords → screen coords
    private func transformedPoint(_ p: CGPoint, geo: GeometryProxy) -> CGPoint {
        CGPoint(
            x: (p.x - 420) * zoom + geo.size.width  / 2 + pan.width,
            y: (p.y - 300) * zoom + geo.size.height / 2 + pan.height
        )
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { v in pan = CGSize(width: lastPan.width + v.translation.width,
                                           height: lastPan.height + v.translation.height) }
            .onEnded { _ in lastPan = pan }
    }

    private func save() {
        appState.updateDocumentContent(id: document.id, content: vm.encode())
    }

    @ViewBuilder
    private func toolbarBtn(icon: String, tip: String,
                            active: Bool = false, destructive: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(
                    destructive ? .red.opacity(0.75)
                    : (active ? .white : .white.opacity(0.52))
                )
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7)
                    .fill(active ? Color.white.opacity(0.14) : Color.clear))
        }
        .buttonStyle(.plain)
        .help(tip)
    }
}

// MARK: - Individual node view
struct MindNodeView: View {
    @Binding var node: MindNode
    let isSelected: Bool
    let isEditing: Bool
    let isConnectSource: Bool
    let connectMode: Bool
    let theme: AppTheme
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onTextCommit: (String) -> Void
    let onDragEnd: (CGPoint) -> Void

    @State private var draft = ""
    @State private var dragStart: CGPoint = .zero
    @State private var hovered = false

    private var minWidth: CGFloat {
        max(80, CGFloat(node.text.count) * 7.5 + 32)
    }

    var body: some View {
        Group {
            if isEditing {
                TextField("", text: $draft, onCommit: { onTextCommit(draft) })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: node.isRoot ? .semibold : .regular))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: minWidth, maxWidth: 200)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: node.isRoot ? 10 : 8)
                            .fill(node.color.fill(for: theme))
                            .overlay(RoundedRectangle(cornerRadius: node.isRoot ? 10 : 8)
                                .stroke(theme.accent, lineWidth: 1.5))
                    )
                    .onAppear { draft = node.text }
            } else {
                Text(node.text)
                    .font(.system(size: node.isRoot ? 13 : 11,
                                  weight: node.isRoot ? .semibold : .medium))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .frame(minWidth: minWidth, maxWidth: 200)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: node.isRoot ? 10 : 8)
                            .fill(node.color.fill(for: theme))
                            .overlay(
                                RoundedRectangle(cornerRadius: node.isRoot ? 10 : 8)
                                    .stroke(
                                        isConnectSource ? theme.accent
                                        : (isSelected ? theme.accent.opacity(0.8)
                                                      : node.color.stroke(for: theme)),
                                        lineWidth: isSelected || isConnectSource ? 1.5 : 1
                                    )
                            )
                    )
                    .shadow(color: isSelected ? theme.accent.opacity(0.25) : .clear, radius: 8)
                    .scaleEffect(isSelected ? 1.06 : (hovered ? 1.03 : 1))
                    .animation(.spring(response: 0.2), value: isSelected)
            }
        }
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture(count: 1) { onTap() }
        .onHover { hovered = $0 }
        .gesture(
            DragGesture(coordinateSpace: .named("mindmap"))
                .onChanged { v in
                    if dragStart == .zero { dragStart = node.position }
                    // This is handled by the parent transforming coords back
                    // We store the raw drag delta on node directly
                    node.x = dragStart.x + v.translation.width
                    node.y = dragStart.y + v.translation.height
                }
                .onEnded { v in
                    dragStart = .zero
                    onDragEnd(node.position)
                }
        )
    }
}
