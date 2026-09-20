//
//  QuestionGenerator.swift
//  NOVA
//

import Foundation

/// Writes the card summary and the quiz question for a story.
///
/// A feed gives a headline and a sentence or two — never enough to ask a question with a
/// provably correct answer — so the text is generated from what the feed does supply.
///
/// IMPORTANT: the output is machine-written and nobody has checked it. It must not be
/// presented to real readers as verified reporting. See `MockNewsService.isDemoContent`.
struct QuestionGenerator: Sendable {
    /// ZeroAPI's undocumented chat endpoint. It proxies Groq and needs no key, which is
    /// the whole reason it's here: nothing secret ships in the binary.
    ///
    /// It is one person's free project and can change or disappear without notice, so
    /// every failure path below falls back to something the reader can still use.
    static let endpoint = URL(string: "https://zeroapi.in/api/ai")!

    /// A non-reasoning model on purpose. The `openai/gpt-oss-*` models ZeroAPI's own
    /// tools default to spend the entire `max_tokens` budget on a `reasoning` field and
    /// return empty `content` — they look like a parse failure and aren't.
    static let model = "llama-3.1-8b-instant"

    static let summaryWordLimit = 50

    var endpoint: URL = QuestionGenerator.endpoint
    var session: URLSession = .shared

    /// Rewrites each story's summary and pairs it with a question.
    ///
    /// Runs concurrently so one slow request doesn't serialise the other four, and
    /// returns stories in their original order regardless of which finished first.
    /// What a batch produced, plus whether the endpoint asked us to slow down.
    ///
    /// The flag exists because a rate-limited batch and a batch of genuinely unusable
    /// answers look identical from the outside — both yield no questions — but they call
    /// for opposite responses: back off, versus carry on to the next batch.
    struct BatchResult {
        var deck: [(story: Story, question: Question?)]
        var wasRateLimited: Bool
        /// How long the server asked us to wait, when it said so.
        var retryAfter: TimeInterval?
    }

    func generateReporting(for stories: [Story]) async -> BatchResult {
        // One probe first. If the endpoint is rate-limiting, firing the whole batch only
        // deepens the lockout — the observed window is minutes, not seconds.
        guard let first = stories.first else {
            return BatchResult(deck: [], wasRateLimited: false)
        }

        do {
            _ = try await generate(for: first)
        } catch GenerationError.rateLimited(let retryAfter) {
            return BatchResult(
                deck: stories.map { ($0.withSummary($0.summary.truncatedToWords(Self.summaryWordLimit)), nil) },
                wasRateLimited: true,
                retryAfter: retryAfter
            )
        } catch {
            // Not a rate limit — let the normal path run and judge the batch on results.
        }

        let deck = await generate(for: stories)
        let allFailed = !deck.isEmpty && deck.allSatisfy { $0.question == nil }
        return BatchResult(deck: deck, wasRateLimited: allFailed)
    }

    func generate(for stories: [Story]) async -> [(story: Story, question: Question?)] {
        await withTaskGroup(of: (Int, Story, Question?).self) { group in
            for (index, story) in stories.enumerated() {
                group.addTask {
                    let generated = try? await self.generate(for: story)
                    guard let generated else {
                        // No question, but the card still reads: the feed's own summary,
                        // trimmed. A round short one question beats a dead deck.
                        return (index, story.withSummary(
                            story.summary.truncatedToWords(Self.summaryWordLimit)
                        ), nil)
                    }
                    return (index, story.withSummary(generated.summary), generated.question(for: story))
                }
            }

            var results: [(Int, Story, Question?)] = []
            for await result in group { results.append(result) }
            return results
                .sorted { $0.0 < $1.0 }
                .map { (story: $0.1, question: $0.2) }
        }
    }

    // MARK: - One story

    private func generate(for story: Story) async throws -> Generated {
        // One retry only. The failure modes worth retrying are a dropped connection and
        // a model that ignored the JSON instruction; both clear on a second attempt, and
        // anything that doesn't isn't worth making the reader wait for.
        //
        // A rate limit is explicitly *not* retried — a second request is exactly what the
        // server just asked us not to send, and it lengthens the limit for everyone
        // behind it.
        do {
            return try await request(for: story)
        } catch let error as GenerationError {
            if case .rateLimited = error { throw error }
            return try await request(for: story)
        } catch {
            return try await request(for: story)
        }
    }

    private func request(for story: Story) async throws -> Generated {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The endpoint is the site's own; it answers without these, but sending them
        // keeps us honest about where the traffic is coming from.
        request.setValue("https://zeroapi.in", forHTTPHeaderField: "Origin")
        request.timeoutInterval = 15

        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                toolId: "mcqGenerator",
                model: Self.model,
                maxTokens: 400,
                temperature: 0.3,
                messages: [
                    .init(role: "system", content: Self.systemPrompt),
                    .init(role: "user", content: Self.userPrompt(for: story))
                ]
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GenerationError.badResponse
        }
        // 429 is the common failure here, and it must be distinguishable: retrying it
        // immediately is what turns a brief limit into a sustained one.
        guard http.statusCode != 429 else {
            // The body carries the server's own wait: {"error":…,"retryAfter":247}.
            // Honouring it is the difference between backing off and hammering someone's
            // free service until it locks us out for longer.
            throw GenerationError.rateLimited(retryAfter: Self.retryAfter(in: data))
        }
        guard (200..<300).contains(http.statusCode) else { throw GenerationError.badResponse }

        let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content, !content.isEmpty else {
            throw GenerationError.emptyContent
        }

        return try Generated(decoding: content)
    }

    // MARK: - Prompts

    private static let systemPrompt = """
        You write quiz questions for a news app.

        Return STRICT JSON and nothing else. No markdown, no code fences, no preamble.

        Shape:
        {"summary": string, "question": string, "answers": [string], "correctIndex": int}

        Rules:
        - "summary" retells the story in at most \(summaryWordLimit) words, plainly, \
        with no opinion and no invented detail.
        - "question" must be answerable from your own summary alone, and must have \
        exactly one defensible answer.
        - "answers" holds 4 options. The wrong ones must be plausible and of the same \
        kind as the right one — if the answer is a number, the others are numbers of a \
        similar size.
        - "correctIndex" is the 0-based index of the correct option.
        - Never invent facts that are not in the story you were given.
        """

    /// Pulls `retryAfter` (seconds) out of a 429 body, if it's there.
    static func retryAfter(in data: Data) -> TimeInterval? {
        struct Limit: Decodable { let retryAfter: TimeInterval? }
        return try? JSONDecoder().decode(Limit.self, from: data).retryAfter
    }

    private static func userPrompt(for story: Story) -> String {
        """
        Headline: \(story.title)
        Source: \(story.source)
        Story: \(story.summary)
        """
    }
}

// MARK: - Wire types

private struct ChatRequest: Encodable {
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

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }

    let choices: [Choice]
}

/// What the model is asked to return.
private struct Generated: Decodable {
    let summary: String
    let question: String
    let answers: [String]
    let correctIndex: Int

    /// Models wrap JSON in ``` fences often enough that trimming to the outermost braces
    /// is cheaper than another round trip to ask for it again.
    init(decoding content: String) throws {
        guard
            let start = content.firstIndex(of: "{"),
            let end = content.lastIndex(of: "}"),
            start < end
        else {
            throw GenerationError.notJSON
        }

        let json = String(content[start...end])
        self = try JSONDecoder().decode(Generated.self, from: Data(json.utf8))

        guard !self.question.isEmpty,
              answers.count >= 2,
              answers.indices.contains(correctIndex)
        else {
            // A question whose correct answer isn't in its own options would score every
            // attempt wrong, which is worse for the reader than having no question.
            throw GenerationError.unusable
        }
    }

    func question(for story: Story) -> Question {
        Question(
            id: QuestionID("question-\(story.id.rawValue)"),
            storyID: story.id,
            prompt: question,
            answers: answers,
            correctAnswerIndex: correctIndex
        )
    }
}

enum GenerationError: Error {
    case badResponse
    case emptyContent
    case notJSON
    case unusable
    /// The endpoint returned 429. Callers should back off for `retryAfter` seconds
    /// (the server tells us how long) rather than guessing.
    case rateLimited(retryAfter: TimeInterval?)
}

private extension Story {
    func withSummary(_ summary: String) -> Story {
        Story(
            id: id,
            title: title,
            summary: summary,
            source: source,
            category: category,
            publishedAt: publishedAt,
            artwork: artwork
        )
    }
}
