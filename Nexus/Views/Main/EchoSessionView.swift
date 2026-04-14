//
//  EchoSessionView.swift
//  Nexus - Phase 5
//
//  Functional spaced repetition with flip animations and SM-2 algorithm
//

import SwiftUI

struct EchoSessionView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var currentCardIndex = 0
    @State private var isFlipped = false
    @State private var cardsToReview: [EchoCard] = []
    @State private var sessionComplete = false
    @State private var showStats = false
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    @State private var animateCardOut = false
    
    private var theme: AppTheme { themeManager.current }
    
    // Study queue: new cards first, then due cards
    private var studyQueue: [EchoCard] {
        let new = appState.newEchoCards.prefix(10)  // Limit new cards per session
        let due = appState.dueEchoCards.filter { !new.map(\.id).contains($0.id) }
        return Array(new) + due
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.clear
                
                if sessionComplete {
                    sessionCompleteView
                } else if cardsToReview.isEmpty {
                    emptyStateView
                } else {
                    cardStudyView(in: geometry)
                }
            }
        }
        .onAppear { startSession() }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(theme.accent)
            
            Text("All Caught Up!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text("You have no cards due for review.")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
            
            if !appState.newEchoCards.isEmpty {
                Button("Study New Cards (\(appState.newEchoCards.count))") {
                    startSession()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 16)
            }
            
            Button("View Statistics") {
                showStats = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
    
    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#F59E0B"))
            
            Text("Session Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            VStack(spacing: 12) {
                StatRow(label: "Cards Reviewed", value: "\(sessionStats.cardsStudied)")
                StatRow(label: "Correct Answers", value: "\(sessionStats.correctAnswers)")
                StatRow(label: "Accuracy", value: "\(accuracyPercentage)%")
                StatRow(label: "Current Streak", value: "\(appState.echoStats.streakDays) days")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.panel)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.border, lineWidth: 1))
            )
            
            HStack(spacing: 16) {
                Button("Study More") {
                    startSession()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Done") {
                    // Return to home
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
    
    private func cardStudyView(in geometry: GeometryProxy) -> some View {
        let card = cardsToReview[currentCardIndex]
        
        return VStack(spacing: 0) {
            // Progress bar
            progressBar
            
            Spacer()
            
            // Card with flip animation
            FlipCardView(
                card: card,
                isFlipped: $isFlipped,
                theme: theme,
                offset: cardOffset,
                rotation: cardRotation
            )
            .frame(maxWidth: 600, maxHeight: 400)
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Rating buttons (only show when flipped)
            if isFlipped {
                ratingButtons
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                flipHint
                    .transition(.opacity)
            }
        }
    }
    
    private var progressBar: some View {
        let progress = cardsToReview.isEmpty ? 0 : Double(currentCardIndex) / Double(cardsToReview.count)
        
        return VStack(spacing: 8) {
            HStack {
                Text("Card \(currentCardIndex + 1) of \(cardsToReview.count)")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
                
                Spacer()
                
                if let card = cardsToReview[safe: currentCardIndex] {
                    CardStatusBadge(card: card)
                }
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.panelSoft)
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.accent)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(response: 0.3), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var ratingButtons: some View {
        VStack(spacing: 12) {
            Text("How well did you know this?")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
            
            HStack(spacing: 12) {
                RatingButton(
                    label: "Again",
                    subtitle: "< 1m",
                    color: Color(hex: "#EF4444"),
                    action: { reviewCard(quality: 0) }
                )
                
                RatingButton(
                    label: "Hard",
                    subtitle: "2d",
                    color: Color(hex: "#F59E0B"),
                    action: { reviewCard(quality: 3) }
                )
                
                RatingButton(
                    label: "Good",
                    subtitle: "4d",
                    color: Color(hex: "#10B981"),
                    action: { reviewCard(quality: 4) }
                )
                
                RatingButton(
                    label: "Easy",
                    subtitle: "7d",
                    color: Color(hex: "#3B82F6"),
                    action: { reviewCard(quality: 5) }
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    private var flipHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.system(size: 24))
                .foregroundColor(theme.textSecondary)
            
            Text("Tap card to reveal answer")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Actions
    
    private func startSession() {
        cardsToReview = studyQueue
        currentCardIndex = 0
        isFlipped = false
        sessionComplete = false
        cardOffset = .zero
        cardRotation = 0
    }
    
    private func reviewCard(quality: Int) {
        guard currentCardIndex < cardsToReview.count else { return }
        
        let card = cardsToReview[currentCardIndex]
        
        // Animate card out
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            animateCardOut = true
            cardOffset = CGSize(width: quality >= 3 ? 200 : -200, height: 0)
            cardRotation = quality >= 3 ? 15 : -15
        }
        
        // Submit review
        appState.reviewEchoCard(cardId: card.id, quality: quality)
        
        // Move to next card after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            cardOffset = .zero
            cardRotation = 0
            animateCardOut = false
            isFlipped = false
            
            if currentCardIndex < cardsToReview.count - 1 {
                currentCardIndex += 1
            } else {
                sessionComplete = true
            }
        }
    }
    
    private var sessionStats: EchoSessionStats {
        appState.echoStats
    }
    
    private var accuracyPercentage: Int {
        guard sessionStats.cardsStudied > 0 else { return 0 }
        return Int(Double(sessionStats.correctAnswers) / Double(sessionStats.cardsStudied) * 100)
    }
}

// MARK: - Flip Card View

struct FlipCardView: View {
    let card: EchoCard
    @Binding var isFlipped: Bool
    let theme: AppTheme
    let offset: CGSize
    let rotation: Double
    
    var body: some View {
        ZStack {
            // Front
            CardFace(
                text: card.front,
                label: "QUESTION",
                theme: theme,
                isFront: true
            )
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )
            
            // Back
            CardFace(
                text: card.back,
                label: "ANSWER",
                theme: theme,
                isFront: false
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isFlipped.toggle()
            }
        }
    }
}

// MARK: - Card Face

struct CardFace: View {
    let text: String
    let label: String
    let theme: AppTheme
    let isFront: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.textTertiary)
                    .tracking(1.5)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            // Content
            ScrollView {
                Text(text)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxWidth: .infinity, minHeight: 200)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isFront ? theme.border : theme.accent.opacity(0.5),
                            lineWidth: isFront ? 1 : 2
                        )
                )
        )
        .shadow(
            color: .black.opacity(0.2),
            radius: 20,
            x: 0, y: 10
        )
    }
}

// MARK: - Rating Button

struct RatingButton: View {
    let label: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 10))
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(isHovered ? 1 : 0.8))
            )
            .scaleEffect(isHovered ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.spring(response: 0.2), value: isHovered)
    }
}

// MARK: - Card Status Badge

struct CardStatusBadge: View {
    let card: EchoCard
    
    var body: some View {
        let (text, color): (String, Color) = {
            if card.isNew {
                return ("New", Color(hex: "#3B82F6"))
            } else if card.isLearning {
                return ("Learning", Color(hex: "#F59E0B"))
            } else {
                return ("Review", Color(hex: "#10B981"))
            }
        }()
        
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview
struct EchoSessionView_Previews: PreviewProvider {
    static var previews: some View {
        EchoSessionView()
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
    }
}
