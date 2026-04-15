import SwiftUI

// MARK: - Echo root
struct EchoView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    @State private var sessionActive = false
    @State private var sessionDocs: [StudyDocument] = []

    private var theme: AppTheme { themeManager.current }
    private var queue: [StudyDocument] { appState.echoQueue }

    var body: some View {
        Group {
            if sessionActive, !sessionDocs.isEmpty {
                EchoSessionView(documents: sessionDocs) {
                    withAnimation(.easeInOut(duration: 0.3)) { sessionActive = false }
                }
            } else if queue.isEmpty {
                EchoEmptyView()
            } else {
                EchoDashboardView(queue: queue) {
                    sessionDocs = queue
                    withAnimation(.easeInOut(duration: 0.3)) { sessionActive = true }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty state
private struct EchoEmptyView: View {
    @EnvironmentObject var themeManager: ThemeManager
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(theme.accent.opacity(0.5))
            Text("All caught up")
                .font(.system(size: 18, weight: .light, design: .serif))
                .foregroundColor(theme.textSecondary)
            Text("No cards due for review today.\nCreate cards in World to start studying.")
                .font(.system(size: 12))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Dashboard
private struct EchoDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let queue: [StudyDocument]
    let onStart: () -> Void

    private var theme: AppTheme { themeManager.current }

    private var dueToday: Int { queue.count }
    private var totalCards: Int { appState.currentDocuments.filter { $0.type == DocumentType.card.rawValue }.count }
    private var masteredCount: Int {
        appState.currentEchoReviews.filter { $0.repetitions >= 3 }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Header
                VStack(spacing: 6) {
                    Text("Echo")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundColor(theme.textPrimary)
                    Text("Spaced repetition for \(appState.currentWorld?.name ?? "your world")")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                }
                .padding(.top, 30)

                // Stats row
                HStack(spacing: 12) {
                    statPill(value: "\(dueToday)", label: "Due today", color: theme.accent)
                    statPill(value: "\(totalCards)", label: "Total cards", color: theme.textSecondary)
                    statPill(value: "\(masteredCount)", label: "Mastered", color: Color(hex: "#1D9E75"))
                }

                // Card stack preview
                ZStack {
                    ForEach(Array(queue.prefix(4).enumerated().reversed()), id: \.element.id) { i, doc in
                        EchoCardPreview(doc: doc)
                            .offset(x: CGFloat(i) * 4, y: CGFloat(i) * 4)
                            .zIndex(Double(4 - i))
                    }
                }
                .frame(height: 190)

                Button("Start Session  →") { onStart() }
                    .buttonStyle(PrimaryButtonStyle())

                // Upcoming reviews
                if !appState.currentEchoReviews.isEmpty {
                    upcomingSection
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 40)
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UPCOMING REVIEWS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(theme.textTertiary)
                .tracking(0.9)

            let upcoming = appState.currentEchoReviews
                .sorted { $0.nextReview < $1.nextReview }
                .prefix(5)

            ForEach(upcoming) { review in
                if let doc = appState.currentDocuments.first(where: { $0.id == review.documentId }) {
                    HStack {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 9))
                            .foregroundColor(theme.textTertiary)
                            .frame(width: 14)
                        Text(doc.title)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textSecondary)
                            .lineLimit(1)
                        Spacer()
                        Text(review.nextReview, style: .relative)
                            .font(.system(size: 10))
                            .foregroundColor(theme.textTertiary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(theme.panelSoft)
                            .overlay(RoundedRectangle(cornerRadius: 7)
                                .stroke(theme.border, lineWidth: 1))
                    )
                }
            }
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.panelSoft)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.border, lineWidth: 1))
        )
    }
}

private struct EchoCardPreview: View {
    @EnvironmentObject var themeManager: ThemeManager
    let doc: StudyDocument
    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(doc.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .lineLimit(2)
        }
        .padding(18)
        .frame(width: 280, height: 170, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.panel)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(theme.border, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Session view
struct EchoSessionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let documents: [StudyDocument]
    let onFinish: () -> Void

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0
    @State private var sessionResults: [(UUID, EchoRating)] = []
    @State private var showingSummary = false
    @State private var dragOffset: CGSize = .zero
    @State private var swipeDirection: SwipeDirection? = nil

    private var theme: AppTheme { themeManager.current }
    private var current: StudyDocument? { currentIndex < documents.count ? documents[currentIndex] : nil }
    private var progress: Double { documents.isEmpty ? 1 : Double(currentIndex) / Double(documents.count) }

    enum SwipeDirection { case left, right }

    var body: some View {
        ZStack {
            if showingSummary {
                EchoSummaryView(results: sessionResults, documents: documents, onDone: onFinish)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if let doc = current {
                VStack(spacing: 0) {
                    // Progress + close
                    HStack {
                        Button(action: onFinish) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(theme.panelSoft))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("\(currentIndex + 1) / \(documents.count)")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textTertiary)
                    }
                    .padding(.horizontal, 30).padding(.top, 20).padding(.bottom, 10)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(theme.panelSoft).frame(height: 3)
                            RoundedRectangle(cornerRadius: 2).fill(theme.accent)
                                .frame(width: geo.size.width * progress, height: 3)
                                .animation(.spring(response: 0.4), value: progress)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 30)

                    Spacer()

                    // Flip card
                    ZStack {
                        // Front — title
                        FlipCardFace(isFront: true, isFlipped: isFlipped, theme: theme) {
                            VStack(spacing: 12) {
                                Text("Question")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(theme.textTertiary)
                                    .tracking(0.8)
                                Text(doc.title)
                                    .font(.system(size: 20, weight: .light, design: .serif))
                                    .foregroundColor(theme.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                                if !isFlipped {
                                    Text("Tap to reveal")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.textTertiary)
                                        .padding(.top, 8)
                                }
                            }
                            .padding(30)
                        }

                        // Back — card content
                        FlipCardFace(isFront: false, isFlipped: isFlipped, theme: theme) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(doc.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(theme.textPrimary)

                                    if let blocks = parsedBlocks(doc) {
                                        ForEach(blocks) { block in
                                            switch block.type {
                                            case .heading:
                                                Text(block.content)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(theme.textPrimary)
                                            case .text:
                                                Text(block.content)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(theme.textSecondary)
                                                    .lineSpacing(3)
                                            case .divider:
                                                Divider().overlay(theme.border)
                                            }
                                        }
                                    } else if !doc.content.isEmpty {
                                        Text(doc.content)
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textSecondary)
                                    } else {
                                        Text("No content yet.")
                                            .font(.system(size: 12))
                                            .foregroundColor(theme.textTertiary)
                                            .italic()
                                    }
                                }
                                .padding(24)
                            }
                        }
                    }
                    .frame(width: 340, height: 260)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 20))
                    .overlay(swipeHint)
                    .onTapGesture { flipCard() }
                    .gesture(dragGesture)
                    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: dragOffset)

                    Spacer()

                    // Rating buttons (only visible when flipped)
                    if isFlipped {
                        HStack(spacing: 8) {
                            ForEach(EchoRating.allCases, id: \.self) { rating in
                                ratingButton(rating)
                            }
                        }
                        .padding(.horizontal, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button("Flip card") { flipCard() }
                            .buttonStyle(SecondaryButtonStyle())
                    }

                    Spacer().frame(height: 30)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: showingSummary)
        .animation(.easeInOut(duration: 0.2), value: isFlipped)
    }

    @ViewBuilder
    private var swipeHint: some View {
        if dragOffset.width > 40 {
            Label("Easy", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#1D9E75"))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color(hex: "#1D9E75").opacity(0.18)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 10)
                .transition(.opacity)
        } else if dragOffset.width < -40 {
            Label("Again", systemImage: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#E24B4A"))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(Color(hex: "#E24B4A").opacity(0.18)))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 10)
                .transition(.opacity)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                if isFlipped { dragOffset = v.translation }
            }
            .onEnded { v in
                if v.translation.width > 80 {
                    advance(rating: .easy)
                } else if v.translation.width < -80 {
                    advance(rating: .again)
                } else {
                    withAnimation { dragOffset = .zero }
                }
            }
    }

    private func flipCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            flipDegrees += 180
            isFlipped.toggle()
        }
    }

    private func advance(rating: EchoRating) {
        guard let doc = current else { return }
        appState.applyEchoRating(documentId: doc.id, rating: rating)
        sessionResults.append((doc.id, rating))

        withAnimation(.spring(response: 0.3)) {
            dragOffset = CGSize(width: rating == .easy ? 400 : -400, height: -20)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dragOffset = .zero
            isFlipped = false
            flipDegrees = 0
            withAnimation { currentIndex += 1 }
            if currentIndex >= documents.count {
                withAnimation { showingSummary = true }
            }
        }
    }

    private func ratingButton(_ rating: EchoRating) -> some View {
        Button { advance(rating: rating) } label: {
            VStack(spacing: 3) {
                Text(rating.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(rating.color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(rating.color.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 9)
                        .stroke(rating.color.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func parsedBlocks(_ doc: StudyDocument) -> [CardBlock]? {
        guard let data = doc.content.data(using: .utf8),
              let blocks = try? JSONDecoder().decode([CardBlock].self, from: data),
              !blocks.isEmpty else { return nil }
        return blocks
    }
}

// MARK: - Flip card face
private struct FlipCardFace<Content: View>: View {
    let isFront: Bool
    let isFlipped: Bool
    let theme: AppTheme
    @ViewBuilder let content: () -> Content

    private var rotation: Double {
        isFront
            ? (isFlipped ? 180 : 0)
            : (isFlipped ? 0   : -180)
    }

    var body: some View {
        content()
            .frame(width: 340, height: 260)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 18)
                        .stroke(theme.border, lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 8)
            .rotation3DEffect(
                .degrees(rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .opacity(abs(rotation) < 90 ? 1 : 0)
    }
}

// MARK: - Summary view
private struct EchoSummaryView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let results: [(UUID, EchoRating)]
    let documents: [StudyDocument]
    let onDone: () -> Void

    private var theme: AppTheme { themeManager.current }

    private var counts: [EchoRating: Int] {
        Dictionary(grouping: results, by: { $0.1 }).mapValues { $0.count }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "star.fill")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundColor(theme.accent)

            Text("Session complete")
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundColor(theme.textPrimary)

            Text("\(results.count) card\(results.count == 1 ? "" : "s") reviewed")
                .font(.system(size: 13))
                .foregroundColor(theme.textTertiary)

            // Breakdown
            HStack(spacing: 10) {
                ForEach(EchoRating.allCases, id: \.self) { rating in
                    let n = counts[rating] ?? 0
                    if n > 0 {
                        VStack(spacing: 4) {
                            Text("\(n)")
                                .font(.system(size: 18, weight: .light, design: .serif))
                                .foregroundColor(rating.color)
                            Text(rating.label)
                                .font(.system(size: 9))
                                .foregroundColor(theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(rating.color.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(rating.color.opacity(0.25), lineWidth: 1))
                        )
                    }
                }
            }
            .frame(maxWidth: 320)

            Button("Done") { onDone() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
