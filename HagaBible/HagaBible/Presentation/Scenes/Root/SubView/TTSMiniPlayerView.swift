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
        HStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ttsService.bookName) \(ttsService.chapterNum)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text("\(ttsService.currentVerseIndex + 1) / \(ttsService.totalVerses)")
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
                    ttsService.togglePlayPause()
                } label: {
                    Image(systemName: ttsService.playbackState == .playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 38, height: 38)
                        .contentShape(.rect)
                        .contentTransition(.symbolEffect(.replace.downUp))
                }
                .buttonStyle(.plain)

                // Next chapter button (expanded only)
                if placement == .expanded {
                    Button {
                        goToNextChapter()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title3)
                            .frame(width: 38, height: 38)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
//            .animation(.easeInOut(duration: 0.2), value: isExpanded)
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .id(placement)
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
