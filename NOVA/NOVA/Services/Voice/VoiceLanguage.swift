//
//  VoiceLanguage.swift
//  NOVA
//

import Foundation

/// The two languages the voice briefing listens and speaks in.
///
/// Indian English rather than en-US: the feeds are Indian and world news, and en-IN
/// recognises Indian names and places noticeably better.
enum VoiceLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case hindi = "hi"

    var localeIdentifier: String {
        switch self {
        case .english: "en-IN"
        case .hindi: "hi-IN"
        }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    /// What the language chip shows.
    var chipTitle: String {
        switch self {
        case .english: "EN"
        case .hindi: "हिं"
        }
    }

    /// Hindi when the phone's first language is Hindi, English otherwise.
    static func preferred(from languages: [String] = Locale.preferredLanguages) -> VoiceLanguage {
        languages.first?.hasPrefix("hi") == true ? .hindi : .english
    }

    // MARK: - Phrases

    func greeting(name: String) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .english:
            return name.isEmpty
                ? "Hi, what news summary do you want?"
                : "Hi \(name), what news summary do you want?"
        case .hindi:
            return name.isEmpty
                ? "नमस्ते, आप कौन सी खबरें सुनना चाहेंगे?"
                : "नमस्ते \(name), आप कौन सी खबरें सुनना चाहेंगे?"
        }
    }

    var didNotCatch: String {
        switch self {
        case .english: "Sorry, I didn't catch that. Which news would you like?"
        case .hindi: "माफ़ कीजिए, मैं समझ नहीं पाया। आप कौन सी खबरें सुनना चाहेंगे?"
        }
    }

    var storiesLoading: String {
        switch self {
        case .english: "Stories are still loading. Try again in a moment."
        case .hindi: "खबरें अभी लोड हो रही हैं। थोड़ी देर में फिर कोशिश करें।"
        }
    }

    /// Said in Hindi when this phone can't recognise Hindi, just before listening in English.
    static let hindiRecognitionUnavailable = "इस फ़ोन पर हिंदी पहचान उपलब्ध नहीं है, इसलिए मैं अंग्रेज़ी में सुनूँगा।"

    /// Added to a Hindi intro when the headlines couldn't be translated and are read in English.
    static let headlinesInEnglish = "शीर्षक अंग्रेज़ी में हैं।"

    func categoryName(_ category: StoryCategory) -> String {
        switch self {
        case .english:
            // "India" is a name, so it keeps its capital; the rest read as ordinary words.
            return category == .india ? category.title : category.title.lowercased()
        case .hindi:
            switch category {
            case .india: return "भारत"
            case .technology: return "टेक्नोलॉजी"
            case .business: return "बिज़नेस"
            case .world: return "दुनिया"
            case .science: return "विज्ञान"
            case .sports: return "खेल"
            case .entertainment: return "मनोरंजन"
            }
        }
    }

    /// The sentence before the highlights. `count` is what will actually be read, which
    /// can be fewer than asked for on a thin day.
    func intro(count: Int, category: StoryCategory?) -> String {
        switch self {
        case .english:
            guard let category else {
                return count == 1 ? "Here is today's top story." : "Here are today's top \(count) stories."
            }
            let name = categoryName(category)
            return count == 1 ? "Here is the top \(name) story." : "Here are the top \(count) \(name) stories."
        case .hindi:
            guard let category else { return "आज की \(count) मुख्य खबरें।" }
            return "\(categoryName(category)) की \(count) मुख्य खबरें।"
        }
    }
}
