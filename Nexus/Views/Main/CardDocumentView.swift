//
//  CardDocumentView.swift
//  Nexus - Phase 5
//
//  Card document editor with AI generation support
//

import SwiftUI

struct CardDocumentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    
    let document: StudyDocument
    
    @State private var cards: [CardContent] = []
    @State private var selectedCardIndex: Int? = nil
    @State private var showAIGeneration = false
    @State private var showAddCardSheet = false
    @State private var newCardFront: String = ""
    @State private var newCardBack: String = ""
    
    private var theme: AppTheme { themeManager.current }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            if cards.isEmpty {
                emptyState
            } else {
                cardsList
            }
        }
        .onAppear { loadCards() }
        .sheet(isPresented: $showAIGeneration) {
            AIGenerationView(document: document)
                .frame(minWidth: 600, minHeight: 700)
        }
        .sheet(isPresented: $showAddCardSheet) {
            addCardSheet
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            // AI Generate Button
            Button {
                showAIGeneration = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                    Text("Generate with AI")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.accentSoft)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.accent.opacity(0.3), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 20)
            
            // Add Card Button
            Button {
                showAddCardSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                    Text("Add Card")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.panelSoft)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.border, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Card Count
            Text("\(cards.count) card\(cards.count == 1 ? "" : "s")")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
            
            // Study Button
            if !cards.isEmpty {
                Button {
                    // Navigate to Echo study session
                    appState.currentTab = .echo
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Study")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.accent)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 48))
                .foregroundColor(theme.textTertiary)
            
            Text("No Cards Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            Text("Generate cards with AI or add them manually")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
            
            HStack(spacing: 16) {
                Button {
                    showAIGeneration = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Generate with AI")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button {
                    showAddCardSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Manually")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Cards List
    
    private var cardsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    EditableCardRow(
                        index: index + 1,
                        card: card,
                        theme: theme,
                        onUpdate: { updatedCard in
                            updateCard(at: index, with: updatedCard)
                        },
                        onDelete: {
                            deleteCard(at: index)
                        }
                    )
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Add Card Sheet
    
    private var addCardSheet: some View {
        VStack(spacing: 20) {
            Text("Add New Card")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Front (Question)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextEditor(text: $newCardFront)
                    .font(.system(size: 14))
                    .frame(height: 80)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Back (Answer)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextEditor(text: $newCardBack)
                    .font(.system(size: 14))
                    .frame(height: 80)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    newCardFront = ""
                    newCardBack = ""
                    showAddCardSheet = false
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Add Card") {
                    addCard()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(newCardFront.trimmingCharacters(in: .whitespaces).isEmpty ||
                         newCardBack.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
    
    // MARK: - Data Management
    
    private func loadCards() {
        if let decodedCards = document.cardContent {
            // Single card stored as CardContent
            cards = [decodedCards]
        } else if let echoCards = document.echoCards {
            // Multiple cards stored as [EchoCard]
            cards = echoCards.map { CardContent(front: $0.front, back: $0.back, tags: []) }
        } else if !document.content.isEmpty {
            // Try to decode as array
            if let data = document.content.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([CardContent].self, from: data) {
                cards = decoded
            }
        }
    }
    
    private func saveCards() {
        if let jsonData = try? JSONEncoder().encode(cards),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            appState.updateDocumentContent(id: document.id, content: jsonString)
        }
    }
    
    private func addCard() {
        let newCard = CardContent(
            front: newCardFront.trimmingCharacters(in: .whitespaces),
            back: newCardBack.trimmingCharacters(in: .whitespaces),
            tags: []
        )
        cards.append(newCard)
        saveCards()
        
        // Also add to Echo for spaced repetition
        appState.createEchoCard(documentId: document.id, front: newCard.front, back: newCard.back)
        
        newCardFront = ""
        newCardBack = ""
        showAddCardSheet = false
    }
    
    private func updateCard(at index: Int, with card: CardContent) {
        guard index < cards.count else { return }
        cards[index] = card
        saveCards()
    }
    
    private func deleteCard(at index: Int) {
        guard index < cards.count else { return }
        cards.remove(at: index)
        saveCards()
    }
}

// MARK: - Editable Card Row

struct EditableCardRow: View {
    let index: Int
    let card: CardContent
    let theme: AppTheme
    let onUpdate: (CardContent) -> Void
    let onDelete: () -> Void
    
    @State private var isEditing = false
    @State private var editFront: String = ""
    @State private var editBack: String = ""
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Card \(index)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.accent)
                
                Spacer()
                
                if !card.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(card.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9))
                                .foregroundColor(theme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(theme.panelSoft)
                                )
                        }
                    }
                }
                
                Menu {
                    Button("Edit") {
                        editFront = card.front
                        editBack = card.back
                        isEditing = true
                    }
                    
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.panelSoft)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
        )
    }
    
    private var displayContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Front
            VStack(alignment: .leading, spacing: 4) {
                Text("Front")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                
                Text(card.front)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(isExpanded ? nil : 2)
            }
            
            Divider()
            
            // Back
            VStack(alignment: .leading, spacing: 4) {
                Text("Back")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                
                Text(card.back)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(isExpanded ? nil : 3)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var editingContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Front")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                
                TextEditor(text: $editFront)
                    .font(.system(size: 13))
                    .frame(height: 60)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Back")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.textTertiary)
                
                TextEditor(text: $editBack)
                    .font(.system(size: 13))
                    .frame(height: 60)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }
            
            HStack(spacing: 8) {
                Button("Cancel") {
                    isEditing = false
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Save") {
                    let updated = CardContent(
                        front: editFront,
                        back: editBack,
                        tags: card.tags,
                        source: card.source
                    )
                    onUpdate(updated)
                    isEditing = false
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - Preview
struct CardDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        CardDocumentView(document: StudyDocument(worldId: nil, title: "Test Cards", type: "Card"))
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
    }
}
