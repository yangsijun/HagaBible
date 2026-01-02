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
                    Text("\(ttsViewModel.bookName) \(ttsViewModel.chapterNum)")
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
        .id(placement)
    }

    private var currentVerseNumber: Int {
        guard !ttsViewModel.verses.isEmpty,
              ttsViewModel.currentVerseIndex < ttsViewModel.verses.count else {
            return 1
        }
        return ttsViewModel.verses[ttsViewModel.currentVerseIndex].verse
    }
}
