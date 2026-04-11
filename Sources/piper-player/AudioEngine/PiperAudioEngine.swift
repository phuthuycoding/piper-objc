#if canImport(AVFoundation)
import AVFoundation

final class PiperAudioEngine {
    enum EngineError: Error {
        case engineNotRunning
        case invalidFormat
    }

    enum State {
        case idle
        case playing
        case paused
    }

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitchNode = AVAudioUnitTimePitch()

    private var audioFormat: AVAudioFormat?
    private var scheduledBufferCount = 0
    private let stateLock = NSLock()
    private var completionHandler: (() -> Void)?
    private var _state: State = .idle

    var state: State {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _state
    }

    var rate: Float {
        get { timePitchNode.rate }
        set { timePitchNode.rate = max(0.25, min(4.0, newValue)) }
    }

    var pitch: Float {
        get { timePitchNode.pitch }
        set { timePitchNode.pitch = max(-2400, min(2400, newValue)) }
    }

    var volume: Float {
        get { playerNode.volume }
        set { playerNode.volume = max(0, min(1.0, newValue)) }
    }

    init() {
        setupAudioGraph()
    }

    private func setupAudioGraph() {
        engine.attach(playerNode)
        engine.attach(timePitchNode)
        engine.connect(playerNode, to: timePitchNode, format: nil)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: nil)
    }

    func prepare(sampleRate: Double) throws {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw EngineError.invalidFormat
        }
        audioFormat = format

        engine.connect(playerNode, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: format)

        engine.prepare()
        try engine.start()
        stateLock.lock()
        _state = .playing
        stateLock.unlock()
    }

    func scheduleBuffer(samples: UnsafePointer<Float>, count: Int, completion: (() -> Void)? = nil) {
        guard let format = audioFormat else { return }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }

        buffer.frameLength = AVAudioFrameCount(count)
        if let channelData = buffer.floatChannelData?[0] {
            channelData.update(from: samples, count: count)
        }

        stateLock.lock()
        scheduledBufferCount += 1
        stateLock.unlock()

        playerNode.scheduleBuffer(buffer) { [weak self] in
            guard let self else { return }
            completion?()

            let shouldComplete: Bool = self.stateLock.withLock {
                self.scheduledBufferCount -= 1
                return self.scheduledBufferCount <= 0
            }
            if shouldComplete {
                self.stateLock.lock()
                let handler = self.completionHandler
                self.stateLock.unlock()
                handler?()
            }
        }

        if !playerNode.isPlaying {
            stateLock.lock()
            let currentState = _state
            stateLock.unlock()
            if currentState == .playing {
                playerNode.play()
            }
        }
    }

    func setCompletionHandler(_ handler: (() -> Void)?) {
        stateLock.lock()
        completionHandler = handler
        stateLock.unlock()
    }

    func pause() {
        stateLock.lock()
        guard _state == .playing else {
            stateLock.unlock()
            return
        }
        _state = .paused
        stateLock.unlock()
        playerNode.pause()
    }

    func resume() {
        stateLock.lock()
        guard _state == .paused else {
            stateLock.unlock()
            return
        }
        _state = .playing
        stateLock.unlock()
        playerNode.play()
    }

    func stop() {
        playerNode.stop()
        playerNode.reset()
        if engine.isRunning {
            engine.stop()
        }
        stateLock.lock()
        scheduledBufferCount = 0
        completionHandler = nil
        _state = .idle
        stateLock.unlock()
    }

    var isPlaying: Bool {
        state == .playing && playerNode.isPlaying
    }
}

extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
#endif
