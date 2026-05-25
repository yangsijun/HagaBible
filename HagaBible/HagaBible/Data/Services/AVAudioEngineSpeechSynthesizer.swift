//
//  AVAudioEngineSpeechSynthesizer.swift
//  HagaBible
//

import AVFoundation
import OSLog

/// `SpeechSynthesizer` that renders `AVSpeechSynthesizer` output to PCM buffers
/// and plays them through an `AVAudioEngine` + `AVAudioPlayerNode`.
///
/// Why not just call `AVSpeechSynthesizer.speak(_:)` (see `AVSpeechSynthesizerAdapter`)?
/// On device, speech-synth audio does **not** make the app the system "Now Playing"
/// app, so the Lock Screen / Control Center media card never appears — even with all
/// the `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` wiring in place. By driving
/// a real `AVAudioPlayerNode` on the app's `.playback` session, the app becomes the
/// active audio player and the card shows reliably. The engine is kept running for
/// the whole session (including pauses) so the card persists between verses.
///
/// Concurrency: the synthesizer's `write` buffer callback and the player node's
/// scheduling completions fire on arbitrary audio threads, so this type is
/// `@unchecked Sendable` and guards its mutable accounting with `lock`. Audio-graph
/// objects (`AVAudioEngine`, `AVAudioPlayerNode`) expose thread-safe transport
/// controls. Caller-facing state (`isSpeaking` / `isPaused` / `delegate` / voice
/// cache) is only ever touched on the main thread — the public protocol methods are
/// invoked on the main actor by `TTSPlaybackManager`, and audio-thread completions
/// hop back to main before mutating it.
final class AVAudioEngineSpeechSynthesizer: NSObject, SpeechSynthesizer, @unchecked Sendable {
    weak var delegate: SpeechSynthesizerDelegate?

    private(set) var isPaused: Bool = false
    private(set) var isSpeaking: Bool = false

    // MARK: - Audio graph (transport controls are thread-safe)

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let renderFormat: AVAudioFormat

    /// Renders utterances to buffers; never produces system audio itself.
    private var renderSynth = AVSpeechSynthesizer()

    // MARK: - Per-utterance accounting (guarded by `lock`)

    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var converterSourceFormat: AVAudioFormat?
    private var scheduledBufferCount = 0
    private var finishedBufferCount = 0
    private var writeCompleted = false
    /// Whether `speechDidStart` has already fired for the current utterance.
    private var startNotified = false
    /// Bumped on every `speak`/`stop`; stale callbacks compare against it and bail.
    private var generation = 0

    /// Main-thread-only voice lookup cache.
    private var voiceCache: [String: AVSpeechSynthesisVoice] = [:]

    // MARK: - Init

    override init() {
        renderFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 22_050,
            channels: 1,
            interleaved: false
        ) ?? AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!

        super.init()

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: renderFormat)
        engine.prepare()
    }

    deinit {
        playerNode.stop()
        engine.stop()
    }

    // MARK: - SpeechSynthesizer

    func speak(text: String, voice: TTSVoiceConfig?, rate: Float) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = mapToAVVoice(voice)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.3

        isSpeaking = true
        isPaused = false

        let gen: Int = lock.withLock {
            generation += 1
            scheduledBufferCount = 0
            finishedBufferCount = 0
            writeCompleted = false
            startNotified = false
            return generation
        }

        // Do NOT stop/reset the player node between verses. Keeping it continuously
        // "playing" is what keeps the app registered as the system Now Playing app —
        // the stop/reset gap was dropping the registration intermittently. The
        // previous verse has already drained (the manager calls speak again only
        // after speechDidFinish), so we simply queue the next verse onto the running
        // node. Real interruptions (start, chapter switch, skip, pause-restart) go
        // through stop()/recreate(), which DO reset the node.
        startEngineIfNeeded()
        if !playerNode.isPlaying {
            playerNode.play()
        }

        renderSynth.write(utterance) { [weak self] avBuffer in
            self?.handleRenderedBuffer(avBuffer, generation: gen)
        }
    }

    func pause() {
        isPaused = true
        isSpeaking = false
        // Engine keeps running so the app stays the Now Playing app while paused.
        playerNode.pause()
    }

    func resume() {
        isPaused = false
        isSpeaking = true
        startEngineIfNeeded()
        playerNode.play()
    }

    func stop() {
        isSpeaking = false
        isPaused = false
        // Invalidate in-flight render callbacks and clear scheduled buffers.
        lock.withLock {
            generation += 1
            scheduledBufferCount = 0
            finishedBufferCount = 0
            writeCompleted = false
        }
        playerNode.stop()
        playerNode.reset()
        // Engine is intentionally left running for a fast restart and to keep the
        // Now Playing card alive between verses.
    }

    func recreate() {
        stop()
        // A fresh synth drops any internal state from the previous render pass.
        renderSynth = AVSpeechSynthesizer()
    }

    func clearVoiceCache() {
        voiceCache.removeAll()
    }

    // MARK: - Rendering

    /// Called on the synth's render thread for each produced buffer; the final call
    /// delivers a zero-length buffer marking the end of the utterance.
    private func handleRenderedBuffer(_ avBuffer: AVAudioBuffer, generation gen: Int) {
        guard lock.withLock({ gen == generation }) else { return }
        guard let pcm = avBuffer as? AVAudioPCMBuffer else { return }

        if pcm.frameLength == 0 {
            let done: Bool = lock.withLock {
                writeCompleted = true
                return finishedBufferCount >= scheduledBufferCount
            }
            if done { finishUtterance(generation: gen) }
            return
        }

        guard let converted = convert(pcm) else { return }

        let isFirstBuffer: Bool = lock.withLock {
            scheduledBufferCount += 1
            guard !startNotified else { return false }
            startNotified = true
            return true
        }
        playerNode.scheduleBuffer(converted, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.bufferFinished(generation: gen)
        }
        if !playerNode.isPlaying {
            playerNode.play()
        }
        // Audio is now actually being output — let the manager (re)assert
        // nowPlayingInfo so iOS registers the app as the Now Playing app.
        if isFirstBuffer {
            notifyStart(generation: gen)
        }
    }

    /// Hops to the main thread to tell the delegate playback has begun.
    private func notifyStart(generation gen: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.lock.withLock({ gen == self.generation }) else { return }
            self.delegate?.speechDidStart()
        }
    }

    /// Converts a rendered buffer to `renderFormat`. The render callback delivers
    /// buffers serially, so the shared converter is touched one buffer at a time.
    private func convert(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let conv: AVAudioConverter? = lock.withLock {
            if converter == nil || converterSourceFormat != source.format {
                converter = AVAudioConverter(from: source.format, to: renderFormat)
                converterSourceFormat = source.format
            }
            return converter
        }
        guard let conv else { return nil }

        let ratio = renderFormat.sampleRate / source.format.sampleRate
        let capacity = AVAudioFrameCount(Double(source.frameLength) * ratio) + 1_024
        guard let output = AVAudioPCMBuffer(pcmFormat: renderFormat, frameCapacity: capacity) else {
            return nil
        }

        var consumed = false
        var error: NSError?
        let status = conv.convert(to: output, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return source
        }

        if status == .error {
            Logger.tts.error("TTS buffer conversion failed: \(error?.localizedDescription ?? "unknown")")
            return nil
        }
        return output.frameLength > 0 ? output : nil
    }

    /// Called on a player-node thread when a scheduled buffer finishes playing.
    private func bufferFinished(generation gen: Int) {
        let done: Bool = lock.withLock {
            guard gen == generation else { return false }
            finishedBufferCount += 1
            return writeCompleted && finishedBufferCount >= scheduledBufferCount
        }
        if done { finishUtterance(generation: gen) }
    }

    /// Hops to the main thread to flip caller-facing state and notify the delegate.
    /// The `isSpeaking` guard de-dupes the two possible callers (terminal write vs.
    /// last buffer played back).
    private func finishUtterance(generation gen: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.lock.withLock({ gen == self.generation }) else { return }
            guard self.isSpeaking else { return }
            self.isSpeaking = false
            self.delegate?.speechDidFinish()
        }
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            Logger.tts.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    // MARK: - Voice mapping (iOS)

    private func mapToAVVoice(_ config: TTSVoiceConfig?) -> AVSpeechSynthesisVoice? {
        guard let config else {
            return AVSpeechSynthesisVoice.speechVoices().first
        }

        if let cached = voiceCache[config.identifier] {
            return cached
        }

        if let voice = AVSpeechSynthesisVoice(identifier: config.identifier) {
            voiceCache[config.identifier] = voice
            return voice
        }

        let languageCode = config.language.isEmpty ? "ko-KR" : config.language
        if let languageVoice = AVSpeechSynthesisVoice(language: languageCode) {
            voiceCache[config.identifier] = languageVoice
            return languageVoice
        }

        return AVSpeechSynthesisVoice.speechVoices().first
    }
}
