#if canImport(AVFoundation)
import AVFoundation
import piper_objc

final class PiperStreamingDelegate: NSObject, PiperDelegate, @unchecked Sendable {
    private let audioEngine: PiperAudioEngine
    private weak var piper: piper_objc.Piper?
    private var isPrepared = false
    private var accumulatedSamples: [Float] = []
    private let minBufferSize = 4096
    private let lock = NSLock()

    init(audioEngine: PiperAudioEngine) {
        self.audioEngine = audioEngine
        super.init()
    }

    func setPiper(_ piper: piper_objc.Piper) {
        lock.lock()
        self.piper = piper
        lock.unlock()
    }

    func piperDidReceiveSamples(_ samples: UnsafePointer<Float>, withSize count: Int) {
        lock.lock()
        if !isPrepared, let piper, piper.sampleRate > 0 {
            do {
                try audioEngine.prepare(sampleRate: Double(piper.sampleRate))
                isPrepared = true
            } catch {
                lock.unlock()
                return
            }
        }

        accumulatedSamples.append(contentsOf: UnsafeBufferPointer(start: samples, count: count))

        if accumulatedSamples.count >= minBufferSize {
            let samples = accumulatedSamples
            accumulatedSamples.removeAll(keepingCapacity: true)
            lock.unlock()

            samples.withUnsafeBufferPointer { ptr in
                guard let baseAddress = ptr.baseAddress else { return }
                audioEngine.scheduleBuffer(samples: baseAddress, count: samples.count)
            }
        } else {
            lock.unlock()
        }
    }

    func flush() {
        lock.lock()
        let samples = accumulatedSamples
        accumulatedSamples.removeAll(keepingCapacity: true)
        lock.unlock()

        guard !samples.isEmpty else { return }

        samples.withUnsafeBufferPointer { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            audioEngine.scheduleBuffer(samples: baseAddress, count: samples.count)
        }
    }

    func reset() {
        lock.lock()
        accumulatedSamples.removeAll()
        isPrepared = false
        lock.unlock()
    }
}
#endif
