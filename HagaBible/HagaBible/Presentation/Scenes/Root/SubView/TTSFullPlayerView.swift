//
//  TTSFullPlayerView.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import SwiftUI

struct TTSFullPlayerView: View {
    let ttsService: TTSService

    @State private var showSettings = false
    @State private var viewModel: BibleReaderViewModel = DIContainer.shared.resolve(type: BibleReaderViewModel.self)
    @State private var sliderValue: Double = 0
    @State private var isDragging = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Artwork area
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .frame(maxWidth: 280, maxHeight: 280)
                    .overlay {
                        Image(systemName: "book.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                    }
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)

                // Current verse info
                VStack(spacing: 8) {
                    Text("\(ttsService.bookName) \(ttsService.chapterNum)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                        .animation(.default, value: displayVerseNumber)

                    Text("\(displayVerseIndex + 1) / \(ttsService.totalVerses) verses")
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: displayVerseIndex)
                }

                // Draggable verse slider
                VStack(spacing: 4) {
                    Slider(
                        value: $sliderValue,
                        in: 0...Double(max(ttsService.totalVerses - 1, 1)),
                        step: 1
                    ) { editing in
                        isDragging = editing
                        if !editing {
                            ttsService.skipToVerse(at: Int(sliderValue))
                        }
                    }
                    .padding(.horizontal, 32)

                    HStack {
                        Text("1")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(ttsService.totalVerses)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 32)
                }
                .onChange(of: ttsService.currentVerseIndex) { _, newValue in
                    if !isDragging {
                        sliderValue = Double(newValue)
                    }
                }
                .onAppear {
                    sliderValue = Double(ttsService.currentVerseIndex)
                }

                // Playback controls
                HStack(spacing: 48) {
                    Button {
                        goToPreviousChapter()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.title)
                    }

                    Button {
                        ttsService.togglePlayPause()
                    } label: {
                        Image(systemName: ttsService.playbackState == .playing
                              ? "pause.circle.fill"
                              : "play.circle.fill")
                            .font(.system(size: 72))
                    }

                    Button {
                        goToNextChapter()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Stop button
                Button(role: .destructive) {
                    ttsService.stop()
                } label: {
                    Text("Stop Reading")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 32)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                TTSSettingsView(ttsService: ttsService)
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var displayVerseIndex: Int {
        isDragging ? Int(sliderValue) : ttsService.currentVerseIndex
    }

    private var displayVerseNumber: Int {
        guard !ttsService.verses.isEmpty,
              displayVerseIndex < ttsService.verses.count else {
            return 1
        }
        return ttsService.verses[displayVerseIndex].verse
    }

    private var currentVerseNumber: Int {
        guard !ttsService.verses.isEmpty,
              ttsService.currentVerseIndex < ttsService.verses.count else {
            return 1
        }
        return ttsService.verses[ttsService.currentVerseIndex].verse
    }

    private func goToPreviousChapter() {
        viewModel.goToPreviousChapter()
        viewModel.bibleNavigationUpdateTrigger.toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let language = viewModel.bibleVersion?.language ?? "Korean"
            ttsService.switchChapter(verses: viewModel.bibleVerseList, language: language)
        }
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

#Preview {
    TTSFullPlayerView(ttsService: TTSService())
}
