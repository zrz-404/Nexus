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
        // .position() in SwiftUI sets the CENTER of the view
        .position(liveCenter)
        .zIndex(isDragging ? 999 : 1)
        // Snap preview overlay — drawn as a sibling, not child
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

    // MARK: Drag gesture — uses .named("workspace") coordinate space
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("workspace"))
            .onChanged { value in
                if !isDragging { isDragging = true }

                // If maximized, restore to original size and re-anchor the drag
                if isMaximized {
                    isMaximized = false
                }

                // Translation is from drag start, not stored position
                // value.startLocation is where the drag began in workspace coords
                // value.location is current finger/mouse position
                // We want: new center = value.location adjusted by where the
                // finger was relative to the window center when drag started.
                let startOffset = CGSize(
                    width: value.startLocation.x - stored.position.x,
                    height: value.startLocation.y - stored.position.y
                )
                dragTranslation = CGSize(
                    width: value.translation.width,
                    height: value.translation.height
                )

                let _ = startOffset // kept for reference; live center calculation handles this correctly

                snapPreview = detectSnap(at: liveCenter)
            }
            .onEnded { value in
                isDragging = false
                let finalCenter = CGPoint(
                    x: stored.position.x + value.translation.width,
                    y: stored.position.y + value.translation.height
                )
                dragTranslation = .zero
                let zone = snapPreview
                snapPreview = nil

                if let zone = zone {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        applySnap(zone)
                    }
                } else {
                    let clamped = clampedCenter(finalCenter, size: stored.size)
                    appState.updateWindowPosition(for: document.id, position: clamped)
                }
            }
    }

    // MARK: Resize handle
    private var resizeHandle: some View {
        ZStack {
            VStack(spacing: 2) {
                HStack(spacing: 2) { gripDot(); gripDot(); gripDot() }
                HStack(spacing: 2) { gripDot(); gripDot(); gripDot() }
                HStack(spacing: 2) { gripDot(); gripDot(); gripDot() }
            }
        }
        .padding(8)
        .contentShape(Rectangle())
        .onHover { over in
//            if over { NSCursor.resizeUpLeftDownRight.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { v in
                    isResizing = true
                    resizeTranslation = v.translation
                }
                .onEnded { _ in
                    isResizing = false
                    appState.updateWindowSize(for: document.id, size: liveSize)
                    resizeTranslation = .zero
                }
        )
    }

    private func gripDot() -> some View {
        Circle().fill(theme.textTertiary.opacity(0.5)).frame(width: 2, height: 2)
    }

    // MARK: Document content
    @ViewBuilder
    private var documentContent: some View {
        Group {
            switch docType {
            case .card:        CardDocumentView(document: document)
            case .canvas:      FreeformCanvasView(canvasDocumentId: document.id)
            case .mindmap:     CanvasPlaceholder(label: "Mind Map — click to add nodes")
            case .connections: ConnectionsGraphView()
            case .note:        NoteDocumentView(document: document)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Maximize
    private func toggleMaximize() {
        if isMaximized {
            isMaximized = false
            if let prev = preMaximizeState {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    appState.updateWindowPosition(for: document.id, position: prev.position)
                    appState.updateWindowSize(for: document.id, size: prev.size)
                }
            }
        } else {
            preMaximizeState = stored
            isMaximized = true
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                applySnap(.topFull)
            }
        }
    }

    // MARK: Snap logic
    private func detectSnap(at center: CGPoint) -> SnapZone? {
        let edgeH: CGFloat = 64
        let edgeV: CGFloat = 48

        let nearLeft  = center.x < edgeH
        let nearRight = center.x > workspaceSize.width - edgeH
        let nearTop   = center.y < edgeV

        if nearTop && nearLeft  { return .topLeft  }
        if nearTop && nearRight { return .topRight }
        if nearTop              { return .topFull  }
        if nearLeft             { return .left     }
        if nearRight            { return .right    }
        return nil
    }

    private func rectForSnap(_ zone: SnapZone) -> CGRect {
        let w = workspaceSize.width
        let h = workspaceSize.height
        let p: CGFloat = 4
        switch zone {
        case .topFull:
            return CGRect(x: p, y: p, width: w - p*2, height: h - p*2)
        case .left:
            return CGRect(x: p, y: p, width: w/2 - p*1.5, height: h - p*2)
        case .right:
            return CGRect(x: w/2 + p*0.5, y: p, width: w/2 - p*1.5, height: h - p*2)
        case .topLeft:
            return CGRect(x: p, y: p, width: w/2 - p*1.5, height: h/2 - p*1.5)
        case .topRight:
            return CGRect(x: w/2 + p*0.5, y: p, width: w/2 - p*1.5, height: h/2 - p*1.5)
        }
    }

    private func applySnap(_ zone: SnapZone) {
        let r = rectForSnap(zone)
        appState.updateWindowPosition(for: document.id, position: CGPoint(x: r.midX, y: r.midY))
        appState.updateWindowSize(for: document.id, size: r.size)
    }

    private func clampedCenter(_ center: CGPoint, size: CGSize) -> CGPoint {
        let halfW = size.width / 2
        let halfH = size.height / 2
        return CGPoint(
            x: min(max(center.x, halfW + 4), workspaceSize.width  - halfW - 4),
            y: min(max(center.y, halfH + 4), workspaceSize.height - halfH - 4)
        )
    }
}

// MARK: - Canvas placeholder
struct CanvasPlaceholder: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        ZStack {
            CanvasGrid()
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundColor(theme.textTertiary)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
            }
        }
    }
}

// MARK: - Note document
struct NoteDocumentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let document: StudyDocument
    @State private var text: String
    private var theme: AppTheme { themeManager.current }

    init(document: StudyDocument) {
        self.document = document
        _text = State(initialValue: document.content)
    }

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 14))
            .foregroundColor(theme.textPrimary)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .padding(20)
            .onChange(of: text) {
                appState.updateDocumentContent(id: document.id, content: text)
            }
    }
}

// MARK: - Card document
struct CardDocumentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let document: StudyDocument
    @State private var title: String
    @State private var blocks: [CardBlock] = []
    @State private var tags: [String] = []
    @State private var showBlockPicker = false
    @State private var coverImage: NSImage? = nil
    @State private var photosItem: PhotosPickerItem? = nil

    private var theme: AppTheme { themeManager.current }

    init(document: StudyDocument) {
        self.document = document
        _title = State(initialValue: document.title)
        if let data = document.content.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([CardBlock].self, from: data) {
            _blocks = State(initialValue: decoded)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    if let img = coverImage {
                        Image(nsImage: img).resizable().scaledToFill()
                            .frame(height: 130).clipped()
                    } else {
                        Rectangle().fill(theme.panelStrong).frame(height: 130)
                    }
                    PhotosPicker(selection: $photosItem, matching: .images) {
                        Label(coverImage == nil ? "Add Cover" : "Change Cover", systemImage: "photo")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Capsule().fill(theme.panelStrong))
                    }
                    .buttonStyle(.plain).padding(10)

                    if coverImage != nil {
                        Button { withAnimation { coverImage = nil } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14)).foregroundColor(theme.textSecondary)
                        }
                        .buttonStyle(.plain).padding(10)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .frame(maxWidth: .infinity)
                .onChange(of: photosItem) { loadCoverImage() }

                VStack(alignment: .leading, spacing: 14) {
                    TextField("Untitled", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .onSubmit { persist() }

                    TagsRow(tags: $tags)
                    Divider().overlay(theme.border)

                    if blocks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get started with")
                                .font(.system(size: 10)).foregroundColor(theme.textTertiary)
                            HStack(spacing: 6) {
                                BlockChip("Text", "text.alignleft") { addBlock(.text) }
                                BlockChip("Heading", "textformat.size") { addBlock(.heading) }
                                BlockChip("Divider", "minus") { addBlock(.divider) }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach($blocks) { $block in
                                CardBlockRow(block: $block) { deleteBlock(block.id) }
                            }
                        }
                    }

                    if showBlockPicker {
                        HStack(spacing: 6) {
                            BlockChip("Text", "text.alignleft") { addBlock(.text); showBlockPicker = false }
                            BlockChip("Heading", "textformat.size") { addBlock(.heading); showBlockPicker = false }
                            BlockChip("Divider", "minus") { addBlock(.divider); showBlockPicker = false }
                        }
                    }

                    Button { showBlockPicker.toggle() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 9))
                            Text("Add block").font(.system(size: 10))
                        }
                        .foregroundColor(theme.textTertiary).padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
            }
        }
        .onChange(of: title) { persist() }
    }

    private func loadCoverImage() {
        guard let item = photosItem else { return }
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                if case .success(let data) = result, let data, let img = NSImage(data: data) {
                    withAnimation { coverImage = img }
                }
            }
        }
    }
    private func addBlock(_ type: CardBlockType) { blocks.append(CardBlock(type: type)); persist() }
    private func deleteBlock(_ id: UUID) { blocks.removeAll { $0.id == id }; persist() }
    private func persist() {
        if let data = try? JSONEncoder().encode(blocks), let json = String(data: data, encoding: .utf8) {
            appState.updateDocumentContent(id: document.id, title: title, content: json)
        }
    }
}

// MARK: - Block row
struct CardBlockRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var block: CardBlock
    let onDelete: () -> Void
    @State private var hovered = false
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 8))
                .foregroundColor(theme.textTertiary.opacity(hovered ? 1 : 0))
                .frame(width: 12).padding(.top, 8)
            Group {
                switch block.type {
                case .text:
                    TextEditor(text: $block.content)
                        .font(.system(size: 13)).foregroundColor(theme.textPrimary)
                        .scrollContentBackground(.hidden).background(Color.clear)
                        .frame(minHeight: 36)
                case .heading:
                    TextField("Heading", text: $block.content)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                case .divider:
                    Divider().overlay(theme.border).padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity)
            if hovered && block.type != .divider {
                Button(action: onDelete) {
                    Image(systemName: "xmark").font(.system(size: 8))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(theme.panelSoft))
                }
                .buttonStyle(.plain).padding(.top, 6)
            }
        }
        .padding(.vertical, 2).contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(.easeInOut(duration: 0.1)) { hovered = isHovered }
        }
    }
}

struct BlockChip: View {
    @EnvironmentObject var themeManager: ThemeManager
    let label: String; let icon: String; let action: () -> Void
    @State private var hovered = false
    private var theme: AppTheme { themeManager.current }
    init(_ l: String, _ i: String, action: @escaping () -> Void) { label = l; icon = i; self.action = action }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 10))
            }
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovered ? theme.panel : theme.panelSoft)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
    }
}

// MARK: - Tags
struct TagsRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var tags: [String]
    @State private var isAdding = false
    @State private var draft = ""
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        FlowLayout(spacing: 5) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 3) {
                    Text(tag).font(.system(size: 9, weight: .medium)).foregroundColor(theme.textSecondary)
                    Button { tags.removeAll { $0 == tag } } label: {
                        Image(systemName: "xmark").font(.system(size: 7)).foregroundColor(theme.textTertiary)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(theme.panelSoft).overlay(Capsule().stroke(theme.border, lineWidth: 1)))
            }
            if isAdding {
                TextField("tag...", text: $draft).textFieldStyle(.plain)
                    .font(.system(size: 9)).foregroundColor(theme.textPrimary).frame(width: 72)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().stroke(theme.border, lineWidth: 1))
                    .onSubmit {
                        let t = draft.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty && !tags.contains(t) { tags.append(t) }
                        draft = ""; isAdding = false
                    }
            } else {
                Button { isAdding = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 8))
                        Text("tag").font(.system(size: 9))
                    }
                    .foregroundColor(theme.textTertiary).padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().stroke(theme.border, lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Flow layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxW = proposal.replacingUnspecifiedDimensions().width
        var x: CGFloat = 0; var y: CGFloat = 0; var rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX; var y = bounds.minY; var rowH: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(s))
            x += s.width + spacing; rowH = max(rowH, s.height)
        }
    }
}
