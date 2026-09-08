//
//  RecordingPlayerView.swift
//  HagaBible
//
//  Created by 양시준 on 6/16/26.
//

import SwiftUI

/// Full-screen player for a saved recording. Mirrors `TTSFullPlayerView`, but the
/// progress scrubber is time-based (current time / total duration) since a recording
/// is one continuous audio file rather than a sequence of discrete verses.
struct RecordingPlayerView: View {
    let viewModel: RecordingsViewModel
    let recording: Recording

    /// Scrubbed position (seconds) while the user is dragging the progress bar.
    @State private var sliderValue: Double = 0
    @State private var isDragging = false

    // Calm gradient color palettes (shared look with TTSFullPlayerView)
    private let gradientPalettes: [[Color]] = [
        [Color(red: 0.2, green: 0.3, blue: 0.4), Color(red: 0.1, green: 0.15, blue: 0.2)],      // Deep blue
        [Color(red: 0.25, green: 0.2, blue: 0.35), Color(red: 0.12, green: 0.1, blue: 0.18)],   // Purple night
        [Color(red: 0.2, green: 0.35, blue: 0.35), Color(red: 0.1, green: 0.18, blue: 0.18)],   // Teal
        [Color(red: 0.35, green: 0.25, blue: 0.2), Color(red: 0.18, green: 0.12, blue: 0.1)],   // Warm brown
        [Color(red: 0.3, green: 0.3, blue: 0.35), Color(red: 0.15, green: 0.15, blue: 0.18)],   // Slate gray
        [Color(red: 0.2, green: 0.3, blue: 0.3), Color(red: 0.1, green: 0.15, blue: 0.15)],     // Ocean
        [Color(red: 0.35, green: 0.3, blue: 0.25), Color(red: 0.18, green: 0.15, blue: 0.12)],  // Sand
        [Color(red: 0.25, green: 0.25, blue: 0.4), Color(red: 0.12, green: 0.12, blue: 0.2)],   // Indigo
    ]

    private var currentGradient: [Color] {
        // Overflow-safe modulo: abs(Int.min) would trap, and a raw hashValue % count
        // can be negative. ((x % n) + n) % n keeps the index in 0..<count.
        let count = gradientPalettes.count
        let index = ((recording.id.hashValue % count) + count) % count
        return gradientPalettes[index]
    }

    private var duration: TimeInterval {
        viewModel.playbackDuration
    }

    /// While dragging, show the scrubbed position; otherwise the live playback time.
    private var displayTime: TimeInterval {
        isDragging ? sliderValue : viewModel.playbackCurrentTime
    }

    /// `.compact` in iPhone landscape, where the portrait stack (300pt artwork over the
    /// controls) is taller than the sheet and clips at both ends.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack {
            LinearGradient(colors: currentGradient, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if verticalSizeClass == .compact {
                landscapeLayout
            } else {
                portraitLayout
            }
        }
        .preferredColorScheme(.light)
        .presentationDragIndicator(.visible)
        // Kept on the container, not inside a layout branch, so rotating between the
        // two layouts does not stop and restart playback.
        .onAppear {
            viewModel.play(recording)
        }
        .onDisappear {
            viewModel.stopPlayback()
        }
    }

    // MARK: - Layouts

    /// Apple Music-style stack: artwork, then title, progress, transport and volume.
    private var portraitLayout: some View {
        VStack(spacing: 0) {
            Spacer()

            PlayerArtworkTile(systemImage: "waveform")
                .frame(width: PlayerArtworkTile.portraitSize, height: PlayerArtworkTile.portraitSize)

            Spacer()

            titleRow
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 24)

            progressSection
                .padding(.horizontal, 24)

            Spacer()
                .frame(height: 24)

            playbackControls

            Spacer()

            // Volume slider (reused from TTSFullPlayerView.swift)
            VolumeSliderView()
                .padding(.horizontal, 24)

            Spacer()
        }
    }

    /// Compact-height layout, Apple Music style: a large artwork on the leading side
    /// and the same controls stacked beside it, so everything fits in an iPhone
    /// landscape sheet. Only iPhones in landscape have a compact vertical size class;
    /// iPad stays on `portraitLayout`.
    private var landscapeLayout: some View {
        HStack(spacing: 32) {
            PlayerArtworkTile(systemImage: "waveform")
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: PlayerArtworkTile.landscapeMaxSize, maxHeight: PlayerArtworkTile.landscapeMaxSize)

            VStack(spacing: 20) {
                titleRow
                progressSection
                playbackControls
                VolumeSliderView()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 28)
    }

    // MARK: - Sections

    private var titleRow: some View {
        HStack(alignment: .center) {
            Text(recording.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
        }
    }

    /// Progress scrubber (time-based, Apple Music style) with the time labels beneath it.
    private var progressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let total = max(duration, 0.01)
                let progress = min(max(displayTime / total, 0), 1)
                let trackHeight: CGFloat = isDragging ? 16 : 8
                // Floor the fill width at trackHeight so its leading cap stays a full
                // semicircle. A Capsule narrower than it is tall rounds by width/2,
                // leaving the track's rounded left end unfilled near 0:00.
                let fillWidth = progress > 0 ? max(trackHeight, geometry.size.width * progress) : 0

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: trackHeight)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: fillWidth, height: trackHeight)
                }
                .frame(height: geometry.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction = min(max(0, value.location.x / geometry.size.width), 1)
                            sliderValue = fraction * total
                        }
                        .onEnded { _ in
                            viewModel.seek(to: sliderValue)
                            isDragging = false
                        }
                )
                .animation(.easeInOut(duration: 0.15), value: isDragging)
            }
            .frame(height: 20)

            HStack {
                Text(RecordingPlaybackManager.timeString(displayTime))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
                Spacer()
                Text(RecordingPlaybackManager.timeString(duration))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()
            }
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 56) {
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 32))
                    .foregroundStyle(.thickMaterial)
            }

            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.playbackState == .playing
                      ? "pause.fill"
                      : "play.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace.downUp))
            }

            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 32))
                    .foregroundStyle(.thickMaterial)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DIContainer.registerForPreview()
    return RecordingPlayerView(
        viewModel: DIContainer.shared.resolve(type: RecordingsViewModel.self),
        recording: Recording(
            title: "마가복음 1장",
            bibleReference: "마가복음 1장",
            duration: 125,
            fileName: "preview.m4a"
        )
    )
}
