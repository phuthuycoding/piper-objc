import Foundation
import piper_objc

#if canImport(AVFoundation)
import AVFoundation
#endif

public final class PiperPlayer: @unchecked Sendable {
    public struct Params {
        public let modelPath: String
        public let configPath: String
        public let espeakNGData: String
        public init(modelPath: String,
                    configPath: String,
                    espeakNGData: String? = nil
        ) {
            self.modelPath = modelPath
            self.configPath = configPath
            self.espeakNGData = espeakNGData ?? ""
        }
    }

    public enum PlayerError: Error {
        case noPiperBackend
        case engineNotReady
    }

    private let piper: piper_objc.Piper
    private let params: Params

#if canImport(AVFoundation)
    private let audioEngine = PiperAudioEngine()
    private var _streamingDelegate: PiperStreamingDelegate?

    private var streamingDelegate: PiperStreamingDelegate {
        if let existing = _streamingDelegate {
            return existing
        }
        let delegate = PiperStreamingDelegate(audioEngine: audioEngine)
        delegate.setPiper(piper)
        _streamingDelegate = delegate
        return delegate
    }

    public lazy var cache = AudioCache()

    public lazy var queue: AudioSegmentQueue = {
        AudioSegmentQueue(piper: piper, audioEngine: audioEngine, cache: cache, params: params)
    }()

#if canImport(MediaPlayer)
    public lazy var mediaSession: MediaSessionManager = {
        MediaSessionManager(queue: queue)
    }()
#endif

    public var playbackRate: Float {
        get { audioEngine.rate }
        set { audioEngine.rate = newValue }
    }

    public var pitch: Float {
        get { audioEngine.pitch }
        set { audioEngine.pitch = newValue }
    }

    public var volume: Float {
        get { audioEngine.volume }
        set { audioEngine.volume = newValue }
    }
#endif

    public init(params: Params) throws {
        guard let piper = piper_objc.Piper(modelPath: params.modelPath,
                                           configPath: params.configPath,
                                           espeakNGData: params.espeakNGData) else {
            throw PlayerError.noPiperBackend
        }
        self.piper = piper
        self.params = params
#if canImport(AVFoundation)
        try FileManager.default.createTempFolderIfNeeded(at: String.temporaryFolderPath)
#endif
    }

    deinit {
#if canImport(AVFoundation)
        audioEngine.stop()
        try? FileManager.default.removeTempFolderIfNeeded(at: String.temporaryFolderPath)
#endif
    }

#if canImport(AVFoundation)
    public func play(text: String) async throws {
        try await playStreaming {
            self.piper.synthesize(text)
        }
    }

    public func play(ssml: String, speakerId: Int32 = 0) async throws {
        try await playStreaming {
            self.piper.synthesizeSSML(ssml, speakerId: speakerId)
        }
    }

    public func synthesizeToFile(text: String) async -> String? {
        let path = String.temporaryPath(fileExtension: "wav")
        await piper.synthesize(text, toFileAtPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    public func synthesizeSSMLToFile(ssml: String, speakerId: Int32 = 0) async -> String? {
        let path = String.temporaryPath(fileExtension: "wav")
        await piper.synthesizeSSML(ssml, speakerId: speakerId, toFileAtPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    public func pause() {
        audioEngine.pause()
    }

    public func resume() {
        audioEngine.resume()
    }

    public func stopAndCancel() {
        piper.cancel()
        audioEngine.stop()
        streamingDelegate.reset()
    }

    private func playStreaming(_ synthesize: @escaping () -> Void) async throws {
        stopAndCancel()

        let delegate = streamingDelegate
        piper.delegate = delegate

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { [weak self] (continuation: CheckedContinuation<Void, any Error>) in
                guard let self else {
                    continuation.resume(throwing: PlayerError.engineNotReady)
                    return
                }

                let resumed = AtomicFlag()

                self.audioEngine.setCompletionHandler {
                    if resumed.setIfUnset() {
                        continuation.resume()
                    }
                }

                DispatchQueue.global(qos: .userInitiated).async {
                    if Task.isCancelled {
                        if resumed.setIfUnset() {
                            continuation.resume(throwing: CancellationError())
                        }
                        return
                    }
                    synthesize()
                    delegate.flush()
                }
            }
        } onCancel: { [weak self] in
            self?.piper.cancel()
            self?.audioEngine.stop()
        }

        piper.delegate = nil
    }
#endif
}
