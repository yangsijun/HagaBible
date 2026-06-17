//
//  TTSMiniPlayerView.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import SwiftUI

@available(iOS 26.0, *)
struct TTSMiniPlayerView: View {
    let ttsViewModel: TTSViewModel
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ttsViewModel.chapterTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text("\(ttsViewModel.currentVerseIndex + 1) / \(ttsViewModel.totalVerses)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(.rect)
            .onTapGesture(perform: onTap)
            // Control buttons
            HStack(spacing: 8) {
                // Play/Pause button
                Button {
                    ttsViewModel.togglePlayPause()
                } label: {
                    Image(systemName: ttsViewModel.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 38, height: 38)
                        .contentShape(.rect)
                        .contentTransition(.symbolEffect(.replace.downUp))
                        // Animate the play/pause symbol swap at render time. A withAnimation at
                        // the tap site didn't take here because playbackState is an @Observable
                        // computed value; an implicit animation keyed on the state animates the
                        // replace however it's triggered (tap, remote command, auto-advance).
                        .animation(.smooth(duration: 0.3), value: ttsViewModel.playbackState)
                }
                .buttonStyle(.plain)

                // Next chapter button (expanded only)
                if placement == .expanded {
                    Button {
                        ttsViewModel.goToNextChapter()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .frame(width: 38, height: 38)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // No `.id(placement)`: `placement` already drives reactive re-evaluation through
        // @Environment, so forcing an identity change only made the inline↔expanded layout
        // (and its size change) rebuild abruptly instead of animating with the tab bar.
    }

    private var currentVerseNumber: Int {
        guard !ttsViewModel.verses.isEmpty,
              ttsViewModel.currentVerseIndex < ttsViewModel.verses.count else {
            return 1
        }
        return ttsViewModel.verses[ttsViewModel.currentVerseIndex].verse
    }
}
