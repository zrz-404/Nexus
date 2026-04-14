//
//  MindMapEditorView.swift
//  Nexus - Phase 5
//
//  Full node-based mind map editor with drag, connect, and edit capabilities
//

import SwiftUI

struct MindMapEditorView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    let document: StudyDocument
    
    @State private var nodes: [MindMapNode] = []
    @State private var selectedNodeId: UUID? = nil
    @State private var editingNodeId: UUID? = nil
    @State private var editText: String = ""
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isDraggingCanvas = false
    @State private var dragStartLocation: CGPoint = .zero
    @State private var showColorPicker = false
    @State private var connectionStartNode: UUID? = nil
    
    private var theme: AppTheme { themeManager.current }
    
    // Color palette for nodes
    private let nodeColors = [
        "#6366F1", // Indigo
        "#EC4899", // Pink
        "#10B981", // Emerald
        "#F59E0B", // Amber
        "#3B82F6", // Blue
        "#EF4444", // Red
        "#8B5CF6", // Violet
        "#14B8A6", // Teal
    ]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid background
                CanvasGrid()
                    .scaleEffect(scale)
                    .offset(offset)
                
                // Connection lines
                connectionsLayer
                    .scaleEffect(scale)
                    .offset(offset)
                
                // Nodes
                nodesLayer(in: geometry)
                    .scaleEffect(scale)
                    .offset(offset)
                
                // UI Overlay
                VStack {
                    HStack {
                        toolbar
                        Spacer()
                        zoomControls
                    }
                    Spacer()
                    statusBar
                }
                .padding()
                
                // Color picker overlay
                if showColorPicker, let nodeId = selectedNodeId {
                    ColorPickerOverlay(
                        colors: nodeColors,
                        selectedColor: nodes.first { $0.id == nodeId }?.color ?? nodeColors[0],
                        onSelect: { color in
                            updateNodeColor(id: nodeId, color: color)
                            showColorPicker = false
                        },
                        onDismiss: { showColorPicker = false }
                    )
                }
            }
            .background(Color.clear)
            .gesture(canvasDragGesture)
            .onAppear { loadNodes() }
            .onChange(of: nodes) { _ in saveNodes() }
        }
    }
    
    // MARK: - Layers
    
    private var connectionsLayer: some View {
        Canvas { context, size in
            for node in nodes {
                if let parentId = node.parentId,
                   let parent = nodes.first(where: { $0.id == parentId }) {
                    // Draw connection line
                    let startPoint = CGPoint(x: parent.x + size.width/2, y: parent.y + size.height/2)
                    let endPoint = CGPoint(x: node.x + size.width/2, y: node.y + size.height/2)
                    
                    var path = Path()
                    path.move(to: startPoint)
                    
                    // Curved bezier connection
                    let midX = (startPoint.x + endPoint.x) / 2
                    path.addCurve(
                        to: endPoint,
                        control1: CGPoint(x: midX, y: startPoint.y),
                        control2: CGPoint(x: midX, y: endPoint.y)
                    )
                    
                    context.stroke(
                        path,
                        with: .color(Color(hex: theme.accentHex).opacity(0.5)),
                        lineWidth: 2
                    )
                }
            }
        }
    }
    
    private func nodesLayer(in geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(nodes) { node in
                MindMapNodeView(
                    node: node,
                    isSelected: selectedNodeId == node.id,
                    isEditing: editingNodeId == node.id,
                    editText: $editText,
                    theme: theme,
                    onTap: { selectNode(node) },
                    onDoubleTap: { startEditing(node) },
                    onDrag: { delta in moveNode(node, by: delta) },
                    onDelete: { deleteNode(node) },
                    onAddChild: { addChildNode(to: node) },
                    onCommitEdit: { commitEdit() },
                    onCancelEdit: { cancelEdit() }
                )
                .position(
                    x: node.x + geometry.size.width/2,
                    y: node.y + geometry.size.height/2
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - UI Components
    
    private var toolbar: some View {
        HStack(spacing: 8) {
            ToolbarButton(icon: "plus.circle", label: "Add Node") {
                addNode()
            }
            
            ToolbarButton(icon: "link", label: "Connect") {
                toggleConnectionMode()
            }
            .opacity(selectedNodeId != nil ? 1 : 0.5)
            
            ToolbarButton(icon: "paintpalette", label: "Color") {
                if selectedNodeId != nil {
                    showColorPicker = true
                }
            }
            .opacity(selectedNodeId != nil ? 1 : 0.5)
            
            Divider()
                .frame(height: 24)
            
            ToolbarButton(icon: "arrow.uturn.backward", label: "Undo") {
                // TODO: Implement undo
            }
            
            ToolbarButton(icon: "arrow.uturn.forward", label: "Redo") {
                // TODO: Implement redo
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.panel.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
        )
    }
    
    private var zoomControls: some View {
        VStack(spacing: 4) {
            ToolbarButton(icon: "plus.magnifyingglass", label: "Zoom In") {
                withAnimation(.spring(response: 0.2)) {
                    scale = min(3.0, scale + 0.25)
                }
            }
            
            Text("\(Int(scale * 100))%")
                .font(.system(size: 10))
                .foregroundColor(theme.textSecondary)
                .frame(width: 40)
            
            ToolbarButton(icon: "minus.magnifyingglass", label: "Zoom Out") {
                withAnimation(.spring(response: 0.2)) {
                    scale = max(0.5, scale - 0.25)
                }
            }
            
            ToolbarButton(icon: "arrow.up.left.and.arrow.down.right", label: "Reset") {
                withAnimation(.spring(response: 0.3)) {
                    scale = 1.0
                    offset = .zero
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.panel.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
        )
    }
    
    private var statusBar: some View {
        HStack {
            Text("\(nodes.count) nodes")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
            
            Spacer()
            
            if let selected = selectedNodeId,
               let node = nodes.first(where: { $0.id == selected }) {
                Text("Selected: \(node.text.prefix(20))\(node.text.count > 20 ? "..." : "")")
                    .font(.system(size: 11))
                    .foregroundColor(theme.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.panel.opacity(0.9))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
        )
    }
    
    // MARK: - Gestures
    
    private var canvasDragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if !isDraggingCanvas {
                    isDraggingCanvas = true
                    dragStartLocation = value.startLocation
                }
                
                // Pan the canvas
                withAnimation(.linear(duration: 0.05)) {
                    offset = CGSize(
                        width: offset.width + value.translation.width / scale,
                        height: offset.height + value.translation.height / scale
                    )
                }
            }
            .onEnded { _ in
                isDraggingCanvas = false
            }
    }
    
    // MARK: - Node Management
    
    private func loadNodes() {
        if let savedNodes = document.mindMapNodes {
            nodes = savedNodes
        } else if nodes.isEmpty {
            // Create root node
            let rootNode = MindMapNode(
                text: document.title,
                x: 0,
                y: 0,
                parentId: nil,
                color: nodeColors[0]
            )
            nodes = [rootNode]
        }
    }
    
    private func saveNodes() {
        appState.updateDocumentTypedContent(id: document.id, typedContent: nodes)
    }
    
    private func addNode() {
        let newNode = MindMapNode(
            text: "New Node",
            x: CGFloat.random(in: -100...100),
            y: CGFloat.random(in: -100...100),
            parentId: selectedNodeId,
            color: nodeColors.randomElement() ?? nodeColors[0]
        )
        nodes.append(newNode)
        selectedNodeId = newNode.id
    }
    
    private func addChildNode(to parent: MindMapNode) {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance: CGFloat = 150
        
        let newNode = MindMapNode(
            text: "New Node",
            x: parent.x + CGFloat(cos(angle)) * distance,
            y: parent.y + CGFloat(sin(angle)) * distance,
            parentId: parent.id,
            color: parent.color
        )
        nodes.append(newNode)
        selectedNodeId = newNode.id
    }
    
    private func moveNode(_ node: MindMapNode, by delta: CGSize) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            nodes[index].x += delta.width / scale
            nodes[index].y += delta.height / scale
        }
    }
    
    private func selectNode(_ node: MindMapNode) {
        if connectionStartNode != nil && connectionStartNode != node.id {
            // Complete connection
            if let startIndex = nodes.firstIndex(where: { $0.id == connectionStartNode }),
               let endIndex = nodes.firstIndex(where: { $0.id == node.id }) {
                nodes[endIndex].parentId = nodes[startIndex].id
            }
            connectionStartNode = nil
        } else {
            selectedNodeId = node.id
        }
    }
    
    private func startEditing(_ node: MindMapNode) {
        editingNodeId = node.id
        editText = node.text
        selectedNodeId = node.id
    }
    
    private func commitEdit() {
        guard let editingId = editingNodeId else { return }
        if let index = nodes.firstIndex(where: { $0.id == editingId }) {
            nodes[index].text = editText.isEmpty ? "New Node" : editText
        }
        editingNodeId = nil
        editText = ""
    }
    
    private func cancelEdit() {
        editingNodeId = nil
        editText = ""
    }
    
    private func deleteNode(_ node: MindMapNode) {
        // Remove this node and all its children
        let nodesToDelete = collectSubtree(nodeId: node.id)
        nodes.removeAll { nodesToDelete.contains($0.id) }
        
        if selectedNodeId == node.id {
            selectedNodeId = nil
        }
    }
    
    private func collectSubtree(nodeId: UUID) -> [UUID] {
        var result = [nodeId]
        let children = nodes.filter { $0.parentId == nodeId }
        for child in children {
            result.append(contentsOf: collectSubtree(nodeId: child.id))
        }
        return result
    }
    
    private func updateNodeColor(id: UUID, color: String) {
        if let index = nodes.firstIndex(where: { $0.id == id }) {
            nodes[index].color = color
        }
    }
    
    private func toggleConnectionMode() {
        if connectionStartNode != nil {
            connectionStartNode = nil
        } else if let selected = selectedNodeId {
            connectionStartNode = selected
        }
    }
}

// MARK: - Mind Map Node View

struct MindMapNodeView: View {
    let node: MindMapNode
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editText: String
    let theme: AppTheme
    let onTap: () -> Void
    let onDoubleTap: () -> Void
    let onDrag: (CGSize) -> Void
    let onDelete: () -> Void
    let onAddChild: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Node background
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: node.color).opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Color(hex: theme.accentHex) : Color(hex: node.color),
                            lineWidth: isSelected ? 3 : 2
                        )
                )
                .shadow(
                    color: Color(hex: node.color).opacity(isHovered ? 0.4 : 0.2),
                    radius: isHovered ? 12 : 6,
                    x: 0, y: isHovered ? 4 : 2
                )
            
            // Content
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .frame(minWidth: 100, maxWidth: 200, minHeight: 40)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
        .offset(dragOffset)
        .gesture(dragGesture)
        .onTapGesture { onTap() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Edit") { onDoubleTap() }
            Button("Add Child") { onAddChild() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
    
    private var displayContent: some View {
        Text(node.text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(theme.textPrimary)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onTapGesture(count: 2) { onDoubleTap() }
    }
    
    private var editingContent: some View {
        TextField("Node text", text: $editText, onCommit: onCommitEdit)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(theme.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onExitCommand(perform: onCancelEdit)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                onDrag(value.translation)
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.2)) {
                    dragOffset = .zero
                }
            }
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isHovered ? .white : .white.opacity(0.7))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.white.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Color Picker Overlay

struct ColorPickerOverlay: View {
    let colors: [String]
    let selectedColor: String
    let onSelect: (String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 16) {
                Text("Choose Color")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: color == selectedColor ? 3 : 0)
                            )
                            .onTapGesture { onSelect(color) }
                    }
                }
                .frame(maxWidth: 200)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
        }
    }
}

// MARK: - Preview
struct MindMapEditorView_Previews: PreviewProvider {
    static var previews: some View {
        MindMapEditorView(document: StudyDocument(worldId: nil, title: "Test Map", type: "Mind Map"))
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
    }
}
