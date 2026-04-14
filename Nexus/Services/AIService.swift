//
//  AIService.swift
//  Nexus - Phase 5
//
//  Anthropic API integration for AI-powered card generation
//

import Foundation
import Combine

enum AIServiceError: Error, Equatable {
    case invalidAPIKey
    case networkError(String)
    case decodingError
    case rateLimited
    case invalidResponse
    case noContent
    
    var localizedDescription: String {
        switch self {
        case .invalidAPIKey:
            return "Invalid or missing API key. Please check your settings."
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError:
            return "Failed to parse AI response."
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .invalidResponse:
            return "Invalid response from AI service."
        case .noContent:
            return "AI returned no content."
        }
    }
}

enum AIGenerationState: Equatable {
    case idle
    case generating
    case success(cards: [AIGeneratedCard])
    case error(message: String)
}

class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var apiKey: String = ""
    @Published var generationState: AIGenerationState = .idle
    
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private var cancellables = Set<AnyCancellable>()
    
    private var isAPIKeyValid: Bool {
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: - API Key Management
    
    func loadSavedAPIKey() {
        if let savedKey = UserDefaults.standard.string(forKey: "nexus_anthropic_api_key") {
            apiKey = savedKey
        }
    }
    
    func saveAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespaces)
        UserDefaults.standard.set(apiKey, forKey: "nexus_anthropic_api_key")
    }
    
    func clearAPIKey() {
        apiKey = ""
        UserDefaults.standard.removeObject(forKey: "nexus_anthropic_api_key")
    }
    
    // MARK: - Card Generation
    
    func generateCards(
        topic: String,
        count: Int = 5,
        difficulty: String = "intermediate",
        includeExamples: Bool = true
    ) -> AnyPublisher<[AIGeneratedCard], AIServiceError> {
        
        guard isAPIKeyValid else {
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        generationState = .generating
        
        let prompt = buildCardGenerationPrompt(
            topic: topic,
            count: min(count, 10),  // Limit to 10 cards max
            difficulty: difficulty,
            includeExamples: includeExamples
        )
        
        guard let request = buildRequest(prompt: prompt) else {
            generationState = .error(message: AIServiceError.invalidAPIKey.localizedDescription)
            return Fail(error: AIServiceError.invalidAPIKey).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Data in
                guard let self = self else { throw AIServiceError.networkError("Service unavailable") }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 200...299:
                        return data
                    case 401:
                        throw AIServiceError.invalidAPIKey
                    case 429:
                        throw AIServiceError.rateLimited
                    default:
                        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                        throw AIServiceError.networkError("HTTP \(httpResponse.statusCode): \(message)")
                    }
                }
                return data
            }
            .flatMap { [weak self] data -> AnyPublisher<[AIGeneratedCard], AIServiceError> in
                guard let self = self else {
                    return Fail(error: AIServiceError.networkError("Service unavailable")).eraseToAnyPublisher()
                }
                return self.parseCardResponse(data: data)
            }
            .handleEvents(
                receiveOutput: { [weak self] cards in
                    DispatchQueue.main.async {
                        self?.generationState = .success(cards: cards)
                    }
                },
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        if case .failure(let error) = completion {
                            self?.generationState = .error(message: error.localizedDescription)
                        }
                    }
                }
            )
            .eraseToAnyPublisher()
    }
    
    // MARK: - Request Building
    
    private func buildRequest(prompt: String) -> URLRequest? {
        guard let url = URL(string: baseURL) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 4000,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    // MARK: - Prompt Engineering
    
    private func buildCardGenerationPrompt(topic: String, count: Int, difficulty: String, includeExamples: Bool) -> String {
        let exampleSection = includeExamples ? """
        
        Include concrete examples where appropriate to illustrate concepts.
        """ : ""
        
        return """
        Generate \(count) flashcards for studying the topic: "\(topic)"
        
        Difficulty level: \(difficulty)
        
        Requirements:
        - Front of card: A clear, concise question or prompt
        - Back of card: A comprehensive but concise answer
        - Each card should focus on one key concept
        - Use formatting (bolding, bullet points) where helpful
        - Keep front under 100 characters when possible
        - Keep back under 300 characters when possible\(exampleSection)
        
        Return ONLY a JSON array in this exact format (no markdown, no code blocks):
        [
          {
            "front": "Question or prompt here",
            "back": "Answer here",
            "tags": ["tag1", "tag2"]
          }
        ]
        
        Generate exactly \(count) cards.
        """
    }
    
    // MARK: - Response Parsing
    
    private func parseCardResponse(data: Data) -> AnyPublisher<[AIGeneratedCard], AIServiceError> {
        return Future { promise in
            do {
                // Parse Anthropic response
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let content = json["content"] as? [[String: Any]],
                      let firstContent = content.first,
                      let text = firstContent["text"] as? String else {
                    promise(.failure(.decodingError))
                    return
                }
                
                // Extract JSON from the text (handle potential markdown code blocks)
                let cleanedText = self.extractJSON(from: text)
                
                guard let jsonData = cleanedText.data(using: .utf8) else {
                    promise(.failure(.decodingError))
                    return
                }
                
                let cards = try JSONDecoder().decode([AIGeneratedCard].self, from: jsonData)
                promise(.success(cards))
                
            } catch {
                print("Parsing error: \(error)")
                promise(.failure(.decodingError))
            }
        }.eraseToAnyPublisher()
    }
    
    private func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find JSON array bounds
        if let startIndex = cleaned.firstIndex(of: "["),
           let endIndex = cleaned.lastIndex(of: "]") {
            return String(cleaned[startIndex...endIndex])
        }
        
        return cleaned
    }
    
    // MARK: - Convenience Methods
    
    func generateCardsAsync(
        topic: String,
        count: Int = 5,
        difficulty: String = "intermediate",
        includeExamples: Bool = true
    ) async throws -> [AIGeneratedCard] {
        return try await withCheckedThrowingContinuation { continuation in
            generateCards(topic: topic, count: count, difficulty: difficulty, includeExamples: includeExamples)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { cards in
                        continuation.resume(returning: cards)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    func resetState() {
        generationState = .idle
    }
}

// MARK: - Preview Helper
extension AIService {
    static var preview: AIService {
        let service = AIService()
        service.generationState = .success(cards: [
            AIGeneratedCard(
                front: "What is photosynthesis?",
                back: "The process by which plants convert light energy into chemical energy (glucose) using chlorophyll.",
                tags: ["biology", "plants"]
            ),
            AIGeneratedCard(
                front: "What are the reactants of photosynthesis?",
                back: "Carbon dioxide (CO₂), water (H₂O), and light energy.",
                tags: ["biology", "chemistry"]
            )
        ])
        return service
    }
}
