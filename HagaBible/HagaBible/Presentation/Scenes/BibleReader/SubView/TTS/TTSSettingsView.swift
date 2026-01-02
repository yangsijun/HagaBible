//
//  TTSSettingsView.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import AVFoundation
import SwiftUI

struct TTSSettingsView: View {
    let ttsViewModel: TTSViewModel

    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)

    init(ttsViewModel: TTSViewModel) {
        self.ttsViewModel = ttsViewModel
        self.fontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    }

    var body: some View {
        NavigationStack {
            List {
                // Voice selection section
                Section {
                    NavigationLink {
                        VoiceSelectionView(
                            ttsViewModel: ttsViewModel,
                            language: "Korean",
                            voices: ttsViewModel.koreanVoices,
                            selectedVoice: ttsViewModel.selectedKoreanVoice
                        )
                    } label: {
                        HStack {
                            Text("Korean Voice")
                            Spacer()
                            Text(ttsViewModel.selectedKoreanVoice?.name ?? "System Default")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        VoiceSelectionView(
                            ttsViewModel: ttsViewModel,
                            language: "English",
                            voices: ttsViewModel.englishVoices,
                            selectedVoice: ttsViewModel.selectedEnglishVoice
                        )
                    } label: {
                        HStack {
                            Text("English Voice")
                            Spacer()
                            Text(ttsViewModel.selectedEnglishVoice?.name ?? "System Default")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Voice")
                }

                // Speech rate section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Speed: \(speedLabel)")
                            .font(.subheadline)

                        Slider(
                            value: Binding(
                                get: { Double(ttsViewModel.speechRate) },
                                set: { ttsViewModel.setSpeechRate(Float($0)) }
                            ),
                            in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate),
                            step: 0.05
                        )

                        HStack {
                            Text("Slower")
                                .font(.caption)
                            Spacer()
                            Text("Faster")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Reading Speed")
                }
            }
            .navigationTitle("TTS Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var speedLabel: String {
        let rate = ttsViewModel.speechRate
        let defaultRate = AVSpeechUtteranceDefaultSpeechRate

        if rate < defaultRate - 0.1 {
            return "Slow"
        } else if rate > defaultRate + 0.1 {
            return "Fast"
        } else {
            return "Normal"
        }
    }
}

// MARK: - Voice Selection View
private struct VoiceSelectionView: View {
    let ttsViewModel: TTSViewModel
    let language: String
    let voices: [TTSVoiceConfig]
    let selectedVoice: TTSVoiceConfig?

    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)

    init(
        ttsViewModel: TTSViewModel,
        language: String,
        voices: [TTSVoiceConfig],
        selectedVoice: TTSVoiceConfig?
    ) {
        self.ttsViewModel = ttsViewModel
        self.language = language
        self.voices = voices
        self.selectedVoice = selectedVoice
        self.fontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    }

    var body: some View {
        List {
            Section {
                // System Default option
                SystemDefaultVoiceRow(isSelected: selectedVoice == nil) {
                    ttsViewModel.setVoice(nil, for: language)
                }

                ForEach(voices) { voice in
                    VoiceRow(
                        voice: voice,
                        isSelected: voice.identifier == selectedVoice?.identifier,
                        showRegion: language == "English" && voice.isUKEnglish
                    ) {
                        ttsViewModel.setVoice(voice, for: language)
                    }
                }
            } footer: {
                Text("More voices can be downloaded in Settings > Accessibility > Spoken Content > Voices")
            }
        }
        .navigationTitle("\(language) Voice")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - System Default Voice Row
private struct SystemDefaultVoiceRow: View {
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                Text("System Default")
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice Row
private struct VoiceRow: View {
    let voice: TTSVoiceConfig
    let isSelected: Bool
    var showRegion: Bool = false
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(voice.name)
                            .foregroundStyle(.primary)
                        if showRegion {
                            Text("(UK)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(voice.quality.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DIContainer.registerForPreview()
    return TTSSettingsView(ttsViewModel: DIContainer.shared.resolve(type: TTSViewModel.self))
}
