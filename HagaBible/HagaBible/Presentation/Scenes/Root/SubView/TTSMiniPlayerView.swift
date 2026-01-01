//
//  TTSMiniPlayerView.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import SwiftUI

@available(iOS 26.0, *)
struct TTSMiniPlayerView: View {
    let ttsService: TTSService
    @Environment(\.tabViewBottomAccessoryPlacement) var placement
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Book/chapter:verse info
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ttsService.bookName) \(ttsService.chapterNum)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if placement == .expanded {
                        Text("\(ttsService.currentVerseIndex + 1) / \(ttsService.totalVerses)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Play/Pause button
                Button {
                    ttsService.togglePlayPause()
                } label: {
                    Image(systemName: ttsService.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                // Next chapter button (expanded only)
                if placement == .expanded {
                    Button {
                        goToNextChapter()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var currentVerseNumber: Int {
        guard !ttsService.verses.isEmpty,
              ttsService.currentVerseIndex < ttsService.verses.count else {
            return 1
        }
        return ttsService.verses[ttsService.currentVerseIndex].verse
    }

    private func goToNextChapter() {
        viewModel.goToNextChapter()
        viewModel.bibleNavigationUpdateTrigger.toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let language = viewModel.bibleVersion?.language ?? "Korean"
            ttsService.switchChapter(verses: viewModel.bibleVerseList, language: language)
        }
    }
}
