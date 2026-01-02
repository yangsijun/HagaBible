//
//  TTSSettingsView.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import AVFoundation
import SwiftUI

struct TTSSettingsView: View {
    let ttsService: TTSService
    
    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    
    init(ttsService: TTSService) {
        self.ttsService = ttsService
        self.fontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    }

    var body: some View {
        NavigationStack {
            List {
                // Voice selection section
                Section {
                    NavigationLink {
                        VoiceSelectionView(
                            ttsService: ttsService,
                            language: "Korean",
                            voices: ttsService.koreanVoices,
                            selectedVoice: ttsService.selectedKoreanVoice
                        )
                    } label: {
                        HStack {
                            Text("Korean Voice")
                            Spacer()
                            Text(ttsService.selectedKoreanVoice?.name ?? "System Default")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        VoiceSelectionView(
                            ttsService: ttsService,
                            language: "English",
                            voices: ttsService.englishVoices,
                            selectedVoice: ttsService.selectedEnglishVoice
                        )
                    } label: {
                        HStack {
                            Text("English Voice")
                            Spacer()
                            Text(ttsService.selectedEnglishVoice?.name ?? "System Default")
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
                                get: { Double(ttsService.speechRate) },
                                set: { ttsService.setSpeechRate(Float($0)) }
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
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
            .navigationTitle("TTS Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var speedLabel: String {
        let rate = ttsService.speechRate
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
    let ttsService: TTSService
    let language: String
    let voices: [AVSpeechSynthesisVoice]
    let selectedVoice: AVSpeechSynthesisVoice?
    
    private var fontThemeManager: FontThemeManager = DIContainer.shared.resolve(type: FontThemeManager.self)
    
    init(
        ttsService: TTSService,
        language: String,
        voices: [AVSpeechSynthesisVoice],
        selectedVoice: AVSpeechSynthesisVoice?
    ) {
        self.ttsService = ttsService
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
                    ttsService.setVoice(nil, for: language)
                }

                ForEach(voices, id: \.identifier) { voice in
                    VoiceRow(
                        voice: voice,
                        isSelected: voice.identifier == selectedVoice?.identifier,
                        showRegion: language == "English" && voice.language == "en-GB"
                    ) {
                        ttsService.setVoice(voice, for: language)
                    }
                }
            } footer: {
                Text("More voices can be downloaded in Settings > Accessibility > Spoken Content > Voices")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: fontThemeManager.theme.backgroundColor))
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
    let voice: AVSpeechSynthesisVoice
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

                    Text(qualityLabel)
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

    private var qualityLabel: String {
        switch voice.quality {
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        default:
            return "Default"
        }
    }
}

#Preview {
    TTSSettingsView(ttsService: TTSService())
}
