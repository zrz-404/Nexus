//
//  FloatingDocumentWindow.swift
//  Nexus - Phase 5
//
//  Updated with Mind Map editor and improved document type handling
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Root
struct WorldWorkspaceView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear

                if appState.openDocuments.isEmpty {
                    EmptyWorkspace()
                } else {
                    ForEach(appState.openDocuments) { doc in
                        FloatingDocumentWindow(document: doc, workspaceSize: geo.size)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "workspace")
            .dropDestination(for: String.self) { items, _ in
                guard let idStr = items.first,
                      let id = UUID(uuidString: idStr),
                      let doc = appState.documents.first(where: { $0.id == id })
                else { return false }
                DispatchQueue.main.async { appState.openDocument(doc) }
                return true
            }
        }
    }
}

// MARK: - Empty state
struct EmptyWorkspace: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.current }

    let items: [(String, String, DocumentType)] = [
        ("rectangle.on.rectangle", "Card", .card),
        ("square.grid.2x2", "Canvas", .canvas),
        ("circle.hexagongrid", "Mind Map", .mindmap),
        ("point.3.connected.trianglepath.dotted", "Connections", .connections),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Start with a")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
            HStack(spacing: 14) {
                ForEach(items, id: \.1) { icon, label, type in
                    QuickCreateTile(icon: icon, label: label) {
                        appState.createDocument(title: "Untitled \(label)", type: type)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QuickCreateTile: View {
    @EnvironmentObject var themeManager: ThemeManager
    let icon: String; let label: String; let action: () -> Void
    @State private var hovered = false
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(hovered ? theme.panel : theme.panelSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(theme.textPrimary)
                }
                .frame(width: 68, height: 68)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(hovered ? 1.05 : 1)
        .animation(.spring(response: 0.22), value: hovered)
        .onHover { hovered = $0 }
    }
}

// MARK: - Snap zone
enum SnapZone: Equatable {
    case left, right, topFull, topLeft, topRight
}

// MARK: - Floating document window
struct FloatingDocumentWindow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    let document: StudyDocument
    let workspaceSize: CGSize

    @State private var isDragging = false
    @State private var dragTranslation: CGSize = .zero
    @State private var isResizing = false
    @State private var resizeTranslation: CGSize = .zero
    @State private var snapPreview: SnapZone? = nil
    @State private var isMaximized = false
    @State private var preMaximizeState: AppState.DocumentWindowState? = nil

    private var theme: AppTheme { themeManager.current }
    var docType: DocumentType { DocumentType(rawValue: document.type) ?? .card }

    private var stored: AppState.DocumentWindowState {
        appState.windowState(for: document.id, workspaceSize: workspaceSize)
    }

    // Live position = stored center + current drag translation
    private var liveCenter: CGPoint {
        CGPoint(
            x: stored.position.x + dragTranslation.width,
            y: stored.position.y + dragTranslation.height
        )
    }

    private var liveSize: CGSize {
        CGSize(
            width: max(360, stored.size.width + resizeTranslation.width),
            height: max(280, stored.size.height + resizeTranslation.height)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            documentContent
        }
        .frame(width: liveSize.width, height: liveSize.height)
        .background(
            GlassBackground(
                tint: theme.glassTint,
                opacity: theme.glassOpacity + 0.08,
                brightnessBoost: theme.brightnessBoost
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isDragging ? theme.accent.opacity(0.6) : theme.border,
                    lineWidth: isDragging ? 1.5 : 1
                )
        )
        .shadow(
            color: .black.opacity(isDragging ? 0.45 : 0.22),
            radius: isDragging ? 44 : 18,
            x: 0, y: isDragging ? 18 : 6
        )
        .scaleEffect(isDragging ? 1.014 : 1, anchor: .center)
        .animation(.spring(response: 0.18, dampingFraction: 0.88), value: isDragging)
        .overlay(alignment: .bottomTrailing) { resizeHandle }
        .position(liveCenter)
        .zIndex(isDragging ? 999 : 1)
    }

    // MARK: Title bar
    private var titleBar: some View {
        HStack(spacing: 8) {
            // macOS-style traffic lights
            HStack(spacing: 5) {
                windowDot(color: Color(hex: "#FF5F57")) {
                    withAnimation(.spring(response: 0.22)) { appState.closeDocument(document) }
                }
                windowDot(color: Color(hex: "#FFBD2E")) { /* minimise — future */ }
                windowDot(color: Color(hex: "#27C840")) { toggleMaximize() }
            }
            .padding(.leading, 2)

            Image(systemName: docType.icon)
                .font(.system(size: 10))
                .foregroundColor(theme.textSecondary)

            Text(document.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Snap target hint when dragging
            if isDragging, let zone = snapPreview {
                snapBadge(zone)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(theme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
        .onHover { over in
            if over { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
        .gesture(dragGesture)
    }

    private func windowDot(color: Color, action: @escaping () -> Void) -> some View {
        Circle()
            .fill(color)
            .frame(width: 11, height: 11)
            .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 0.5))
            .onTapGesture(perform: action)
    }

    @ViewBuilder
    private func snapBadge(_ zone: SnapZone) -> some View {
        let label: String = {
            switch zone {
            case .left:    return "← Left half"
            case .right:   return "Right half →"
            case .topFull: return "⬆ Full"
            case .topLeft: return "↖ Quarter"
            case .topRight: return "↗ Quarter"
            }
        }()
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(theme.accent)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(theme.accentSoft)
                    .overlay(Capsule().stroke(theme.accent.opacity(0.3), lineWidth: 1))
            )
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.easeInOut(duration: 0.12), value: zone)
    }

    // MARK: Drag gesture
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("workspace"))
            .onChanged { value in
                if !isDragging { isDragging = true }

                if isMaximized {
                    isMaximized = false
                }

                let startOffset = CGSize(
                    width: value.startLocation.x - stored.position.x,
                    height: value.startLocation.y - stored.position.y
                )
                dragTranslation = CGSize(
                    width: value.location.x - stored.position.x - startOffset.width,
                    height: value.location.y - stored.position.y - startOffset.height
                )

                snapPreview = computeSnapZone(at: value.location)
            }
            .onEnded { value in
                isDragging = false
                defer { snapPreview = nil }

                if let zone = snapPreview {
                    applySnap(zone: zone)
                } else {
                    let finalCenter = CGPoint(
                        x: stored.position.x + dragTranslation.width,
                        y: stored.position.y + dragTranslation.height
                    )
                    appState.updateWindowPosition(for: document.id, position: finalCenter)
                }
                dragTranslation = .zero
            }
    }

    // MARK: Document Content
    @ViewBuilder
    private var documentContent: some View {
        switch docType {
        case .card:
            CardDocumentView(document: document)
        case .canvas:
            FreeFormCanvasView(document: document)
        case .mindmap:
            MindMapEditorView(document: document)
        case .connections:
            ConnectionsGraphView(document: document)
        case .note:
            NoteEditorView(document: document)
        }
    }

    // MARK: Resize handle
    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10))
            .foregroundColor(theme.textTertiary)
            .padding(8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isResizing { isResizing = true }
                        resizeTranslation = value.translation
                    }
                    .onEnded { value in
                        isResizing = false
                        let finalSize = CGSize(
                            width: max(360, stored.size.width + value.translation.width),
                            height: max(280, stored.size.height + value.translation.height)
                        )
                        appState.updateWindowSize(for: document.id, size: finalSize)
                        resizeTranslation = .zero
                    }
            )
            .onHover { over in
                if over { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
    }

    // MARK: Snap logic
    private func computeSnapZone(at point: CGPoint) -> SnapZone? {
        let margin: CGFloat = 60
        let leftZone   = CGRect(x: 0, y: 0, width: margin, height: workspaceSize.height)
        let rightZone  = CGRect(x: workspaceSize.width - margin, y: 0, width: margin, height: workspaceSize.height)
        let topZone    = CGRect(x: 0, y: 0, width: workspaceSize.width, height: margin)
        let topLeft    = CGRect(x: 0, y: 0, width: margin, height: margin)
        let topRight   = CGRect(x: workspaceSize.width - margin, y: 0, width: margin, height: margin)

        if topLeft.contains(point)   { return .topLeft }
        if topRight.contains(point)  { return .topRight }
        if leftZone.contains(point)  { return .left }
        if rightZone.contains(point) { return .right }
        if topZone.contains(point)   { return .topFull }
        return nil
    }

    private func applySnap(zone: SnapZone) {
        let margin: CGFloat = 8
        let halfW  = (workspaceSize.width  - margin * 3) / 2
        let halfH  = (workspaceSize.height - margin * 2) / 2
        let fullW  = workspaceSize.width  - margin * 2
        let fullH  = workspaceSize.height - margin * 2

        var newSize = stored.size
        var newCenter = stored.position

        switch zone {
        case .left:
            newSize  = CGSize(width: halfW, height: fullH)
            newCenter = CGPoint(x: margin + halfW/2, y: workspaceSize.height/2)
        case .right:
            newSize  = CGSize(width: halfW, height: fullH)
            newCenter = CGPoint(x: workspaceSize.width - margin - halfW/2, y: workspaceSize.height/2)
        case .topFull:
            newSize  = CGSize(width: fullW, height: fullH)
            newCenter = CGPoint(x: workspaceSize.width/2, y: workspaceSize.height/2)
        case .topLeft:
            newSize  = CGSize(width: halfW, height: halfH)
            newCenter = CGPoint(x: margin + halfW/2, y: margin + halfH/2)
        case .topRight:
            newSize  = CGSize(width: halfW, height: halfH)
            newCenter = CGPoint(x: workspaceSize.width - margin - halfW/2, y: margin + halfH/2)
        }

        appState.updateWindowSize(for: document.id, size: newSize)
        appState.updateWindowPosition(for: document.id, position: newCenter)
    }

    private func toggleMaximize() {
        if isMaximized {
            if let pre = preMaximizeState {
                appState.updateWindowSize(for: document.id, size: pre.size)
                appState.updateWindowPosition(for: document.id, position: pre.position)
            }
            isMaximized = false
            preMaximizeState = nil
        } else {
            preMaximizeState = stored
            let margin: CGFloat = 8
            let fullW = workspaceSize.width - margin * 2
            let fullH = workspaceSize.height - margin * 2
            appState.updateWindowSize(for: document.id, size: CGSize(width: fullW, height: fullH))
            appState.updateWindowPosition(for: document.id, position: CGPoint(x: workspaceSize.width/2, y: workspaceSize.height/2))
            isMaximized = true
        }
    }
}

// MARK: - Placeholder Views for other document types

struct FreeFormCanvasView: View {
    let document: StudyDocument
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            CanvasGrid()
            
            VStack {
                Text("Canvas Editor")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeManager.current.textPrimary)
                
                Text("Free-form drawing canvas - Coming in Phase 6")
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.current.textSecondary)
            }
        }
    }
}

struct ConnectionsGraphView: View {
    let document: StudyDocument
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            CanvasGrid()
            
            VStack {
                Text("Connections Graph")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeManager.current.textPrimary)
                
                Text("Visual connections between documents - Coming in Phase 6")
                    .font(.system(size: 13))
                    .foregroundColor(themeManager.current.textSecondary)
            }
        }
    }
}

struct NoteEditorView: View {
    let document: StudyDocument
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var text: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Spacer()
                
                Button("Save") {
                    appState.updateDocumentContent(id: document.id, content: text)
                }
                .font(.system(size: 12))
                .foregroundColor(themeManager.current.accent)
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
            .padding(.vertical, 8)
            .background(themeManager.current.panel)
            
            // Editor
            TextEditor(text: $text)
                .font(.system(size: 14))
                .foregroundColor(themeManager.current.textPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(16)
        }
        .onAppear {
            text = document.content
        }
    }
}

// MARK: - Glass Background
struct GlassBackground: View {
    let tint: Color
    let opacity: CGFloat
    let brightnessBoost: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.opacity(opacity))
            .brightness(brightnessBoost)
    }
}
