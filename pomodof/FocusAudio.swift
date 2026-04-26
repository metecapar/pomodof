import AVFoundation
import Combine

enum FocusSound: String, CaseIterable {
    case off   = "Off"
    case rain  = "Rain"
    case cafe  = "Café"
    case focus = "Focus"

    var icon: String {
        switch self {
        case .off:   return "speaker.slash"
        case .rain:  return "cloud.rain"
        case .cafe:  return "cup.and.saucer"
        case .focus: return "waveform"
        }
    }
}

@MainActor
class FocusAudioPlayer: ObservableObject {
    @Published var current: FocusSound = .off
    @Published var volume: Float = 0.5

    private let engine = AVAudioEngine()
    private let node   = AVAudioPlayerNode()
    private var ready  = false

    func select(_ sound: FocusSound) {
        stopEngine()
        current = sound
        guard sound != .off else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let buffer = Self.makeBuffer(for: sound)
            await MainActor.run { self.startPlaying(buffer) }
        }
    }

    func pause() {
        guard engine.isRunning else { return }
        node.pause()
    }

    func resume() {
        guard current != .off, engine.isRunning else { return }
        node.play()
    }

    func stopAll() {
        stopEngine()
        current = .off
    }

    func setVolume(_ v: Float) {
        volume = v
        engine.mainMixerNode.outputVolume = v
    }

    // MARK: - Private

    private func startPlaying(_ buffer: AVAudioPCMBuffer) {
        if !ready {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
            ready = true
        }
        engine.mainMixerNode.outputVolume = volume
        try? engine.start()
        node.play()
        node.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    private func stopEngine() {
        node.stop()
        if engine.isRunning { engine.stop() }
    }

    // MARK: - Noise generation (runs off main thread)

    nonisolated private static func makeBuffer(for sound: FocusSound) -> AVAudioPCMBuffer {
        let rate: Double = 44100
        let frames = AVAudioFrameCount(rate * 8)
        let fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
        buf.frameLength = frames
        let out = buf.floatChannelData![0]

        switch sound {
        case .rain:
            // Brown noise — low-frequency rumble closest to rainfall
            var b: Float = 0
            for i in 0..<Int(frames) {
                let w = Float.random(in: -1...1)
                b = (b + 0.02 * w) / 1.02
                out[i] = min(max(b * 3.5, -1), 1)
            }
        case .cafe:
            // Pink noise (Paul Kellet's refined method) — balanced mid-range hum
            var b0: Float = 0, b1: Float = 0, b2: Float = 0
            var b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
            for i in 0..<Int(frames) {
                let w = Float.random(in: -1...1)
                b0 = 0.99886 * b0 + w * 0.0555179
                b1 = 0.99332 * b1 + w * 0.0750759
                b2 = 0.96900 * b2 + w * 0.1538520
                b3 = 0.86650 * b3 + w * 0.3104856
                b4 = 0.55000 * b4 + w * 0.5329522
                b5 = -0.7616 * b5 - w * 0.0168980
                out[i] = min(max((b0+b1+b2+b3+b4+b5+b6 + w*0.5362) * 0.11, -1), 1)
                b6 = w * 0.115926
            }
        case .focus:
            // White noise — broadband, masks distractions
            for i in 0..<Int(frames) {
                out[i] = Float.random(in: -1...1) * 0.25
            }
        case .off:
            break
        }
        return buf
    }
}
