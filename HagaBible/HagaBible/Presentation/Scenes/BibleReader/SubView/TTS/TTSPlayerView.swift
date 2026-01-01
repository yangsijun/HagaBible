//
//  TTSPlayerView.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import SwiftUI

struct TTSPlayerView: View {
    let ttsService: TTSService
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Current position info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(ttsService.bookName) \(ttsService.chapterNum):\(currentVerseNumber)")
                        .font(.headline)
                    Text("\(ttsService.currentVerseIndex + 1) / \(ttsService.totalVerses)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Playback controls
            HStack(spacing: 40) {
                Button {
                    ttsService.skipToPrevious()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(ttsService.currentVerseIndex == 0)

                Button {
                    ttsService.togglePlayPause()
                } label: {
                    Image(systemName: ttsService.playbackState == .playing
                          ? "pause.circle.fill"
                          : "play.circle.fill")
                        .font(.system(size: 52))
                }
                .buttonStyle(.plain)

                Button {
                    ttsService.skipToNext()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(ttsService.currentVerseIndex >= ttsService.totalVerses - 1)
            }

            // Stop button
            Button(role: .destructive) {
                ttsService.stop()
            } label: {
                Text("Stop")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
    }

    private var currentVerseNumber: Int {
        guard !ttsService.verses.isEmpty,
              ttsService.currentVerseIndex < ttsService.verses.count else {
            return 1
        }
        return ttsService.verses[ttsService.currentVerseIndex].verse
    }
}

#Preview {
    VStack {
        Spacer()
        TTSPlayerView(
            ttsService: TTSService(),
            showSettings: .constant(false)
        )
        .padding()
    }
}
