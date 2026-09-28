//
//  VoiceBriefingPanel.swift
//  NOVA
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The sheet the floater opens: what NOVA is doing, what it heard, and what it read.
///
/// Reading surface, so paper. The row being read is the only one at full strength, and
/// the rest step back. That uses opacity, not marigold, because nothing here is earned.
struct VoiceBriefingPanel: View {
    @Environment(VoiceAssistant.self) private var voice
    @Environment(NewsStore.self) private var store
    @Environment(SoundPlayer.self) private var sound
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("readerName") private var readerName = ""
    @AppStorage("voiceLanguage") private var languageRaw = VoiceLanguage.preferred().rawValue

    private var chosenLanguage: VoiceLanguage { VoiceLanguage(rawValue: languageRaw) ?? .english }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            status
            if let briefing = voice.briefing {
                list(briefing)
            } else {
                Spacer(minLength: 0)
            }
            controls
        }
        .padding(Nova.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Nova.ink)
        .presentationBackground(Nova.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: begin)
        // Closing the sheet is a stop. Nothing should keep talking once it's gone.
        .onDisappear { voice.stop() }
    }

    private func begin() {
        voice.start(pool: store.allStories, readerName: readerName, language: chosenLanguage, audio: sound)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Ask NOVA")
                .font(Nova.display(.title2))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            languageChip
        }
    }

    private var languageChip: some View {
        HStack(spacing: 0) {
            ForEach(VoiceLanguage.allCases, id: \.self) { language in
                let selected = voice.language == language
                Button {
                    languageRaw = language.rawValue
                    // A new language is a new question: start over in it.
                    begin()
                } label: {
                    Text(language.chipTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 32)
                        .foregroundStyle(selected ? Nova.paper : Nova.ink)
                        .background(selected ? Nova.ink : .clear, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(language == .english ? "English" : "Hindi")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .overlay(Capsule().strokeBorder(Nova.hairline))
    }

    // MARK: - Status

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statusTitle)
                .novaMeta()
                .foregroundStyle(.secondary)

            switch voice.phase {
            case .greeting:
                Text(voice.language.greeting(name: readerName))
                    .font(Nova.reading(.title3))
            case .listening, .thinking:
                Text(voice.transcript.isEmpty ? "…" : "“\(voice.transcript)”")
                    .font(Nova.reading(.title3))
            case .failed(.permissionDenied):
                Text("NOVA needs the microphone and speech recognition to hear your question.")
                    .font(Nova.reading(.body))
                if let url = VoiceSettings.url {
                    Button("Open Settings") { openURL(url) }
                        .buttonStyle(PaperButtonStyle())
                }
            case .failed(.storiesLoading):
                Text("Stories are still loading. Try again in a moment.")
                    .font(Nova.reading(.body))
            case .failed(.nothingHeard):
                Text("I didn't catch that. Tap Ask again and say a topic, like “tech news”.")
                    .font(Nova.reading(.body))
            case .failed(.briefingFailed):
                Text("I couldn't put a briefing together. Try again in a moment.")
                    .font(Nova.reading(.body))
            case .idle, .speaking, .done:
                EmptyView()
            }

            if voice.briefing?.tier.isMachineWritten == true {
                // Machine-written and unchecked, so it must not read as verified reporting.
                Text("AI-written · unchecked")
                    .novaMeta()
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusTitle: String {
        switch voice.phase {
        case .idle: String(localized: "Ready")
        case .greeting: String(localized: "Speaking")
        case .listening: String(localized: "Listening")
        case .thinking: String(localized: "Finding stories")
        case .speaking: String(localized: "Briefing")
        case .done: String(localized: "Done")
        case .failed: String(localized: "Couldn't brief you")
        }
    }

    // MARK: - List

    private func list(_ briefing: Briefing) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(briefing.items.enumerated()), id: \.element.id) { index, item in
                    Button { open(item.storyID) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(Nova.meta(.subheadline, weight: .medium))
                                .frame(width: 22, alignment: .trailing)
                            Text(item.line)
                                .font(Nova.reading(.body))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 12)
                        .opacity(isDimmed(index) ? 0.45 : 1)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityHint("Opens the story")

                    Rectangle().fill(Nova.hairline).frame(height: 1)
                }
            }
            .animation(reduceMotion ? nil : Nova.Motion.settle, value: voice.phase)
        }
    }

    /// While a line is being read, every other line steps back.
    private func isDimmed(_ index: Int) -> Bool {
        if case .speaking(let current) = voice.phase { return current != index }
        return false
    }

    private func open(_ id: StoryID) {
        voice.stop()
        dismiss()
        router.tab = .home
        router.pushHome(.story(id))
    }

    // MARK: - Controls

    private var controls: some View {
        Group {
            if voice.isActive {
                Button("Stop") { voice.stop() }
            } else {
                Button("Ask again", action: begin)
            }
        }
        .buttonStyle(PaperButtonStyle())
    }
}

/// The app's page in Settings, where a denied permission is turned back on.
/// Settings deep links only exist on iOS and visionOS; elsewhere there is no button.
enum VoiceSettings {
    static var url: URL? {
        #if os(iOS) || os(visionOS)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}
