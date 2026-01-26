//
//  TTSFullPlayerView.swift
//  HagaBible
//
//  Created by 양시준 on 1/1/26.
//

import SwiftUI
import MediaPlayer
import AVFoundation
import Combine

struct TTSFullPlayerView: View {
    let ttsViewModel: TTSViewModel

    @State private var showSettings = false
    @State private var sliderValue: Double = 0
    @State private var isDragging = false

    // Calm gradient color palettes
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
        let seed = ttsViewModel.bookName.hashValue ^ ttsViewModel.chapterNum
        let index = abs(seed) % gradientPalettes.count
        return gradientPalettes[index]
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: currentGradient,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Artwork area
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 300, height: 300)
                    .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 10)
                    .overlay {
                        Image(systemName: "book.fill")
                            .font(.system(size: 100))
                            .foregroundStyle(.thickMaterial)
                    }

                Spacer()

                // Title and info section
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(ttsViewModel.bookName) \(ttsViewModel.chapterNum)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(.default, value: ttsViewModel.chapterNum)
                    }

                    Spacer()

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .foregroundStyle(.thinMaterial)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
                    .frame(height: 24)

                // Progress slider (Apple Music style)
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        let totalVerses = max(ttsViewModel.totalVerses - 1, 1)
                        let progress = sliderValue / Double(totalVerses)
                        let trackHeight: CGFloat = isDragging ? 16 : 8

                        ZStack(alignment: .leading) {
                            // Background track
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: trackHeight)

                            // Progress track
                            Capsule()
                                .fill(Color.white)
                                .frame(width: max(0, geometry.size.width * progress), height: trackHeight)
                        }
                        .frame(height: geometry.size.height)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                                    let rawValue = newProgress * Double(totalVerses)
                                    sliderValue = rawValue.rounded() // Snap to integer
                                }
                                .onEnded { _ in
                                    isDragging = false
                                    ttsViewModel.skipToVerse(at: Int(sliderValue))
                                }
                        )
                        .animation(.easeInOut(duration: 0.15), value: isDragging)
                    }
                    .frame(height: 20)

                    HStack {
                        Text("\(displayVerseIndex + 1)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .monospacedDigit()
                        Spacer()
                        Text("\(ttsViewModel.totalVerses) verses")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 24)
                .onChange(of: ttsViewModel.currentVerseIndex) { _, newValue in
                    if !isDragging {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sliderValue = Double(newValue)
                        }
                    }
                }
                .onAppear {
                    sliderValue = Double(ttsViewModel.currentVerseIndex)
                }

                Spacer()
                    .frame(height: 24)

                // Playback controls
                HStack(spacing: 56) {
                    Button {
                        ttsViewModel.goToPreviousChapter()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.thickMaterial)
                    }

                    Button {
                        ttsViewModel.togglePlayPause()
                    } label: {
                        Image(systemName: ttsViewModel.playbackState == .playing
                              ? "pause.fill"
                              : "play.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace.downUp))
                    }

                    Button {
                        ttsViewModel.goToNextChapter()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.thickMaterial)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Volume slider (Apple Music style)
                VolumeSliderView()
                    .padding(.horizontal, 24)

                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showSettings) {
            TTSSettingsView(ttsViewModel: ttsViewModel)
        }
        .presentationDragIndicator(.visible)
    }

    private var displayVerseIndex: Int {
        isDragging ? Int(sliderValue) : ttsViewModel.currentVerseIndex
    }

    private var displayVerseNumber: Int {
        guard !ttsViewModel.verses.isEmpty,
              displayVerseIndex < ttsViewModel.verses.count else {
            return 1
        }
        return ttsViewModel.verses[displayVerseIndex].verse
    }

    private var currentVerseNumber: Int {
        guard !ttsViewModel.verses.isEmpty,
              ttsViewModel.currentVerseIndex < ttsViewModel.verses.count else {
            return 1
        }
        return ttsViewModel.verses[ttsViewModel.currentVerseIndex].verse
    }
}

// MARK: - Custom Volume Slider with System Volume Control
struct VolumeSliderView: View {
    @State private var volume: Float = 0.5
    @State private var isDragging = false
    @StateObject private var volumeObserver = VolumeObserver()

    var body: some View {
        if PlatformHelper.isRunningOnMac {
            // macOS: AVAudioSession volume control is not available
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.footnote)
                    .foregroundStyle(.thinMaterial)
                Text("Use system volume controls")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        } else {
            // iOS: Full volume slider with system integration
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.footnote)
                    .foregroundStyle(.thinMaterial)

                GeometryReader { geometry in
                    let progress = CGFloat(volume)
                    let trackHeight: CGFloat = isDragging ? 10 : 6

                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .frame(height: trackHeight)

                        // Volume track
                        Capsule()
                            .fill(.thickMaterial)
                            .frame(width: max(0, geometry.size.width * progress), height: trackHeight)
                    }
                    .frame(height: geometry.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let newVolume = Float(min(max(0, value.location.x / geometry.size.width), 1))
                                volume = newVolume
                                SystemVolumeManager.setVolume(newVolume)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                    .animation(.easeInOut(duration: 0.15), value: isDragging)
                }
                .frame(height: 20)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.footnote)
                    .foregroundStyle(.thinMaterial)
            }
            .onAppear {
                volume = AVAudioSession.sharedInstance().outputVolume
            }
            .onReceive(volumeObserver.$volume) { newVolume in
                if !isDragging {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        volume = newVolume
                    }
                }
            }
        }
    }
}

// MARK: - Volume Observer (KVO for system volume changes)
class VolumeObserver: ObservableObject {
    @Published var volume: Float = 0.5
    private var observation: NSKeyValueObservation?

    init() {
        // AVAudioSession volume observation is iOS-only; skip on macOS
        guard !PlatformHelper.isRunningOnMac else { return }

        let audioSession = AVAudioSession.sharedInstance()
        volume = audioSession.outputVolume

        observation = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                if let newVolume = change.newValue {
                    self?.volume = newVolume
                }
            }
        }
    }

    deinit {
        observation?.invalidate()
    }
}

// MARK: - System Volume Manager
enum SystemVolumeManager {
    private static var volumeView: MPVolumeView?

    static func setVolume(_ volume: Float) {
        // MPVolumeView/UISlider are iOS-only; skip on macOS
        guard !PlatformHelper.isRunningOnMac else { return }

        if volumeView == nil {
            volumeView = MPVolumeView(frame: .zero)
        }

        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            slider.value = volume
        }
    }
}

#Preview {
    DIContainer.registerForPreview()
    return TTSFullPlayerView(ttsViewModel: DIContainer.shared.resolve(type: TTSViewModel.self))
}
