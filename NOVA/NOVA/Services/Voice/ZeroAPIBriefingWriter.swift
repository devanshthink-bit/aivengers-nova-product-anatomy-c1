//
//  ZeroAPIBriefingWriter.swift
//  NOVA
//

import Foundation

/// The best-sounding tier: the same free, keyless endpoint that writes the quiz questions.
///
/// It picks what matters and phrases it for speech, in Hindi when asked. No retry: the
/// next tier *is* the retry, and a second request against a rate limit only lengthens it.
struct ZeroAPIBriefingWriter: BriefingWriter {
    var endpoint: URL = QuestionGenerator.endpoint
    var session: URLSession = .shared

    func brief(request transcript: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        guard !candidates.isEmpty else { throw BriefingError.noStories }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("https://zeroapi.in", forHTTPHeaderField: "Origin")
        urlRequest.timeoutInterval = 8

        urlRequest.httpBody = try JSONEncoder().encode(
            BriefingChatRequest(
                // The question generator's tool id: the one this endpoint is known to accept.
                toolId: "mcqGenerator",
                model: QuestionGenerator.model,
                // Devanagari costs several tokens a word, so Hindi needs the larger budget.
                maxTokens: 1000,
                temperature: 0.3,
                messages: [
                    .init(role: "system", content: BriefingPrompt.instructions(language: language, count: intent.count)),
                    .init(role: "user", content: BriefingPrompt.request(transcript: transcript, candidates: candidates))
                ]
            )
        )

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BriefingError.badResponse
        }
        let chat = try JSONDecoder().decode(BriefingChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content, !content.isEmpty else {
            throw BriefingError.badResponse
        }
        return try Briefing.decoding(content, candidates: candidates, tier: .zeroAPI, language: language)
    }
}

// MARK: - Wire types

// Separate from `QuestionGenerator`'s private copies so neither file's shape can
// quietly change the other's requests.
private struct BriefingChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let toolId: String
    let model: String
    let maxTokens: Int
    let temperature: Double
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case toolId, model, temperature, messages
        case maxTokens = "max_tokens"
    }
}

private struct BriefingChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }

    let choices: [Choice]
}
