//
//  SoundPlayer.swift
//  NOVA
//

import AVFoundation
import Foundation
import Observation

/// Plays the game's short effects.
///
/// Files are preloaded so a shot never waits on disk, and the audio session is
/// `ambient`: NOVA's sounds respect the silent switch and never interrupt whatever the
/// player is already listening to.
@Observable
final class SoundPlayer {
    enum Effect: String, CaseIterable {
        case shot
        case score
        /// Clipped the rim and bounced out.
        case rim
        case miss
    }

    /// Off keeps the game silent without callers needing to care.
    var isEnabled = true

    /// True while the voice briefing owns the audio session. Effects stay quiet so a shot
    /// sound can't land in the middle of a spoken line.
    private(set) var isVoiceActive = false

    private var players: [Effect: AVAudioPlayer] = [:]

    init() {
        configureSession()
        for effect in Effect.allCases {
            players[effect] = Self.makePlayer(for: effect)
        }
    }

    func play(_ effect: Effect) {
        guard isEnabled, !isVoiceActive, let player = players[effect] else { return }
        player.currentTime = 0
        player.play()
    }

    // MARK: - Voice

    /// Hands the session to the voice briefing: recording plus spoken playback, over the
    /// speaker rather than the earpiece, ducking anything else that's playing.
    func beginVoice() {
        isVoiceActive = true
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Without the session the recogniser gets no audio. The listener then hears
            // nothing, and the assistant says so; nothing here needs to.
        }
        #endif
    }

    /// Takes the session back to `.ambient`, so the game keeps respecting the silent switch.
    func endVoice() {
        isVoiceActive = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        configureSession()
    }

    // MARK: - Setup

    private func configureSession() {
        #if os(iOS) || os(visionOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Sound is a nicety here. If the session won't start, the game still works.
        }
        #endif
    }

    private static func makePlayer(for effect: Effect) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
            return nil
        }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }
}

extension SoundPlayer: VoiceAudioSession {}
