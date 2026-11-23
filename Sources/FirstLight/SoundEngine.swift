import AVFoundation
import Apple1Core

/// All of the bench's sounds, synthesized — no audio assets. A low mains
/// hum while powered, key clicks, chip seat/eject, the power-on thunk,
/// and the ACI's two-tone FSK warble during cassette loads.
@MainActor
final class SoundEngine {
    private let engine = AVAudioEngine()
    private let fx = AVAudioPlayerNode()
    private let hum = AVAudioPlayerNode()
    private let tape = AVAudioPlayerNode()
    private let flyback = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    var enabled = true
    /// Keyboard thock can be silenced independently of everything else.
    var keyClicksEnabled = true
    /// Keep the mains hum running indefinitely (menu toggle); otherwise
    /// it fades away a few seconds after power-on.
    var persistentHum = false
    private var humRamp: Task<Void, Never>?
    private var tapeRamp: Task<Void, Never>?
    private var tapeSynth: Task<Void, Never>?
    /// Bumped by every tapePlay/tapeStop so audio still being synthesized
    /// for a cancelled load is never scheduled.
    private var tapeGeneration = 0

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.attach(fx)
        engine.attach(hum)
        engine.attach(tape)
        engine.attach(flyback)
        engine.connect(flyback, to: engine.mainMixerNode, format: format)
        flyback.volume = 0.05
        engine.connect(fx, to: engine.mainMixerNode, format: format)
        engine.connect(hum, to: engine.mainMixerNode, format: format)
        engine.connect(tape, to: engine.mainMixerNode, format: format)
        tape.volume = 0.4
        hum.volume = 0.16
        fx.volume = 0.5
        for (i, pitch) in [Float(88), 102, 117].enumerated() {
            buffers["click\(i)"] = make(duration: 0.06) { t, _ in
                let body = sin(t * pitch * 2 * .pi) * exp(-t * 58) * 0.7
                let thud = sin(t * pitch * 0.5 * 2 * .pi) * exp(-t * 45) * 0.25
                let knock = Float.random(in: -1...1) * exp(-t * 260) * 0.28
                let tick = sin(t * 1150 * 2 * .pi) * exp(-t * 700) * 0.05
                return body + thud + knock + tick
            }
        }
        buffers["seat"] = make(duration: 0.07) { t, _ in
            (sin(t * 170 * 2 * .pi) * 0.7 + Float.random(in: -1...1) * 0.15)
                * exp(-t * 60)
        }
        buffers["eject"] = make(duration: 0.06) { t, _ in
            (sin(t * 320 * 2 * .pi) * 0.5 + Float.random(in: -1...1) * 0.2)
                * exp(-t * 70)
        }
        buffers["thunk"] = make(duration: 0.35) { t, _ in
            (sin(t * 50 * 2 * .pi) * 0.8 + sin(t * 95 * 2 * .pi) * 0.3)
                * exp(-t * 12)
        }
        // ~2.4s of ACI-style FSK: pseudo-random bits at the real tones
        buffers["fsk"] = make(duration: 2.4) { t, _ in
            let bit = Int(t * 1350) % 7 < 3
            return sin(t * (bit ? 1000 : 2000) * 2 * .pi)
                * 0.22 * min(1, Float(t) * 8) * min(1, Float(2.4 - t) * 4)
        }
        buffers["pick"] = make(duration: 0.025) { t, _ in
            (sin(t * 900 * 2 * .pi) * 0.4 + Float.random(in: -1...1) * 0.3)
                * exp(-t * 220) * 0.6
        }
        // connector snap: sharp transient, then a tiny plastic body
        buffers["snap"] = make(duration: 0.05) { t, _ in
            let transient = Float.random(in: -1...1) * exp(-t * 600) * 0.9
            let body = sin(t * 1400 * 2 * .pi) * exp(-t * 180) * 0.35
            let clack = t > 0.018
                ? sin((t - 0.018) * 700 * 2 * .pi) * exp(-(t - 0.018) * 250) * 0.4
                : 0
            return transient + body + clack
        }
        buffers["unsnap"] = make(duration: 0.035) { t, _ in
            (Float.random(in: -1...1) * 0.4 + sin(t * 500 * 2 * .pi) * 0.4)
                * exp(-t * 160)
        }
        // the CRT's 15734 Hz horizontal-scan whine (loops cleanly:
        // duration chosen so whole cycles fit)
        buffers["flybackLoop"] = make(duration: 0.0998) { t, _ in
            sin(t * 15734 * 2 * .pi) * 0.5
        }
        // tape transport whirr (REW/FF)
        buffers["whirr"] = make(duration: 0.5) { t, _ in
            Float.random(in: -1...1) * 0.18
                * min(1, Float(t) * 30) * min(1, Float(0.5 - t) * 8)
                + sin(t * 80 * 2 * .pi) * 0.06
        }
        buffers["humLoop"] = make(duration: 1.0) { t, _ in
            sin(t * 60 * 2 * .pi) * 0.55 + sin(t * 120 * 2 * .pi) * 0.30
                + sin(t * 180 * 2 * .pi) * 0.10
        }
        try? engine.start()
    }

    private func make(duration: Double,
                      _ sample: (Float, Int) -> Float) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(44100 * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            data[i] = sample(Float(i) / 44100, i)
        }
        return buffer
    }

    /// Start the engine if needed; false if it can't run (no output device,
    /// a route change it couldn't recover from). AVAudioPlayerNode.play() on
    /// a stopped engine raises an Objective-C exception Swift can't catch,
    /// so every play() must be gated on this.
    private func engineReady() -> Bool {
        if engine.isRunning { return true }
        do { try engine.start() } catch { return false }
        return engine.isRunning
    }

    private func play(_ name: String) {
        guard enabled, let buffer = buffers[name], engineReady() else { return }
        fx.scheduleBuffer(buffer, at: nil)
        fx.play()
    }

    func keyClick() {
        guard keyClicksEnabled else { return }
        play("click\(Int.random(in: 0...2))")
    }
    func chipPick() { play("pick") }
    func chipSeat() { play("seat") }
    func chipEject() { play("eject") }
    func tapeLoad() { play("fsk") }

    /// T1: bit-true ACI audio. The waveform is generated from the
    /// tape's ACTUAL BYTES per the real encoding — 1 kHz cycles for 1,
    /// 2 kHz for 0 (the ROM reader's polarity, see TapeEncoding), MSB
    /// first, preceded by the asymmetric-cycle leader.
    /// (SB-Projects ACI doc: leader cycle ~565+455 µs.)
    nonisolated static let tapeRate = 44100.0

    /// Samples per phase, exactly as `tapeSamples` renders them.
    nonisolated private static func sampleCount(of phase: Double) -> Int {
        Int(tapeRate * phase / 1_000_000)
    }

    /// Length in seconds of the rendered phases, without rendering them.
    nonisolated static func tapeDuration<C: Collection<Double>>(phases: C) -> Double {
        Double(phases.reduce(0) { $0 + sampleCount(of: $1) }) / tapeRate
    }

    /// Render phases to samples. Pure, so it runs off the main actor.
    /// Returns [] if the calling task is cancelled part-way.
    nonisolated static func tapeSamples<C: Collection<Double>>(phases: C) -> [Float] {
        var samples: [Float] = []
        samples.reserveCapacity(phases.reduce(0) { $0 + sampleCount(of: $1) } + 16)
        var high = true
        for (index, phase) in phases.enumerated() {
            if index & 0xFFF == 0, Task.isCancelled { return [] }
            let n = sampleCount(of: phase)
            for i in 0..<n {
                let edge = min(1.0, Double(min(i, n - i)) / 6.0)
                samples.append(Float((high ? 1.0 : -1.0) * 0.32 * edge))
            }
            high.toggle()
        }
        return samples
    }

    /// Copy samples into a buffer; nil if it can't be allocated.
    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty, samples.count <= Int(UInt32.max),
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                  frameCapacity: AVAudioFrameCount(samples.count)),
              let data = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            data.update(from: src.baseAddress!, count: samples.count)
        }
        return buffer
    }

    struct TapeAudioError: Error {}

    /// Write bit-true tape audio to a .wav file (P1: tape save). The
    /// result is the same encoding the real ACI put on cassettes.
    func writeTapeWAV(bytes: [UInt8], to url: URL) throws {
        let phases = TapeEncoding.phases(bytes: bytes, leaderSeconds: 10)
        guard let buffer = makeBuffer(Self.tapeSamples(phases: phases))
        else { throw TapeAudioError() }
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
        ])
        try file.write(from: buffer)
    }

    /// Play bit-true tape audio for a load. In authentic mode the whole
    /// recording plays (fading to background after a few seconds); in
    /// showcase mode just the first moments of the same real waveform.
    /// Returns the full recording's duration at once; the samples are
    /// rendered off the main actor and start playing when ready.
    func tapePlay(bytes: [UInt8], authentic: Bool) -> Double {
        // authentic leader matches the bus playback exactly — the
        // sound IS what the machine hears
        let phases = TapeEncoding.phases(
            bytes: bytes, leaderSeconds: authentic ? 6.0 : 0.6)
        let duration = Self.tapeDuration(phases: phases)
        tapeGeneration += 1
        tapeSynth?.cancel()
        tapeRamp?.cancel()
        guard enabled else { return duration }
        // A showcase load is over in ~2.8 s: render only what it plays.
        var played = phases[...]
        if !authentic {
            var seconds = 0.0, count = 0
            while count < phases.count, seconds < Self.showcaseSeconds {
                seconds += phases[count] / 1_000_000
                count += 1
            }
            played = phases.prefix(count)
        }
        let generation = tapeGeneration
        let toRender = Array(played)
        let render = Task.detached(priority: .userInitiated) {
            SoundEngine.tapeSamples(phases: toRender)
        }
        tapeSynth = Task { [weak self] in
            // a stopped/superseded load stops the render too
            let samples = await withTaskCancellationHandler {
                await render.value
            } onCancel: {
                render.cancel()
            }
            guard let self, !Task.isCancelled,
                  generation == self.tapeGeneration,
                  self.engineReady(),
                  let buffer = self.makeBuffer(samples) else { return }
            self.startTape(buffer, fadeAfterAWhile: authentic)
        }
        return duration
    }

    private func startTape(_ buffer: AVAudioPCMBuffer, fadeAfterAWhile: Bool) {
        tape.volume = 0.5
        tape.scheduleBuffer(buffer, at: nil)
        tape.play()
        guard fadeAfterAWhile else { return }
        tapeRamp = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            for step in 0..<25 {
                guard !Task.isCancelled else { return }
                self?.tape.volume = 0.5 - (0.5 - 0.08) * Float(step + 1) / 25
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    /// Showcase loads finish after 170 frames (~2.8 s); a little slack.
    static let showcaseSeconds = 4.0

    func tapeStop() {
        tapeGeneration += 1
        tapeSynth?.cancel()
        tapeRamp?.cancel()
        tape.stop()
    }

    /// T9: the tube's flyback whine — that 15.7 kHz edge of hearing.
    private(set) var flybackRunning = false
    func flybackSet(_ on: Bool) {
        guard on != flybackRunning else { return }
        flybackRunning = on
        if on, enabled, let loop = buffers["flybackLoop"], engineReady() {
            flyback.scheduleBuffer(loop, at: nil, options: .loops)
            flyback.play()
        } else {
            flyback.stop()
        }
    }
    func connectorSnap() { play("snap") }
    func transportWhirr() { play("whirr") }
    func connectorPull() { play("unsnap") }

    func powerOn() {
        play("thunk")
        guard enabled, let loop = buffers["humLoop"], engineReady() else { return }
        humRamp?.cancel()
        hum.volume = 0.16
        hum.scheduleBuffer(loop, at: nil, options: .loops)
        hum.play()
        if !persistentHum {
            humRamp = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                for step in 0..<30 {
                    guard !Task.isCancelled else { return }
                    self?.hum.volume = 0.16 * Float(29 - step) / 29
                    try? await Task.sleep(for: .milliseconds(120))
                }
                self?.hum.stop()
            }
        }
    }

    func powerOff() {
        humRamp?.cancel()
        hum.stop()
    }
}
