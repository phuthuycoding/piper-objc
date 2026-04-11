#if canImport(AVFoundation)
import AVFoundation
import Foundation
import piper_objc

public final class AudioSegmentQueue: @unchecked Sendable {
    public struct Segment: Sendable {
        public let text: String
        public let speakerId: Int32
        public let metadata: [String: String]?

        public init(text: String, speakerId: Int32 = 0, metadata: [String: String]? = nil) {
            self.text = text
            self.speakerId = speakerId
            self.metadata = metadata
        }
    }

    public enum State: Equatable {
        case idle
        case playing(segmentIndex: Int)
        case paused(segmentIndex: Int)
    }

    private let piper: piper_objc.Piper
    private let audioEngine: PiperAudioEngine
    private let cache: AudioCache
    private let prefetchManager: PrefetchManager
    private let serialQueue = DispatchQueue(label: "com.piper.segmentqueue")
    private var playTask: Task<Void, Never>?

    private var _segments: [Segment] = []
    private var _currentIndex: Int = 0
    private var _state: State = .idle

    public var segments: [Segment] {
        serialQueue.sync { _segments }
    }

    public var currentIndex: Int {
        serialQueue.sync { _currentIndex }
    }

    public var state: State {
        serialQueue.sync { _state }
    }

    public var prefetchCount: Int = 2
    public weak var delegate: AudioSegmentQueueDelegate?

    public var playbackRate: Float {
        get { audioEngine.rate }
        set { audioEngine.rate = newValue }
    }

    public var pitch: Float {
        get { audioEngine.pitch }
        set { audioEngine.pitch = newValue }
    }

    init(piper: piper_objc.Piper, audioEngine: PiperAudioEngine, cache: AudioCache, params: PiperPlayer.Params) {
        self.piper = piper
        self.audioEngine = audioEngine
        self.cache = cache
        self.prefetchManager = PrefetchManager(
            cache: cache,
            modelPath: params.modelPath,
            configPath: params.configPath,
            espeakNGData: params.espeakNGData
        )
    }

    public func replaceAll(_ newSegments: [Segment]) {
        stop()
        serialQueue.sync {
            _segments = newSegments
            _currentIndex = 0
        }
    }

    public func append(_ newSegments: [Segment]) {
        serialQueue.sync {
            _segments.append(contentsOf: newSegments)
        }
    }

    public func play() {
        let isEmpty = serialQueue.sync { _segments.isEmpty }
        guard !isEmpty else { return }
        let index = serialQueue.sync { _currentIndex }
        playFromIndex(index)
    }

    public func pause() {
        let idx: Int? = serialQueue.sync {
            guard case .playing(let i) = _state else { return nil }
            return i
        }
        guard let idx else { return }
        audioEngine.pause()
        serialQueue.sync { _state = .paused(segmentIndex: idx) }
        delegate?.queue(self, didChangeState: .paused(segmentIndex: idx))
    }

    public func resume() {
        let wasPaused: Bool = serialQueue.sync {
            guard case .paused = _state else { return false }
            return true
        }
        guard wasPaused else { return }
        audioEngine.resume()
        let idx = serialQueue.sync {
            _state = .playing(segmentIndex: _currentIndex)
            return _currentIndex
        }
        delegate?.queue(self, didChangeState: .playing(segmentIndex: idx))
    }

    public func skipForward() {
        let canSkip = serialQueue.sync { _currentIndex + 1 < _segments.count }
        guard canSkip else { return }
        let nextIndex = serialQueue.sync { _currentIndex + 1 }
        playFromIndex(nextIndex)
    }

    public func skipBackward() {
        let canSkip = serialQueue.sync { _currentIndex > 0 }
        guard canSkip else { return }
        let prevIndex = serialQueue.sync { _currentIndex - 1 }
        playFromIndex(prevIndex)
    }

    public func seek(to index: Int) {
        let valid = serialQueue.sync { index >= 0 && index < _segments.count }
        guard valid else { return }
        playFromIndex(index)
    }

    public func stop() {
        playTask?.cancel()
        playTask = nil
        audioEngine.stop()
        prefetchManager.cancelAll()
        serialQueue.sync { _state = .idle }
        delegate?.queue(self, didChangeState: .idle)
    }

    private func playFromIndex(_ index: Int) {
        playTask?.cancel()
        audioEngine.stop()
        prefetchManager.cancelAll()

        serialQueue.sync {
            _currentIndex = index
            _state = .playing(segmentIndex: index)
        }
        delegate?.queue(self, didChangeState: .playing(segmentIndex: index))

        playTask = Task { [weak self] in
            guard let self else { return }
            await self.playLoop()
        }
    }

    private func playLoop() async {
        while true {
            guard !Task.isCancelled else { return }

            let (segment, index, count) = serialQueue.sync {
                (_currentIndex < _segments.count ? _segments[_currentIndex] : nil,
                 _currentIndex,
                 _segments.count)
            }

            guard let segment, index < count else { break }

            triggerPrefetch(from: index + 1)
            delegate?.queue(self, didStartSegment: index)

            do {
                try await playSegment(segment, atIndex: index)
            } catch is CancellationError {
                return
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            delegate?.queue(self, didFinishSegment: index)
            serialQueue.sync { _currentIndex += 1 }
        }

        serialQueue.sync { _state = .idle }
        delegate?.queue(self, didChangeState: .idle)
        delegate?.queueDidFinishAll(self)
    }

    private func playSegment(_ segment: Segment, atIndex index: Int) async throws {
        if let cachedURL = prefetchManager.cachedPath(for: segment) {
            try await playCachedFile(cachedURL)
            return
        }

        let streamingDelegate = PiperStreamingDelegate(audioEngine: audioEngine)
        streamingDelegate.setPiper(piper)
        piper.delegate = streamingDelegate

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let resumed = AtomicFlag()

                audioEngine.setCompletionHandler {
                    if resumed.setIfUnset() {
                        continuation.resume()
                    }
                }

                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self else {
                        if resumed.setIfUnset() {
                            continuation.resume(throwing: PiperPlayer.PlayerError.engineNotReady)
                        }
                        return
                    }
                    if Task.isCancelled {
                        if resumed.setIfUnset() {
                            continuation.resume(throwing: CancellationError())
                        }
                        return
                    }
                    self.piper.synthesize(segment.text)
                    streamingDelegate.flush()
                }
            }
        } onCancel: { [weak self] in
            self?.piper.cancel()
            self?.audioEngine.stop()
        }

        piper.delegate = nil

        let alignments = streamingDelegate.getAlignments()
        let sr = streamingDelegate.sampleRate
        if !alignments.isEmpty && sr > 0 {
            let wordTimings = TextTimingMapper.buildWordTimings(
                for: segment.text,
                phonemeAlignments: alignments,
                sampleRate: sr
            )
            for word in wordTimings {
                delegate?.queue(self, didStartSpeakingWord: word, inSegment: index)
            }
        }

        let totalSamples = streamingDelegate.totalSamplesScheduled
        if totalSamples > 0 && sr > 0 {
            delegate?.queue(self, progressUpdate: 1.0, inSegment: index)
        }
    }

    private func playCachedFile(_ url: URL) async throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw PiperPlayer.PlayerError.engineNotReady
        }
        try file.read(into: buffer)
        try audioEngine.prepare(sampleRate: format.sampleRate)

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let resumed = AtomicFlag()

                audioEngine.setCompletionHandler {
                    if resumed.setIfUnset() {
                        continuation.resume()
                    }
                }
                if let channelData = buffer.floatChannelData?[0] {
                    audioEngine.scheduleBuffer(samples: channelData, count: Int(buffer.frameLength))
                } else {
                    if resumed.setIfUnset() {
                        continuation.resume(throwing: PiperPlayer.PlayerError.engineNotReady)
                    }
                }
            }
        } onCancel: { [weak self] in
            self?.audioEngine.stop()
        }
    }

    private func triggerPrefetch(from startIndex: Int) {
        let (segments, count) = serialQueue.sync { (_segments, _segments.count) }
        let endIndex = min(startIndex + prefetchCount, count)
        for i in startIndex..<endIndex {
            prefetchManager.prefetch(segment: segments[i])
        }
    }
}

#endif
