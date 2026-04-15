import SwiftUI
import Combine

// MARK: - AI generation request/response types
private struct AnthropicRequest: Codable {
    let model: String
    let max_tokens: Int
    let system: String
    let messages: [AnthropicMessage]
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Codable {
    let content: [AnthropicContent]
}

private struct AnthropicContent: Codable {
    let type: String
    let text: String?
}

// MARK: - Generated card result
struct GeneratedCard {
    var title: String
    var blocks: [CardBlock]
}

// MARK: - AI card generator
class AICardGenerator: ObservableObject {
    @Published var isGenerating = false
    @Published var error: String? = nil

    /// Generate card blocks for a given topic and study genre
    func generate(topic: String, genre: String) async throws -> GeneratedCard {
        await MainActor.run { isGenerating = true; error = nil }

        let systemPrompt = """
        You are a study card generator for a student studying \(genre.isEmpty ? "general subjects" : genre).
        When given a topic, produce a well-structured study card as JSON.
        Respond ONLY with valid JSON — no markdown, no backticks, no preamble.
        The JSON schema is:
        {
          "title": "string — concise card title",
          "blocks": [
            {"type": "heading", "content": "string"},
            {"type": "text",    "content": "string"},
            {"type": "divider", "content": ""},
            ...
          ]
        }
        Guidelines:
        - Start with a heading that states the concept name
        - Write 2-4 text blocks covering: definition, key details, examples or mnemonics
        - Use a divider to separate sections where helpful
        - Keep each text block to 2-4 sentences — dense but readable
        - Do not use markdown inside the content strings
        """

        let body = AnthropicRequest(
            model: "claude-sonnet-4-20250514",
            max_tokens: 1000,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: "Create a study card for: \(topic)")]
        )

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw GeneratorError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // API key is injected at build time via xcconfig / environment
        // For dev: set ANTHROPIC_API_KEY in your scheme environment variables
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
        }
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            await MainActor.run { error = msg; isGenerating = false }
            throw GeneratorError.apiError(msg)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw GeneratorError.emptyResponse
        }

        // Parse the JSON card
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = cleaned.data(using: .utf8),
              let raw = try? JSONDecoder().decode(RawGeneratedCard.self, from: jsonData) else {
            throw GeneratorError.parseError(text)
        }

        let card = GeneratedCard(
            title: raw.title,
            blocks: raw.blocks.map { rb in
                CardBlock(
                    type: CardBlockType(rawValue: rb.type) ?? .text,
                    content: rb.content
                )
            }
        )

        await MainActor.run { isGenerating = false }
        return card
    }

    enum GeneratorError: LocalizedError {
        case badURL
        case apiError(String)
        case emptyResponse
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .badURL:           return "Invalid API URL"
            case .apiError(let m): return "API error: \(m)"
            case .emptyResponse:   return "Empty response from AI"
            case .parseError(let t): return "Could not parse AI response: \(t.prefix(120))"
            }
        }
    }
}

private struct RawGeneratedCard: Codable {
    let title: String
    let blocks: [RawBlock]
    struct RawBlock: Codable {
        let type: String
        let content: String
    }
}

// MARK: - AI Generate Sheet (presented from CardDocumentView)
struct AIGenerateSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var generator = AICardGenerator()

    let genre: String
    let onAccept: (GeneratedCard) -> Void

    @State private var topic = ""
    @State private var preview: GeneratedCard? = nil
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss

    private var theme: AppTheme { themeManager.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 13))
                    .foregroundColor(theme.accent)
                Text("Generate with AI")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(theme.panelSoft))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 14)

            Divider().overlay(theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Topic input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Topic")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.textSecondary)
                        HStack(spacing: 10) {
                            TextField("e.g. Mitosis, Ohm's Law, The French Revolution…", text: $topic)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .foregroundColor(theme.textPrimary)
                                .onSubmit { startGeneration() }

                            Button {
                                startGeneration()
                            } label: {
                                Group {
                                    if generator.isGenerating {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 18))
                                    }
                                }
                                .foregroundColor(topic.isEmpty ? theme.textTertiary : theme.accent)
                            }
                            .buttonStyle(.plain)
                            .disabled(topic.isEmpty || generator.isGenerating)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(theme.panelSoft)
                                .overlay(RoundedRectangle(cornerRadius: 9)
                                    .stroke(theme.border, lineWidth: 1))
                        )
                    }

                    // Error state
                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange.opacity(0.2), lineWidth: 1))
                        )
                    }

                    // Preview
                    if let card = preview {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Preview")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                // Regenerate
                                Button {
                                    startGeneration()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 9))
                                        Text("Regenerate")
                                            .font(.system(size: 10))
                                    }
                                    .foregroundColor(theme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text(card.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.textPrimary)

                                ForEach(card.blocks) { block in
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
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(theme.panel)
                                    .overlay(RoundedRectangle(cornerRadius: 10)
                                        .stroke(theme.border, lineWidth: 1))
                            )
                        }
                    }
                }
                .padding(20)
            }

            // Action row
            if preview != nil {
                Divider().overlay(theme.border)
                HStack(spacing: 10) {
                    Button("Discard") { preview = nil }
                        .buttonStyle(SecondaryButtonStyle())
                    Spacer()
                    Button("Use this card") {
                        if let card = preview { onAccept(card); dismiss() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
            }
        }
        .frame(width: 440)
        .frame(minHeight: 300)
        .background(
            GlassBackground(
                tint: theme.glassTint,
                opacity: theme.glassOpacity + 0.1,
                brightnessBoost: theme.brightnessBoost
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.border, lineWidth: 1)
        )
        .preferredColorScheme(theme.isDarkTheme ? .dark : .light)
    }

    private func startGeneration() {
        guard !topic.isEmpty else { return }
        errorMessage = nil
        preview = nil
        Task {
            do {
                let card = try await generator.generate(topic: topic, genre: genre)
                await MainActor.run { preview = card }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}
