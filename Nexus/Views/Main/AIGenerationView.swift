//
//  AIGenerationView.swift
//  Nexus - Phase 5
//
//  Generate flashcards using Anthropic Claude API
//

import SwiftUI

struct AIGenerationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let document: StudyDocument
    
    @StateObject private var aiService = AIService.shared
    
    @State private var topic: String = ""
    @State private var cardCount: Int = 5
    @State private var difficulty: String = "intermediate"
    @State private var includeExamples: Bool = true
    @State private var generatedCards: [AIGeneratedCard] = []
    @State private var showAPIKeyInput = false
    @State private var apiKeyInput: String = ""
    @State private var showSaveConfirmation = false
    
    private var theme: AppTheme { themeManager.current }
    
    private let difficulties = ["beginner", "intermediate", "advanced"]
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            ScrollView {
                VStack(spacing: 24) {
                    if aiService.generationState == .success(cards: generatedCards) && !generatedCards.isEmpty {
                        resultsSection
                    } else {
                        configurationSection
                    }
                }
                .padding(24)
            }
            
            bottomBar
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            aiService.loadSavedAPIKey()
            topic = document.title
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generate with AI")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                
                Text("Powered by Claude")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(theme.panelSoft)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(theme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }
    
    // MARK: - Configuration Section
    
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // API Key Status
            apiKeySection
            
            Divider()
            
            // Topic Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Topic")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                
                TextField("Enter a topic to generate cards about", text: $topic)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 14))
                    .foregroundColor(theme.textPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.panelSoft)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.border, lineWidth: 1))
                    )
            }
            
            // Card Count
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Number of Cards")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    
                    Spacer()
                    
                    Text("\(cardCount)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.accent)
                }
                
                Slider(value: .init(
                    get: { Double(cardCount) },
                    set: { cardCount = Int($0) }
                ), in: 1...10, step: 1)
                .tint(theme.accent)
            }
            
            // Difficulty
            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty Level")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                
                HStack(spacing: 8) {
                    ForEach(difficulties, id: \.self) { diff in
                        DifficultyButton(
                            label: diff.capitalized,
                            isSelected: difficulty == diff,
                            theme: theme
                        ) {
                            difficulty = diff
                        }
                    }
                }
            }
            
            // Include Examples Toggle
            Toggle("Include Examples", isOn: $includeExamples)
                .font(.system(size: 13))
                .foregroundColor(theme.textPrimary)
                .tint(theme.accent)
        }
    }
    
    private var apiKeySection: some View {
        HStack {
            Image(systemName: aiService.apiKey.isEmpty ? "key.fill" : "checkmark.shield.fill")
                .font(.system(size: 16))
                .foregroundColor(aiService.apiKey.isEmpty ? theme.textTertiary : Color(hex: "#10B981"))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(aiService.apiKey.isEmpty ? "API Key Required" : "API Key Configured")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.textPrimary)
                
                Text(aiService.apiKey.isEmpty ? "Add your Anthropic API key to generate cards" : "Ready to generate flashcards")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
            }
            
            Spacer()
            
            Button(aiService.apiKey.isEmpty ? "Add Key" : "Change") {
                apiKeyInput = aiService.apiKey
                showAPIKeyInput = true
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(theme.accent)
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(aiService.apiKey.isEmpty ? Color(hex: "#F59E0B").opacity(0.1) : Color(hex: "#10B981").opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(aiService.apiKey.isEmpty ? Color(hex: "#F59E0B").opacity(0.3) : Color(hex: "#10B981").opacity(0.3), lineWidth: 1))
        )
        .sheet(isPresented: $showAPIKeyInput) {
            APIKeyInputSheet(apiKey: $apiKeyInput, onSave: {
                aiService.saveAPIKey(apiKeyInput)
                showAPIKeyInput = false
            }, onCancel: {
                showAPIKeyInput = false
            })
        }
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Generated Cards (\(generatedCards.count))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                
                Spacer()
                
                Button("Regenerate") {
                    generateCards()
                }
                .font(.system(size: 12))
                .foregroundColor(theme.accent)
                .buttonStyle(.plain)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(generatedCards.enumerated()), id: \.offset) { index, card in
                    GeneratedCardPreview(
                        index: index + 1,
                        card: card,
                        theme: theme,
                        onDelete: { deleteCard(at: index) }
                    )
                }
            }
        }
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            if case .success = aiService.generationState {
                Button("Start Over") {
                    aiService.resetState()
                    generatedCards = []
                }
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            if case .generating = aiService.generationState {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating...")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
            } else if case .success = aiService.generationState {
                Button("Save to Document") {
                    saveCards()
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Generate Cards") {
                    generateCards()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(topic.trimmingCharacters(in: .whitespaces).isEmpty || aiService.apiKey.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(theme.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }
    
    // MARK: - Actions
    
    private func generateCards() {
        guard !topic.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        aiService.generateCards(
            topic: topic,
            count: cardCount,
            difficulty: difficulty,
            includeExamples: includeExamples
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Generation failed: \(error)")
                }
            },
            receiveValue: { cards in
                generatedCards = cards
            }
        )
        .store(in: &aiService.cancellables)
    }
    
    private func deleteCard(at index: Int) {
        guard index < generatedCards.count else { return }
        generatedCards.remove(at: index)
    }
    
    private func saveCards() {
        // Convert generated cards to card content and save
        let cardContents = generatedCards.map { CardContent(
            front: $0.front,
            back: $0.back,
            tags: $0.tags,
            source: "AI-generated"
        )}
        
        // Save to document
        if let jsonData = try? JSONEncoder().encode(cardContents),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            appState.updateDocumentContent(id: document.id, content: jsonString)
            
            // Also create echo cards for spaced repetition
            appState.addEchoCards(from: document.id, cards: cardContents)
        }
        
        showSaveConfirmation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

// MARK: - Difficulty Button

struct DifficultyButton: View {
    let label: String
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? theme.accent : theme.panelSoft)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Generated Card Preview

struct GeneratedCardPreview: View {
    let index: Int
    let card: AIGeneratedCard
    let theme: AppTheme
    let onDelete: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Card \(index)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.accent)
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            
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
            .padding(.horizontal, 12)
            
            Divider()
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            
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
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.panelSoft)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 1))
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
}

// MARK: - API Key Input Sheet

struct APIKeyInputSheet: View {
    @Binding var apiKey: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Anthropic API Key")
                .font(.system(size: 16, weight: .semibold))
            
            SecureField("API Key", text: $apiKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                
                Button("Save", action: onSave)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

// MARK: - Preview
struct AIGenerationView_Previews: PreviewProvider {
    static var previews: some View {
        AIGenerationView(document: StudyDocument(worldId: nil, title: "Biology", type: "Card"))
            .environmentObject(AppState())
            .environmentObject(ThemeManager())
    }
}
