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

    private(set) var totalSamplesScheduled: Int = 0
    private(set) var sampleRate: Int = 0
    private(set) var phonemeAlignments: [(phoneme: UInt32, sampleCount: Int)] = []

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
                sampleRate = Int(piper.sampleRate)
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
            totalSamplesScheduled += samples.count
            lock.unlock()

            samples.withUnsafeBufferPointer { ptr in
                guard let baseAddress = ptr.baseAddress else { return }
                audioEngine.scheduleBuffer(samples: baseAddress, count: samples.count)
            }
        } else {
            lock.unlock()
        }
    }

    @objc func piperDidReceiveAudioChunk(
        _ samples: UnsafePointer<Float>,
        withSize count: Int,
        sampleRate: Int,
        alignments: [PiperPhonemeAlignment]
    ) {
        lock.lock()
        for alignment in alignments {
            phonemeAlignments.append((phoneme: alignment.phoneme, sampleCount: Int(alignment.sampleCount)))
        }
        lock.unlock()
    }

    func flush() {
        lock.lock()
        let samples = accumulatedSamples
        accumulatedSamples.removeAll(keepingCapacity: true)
        totalSamplesScheduled += samples.count
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
        totalSamplesScheduled = 0
        sampleRate = 0
        phonemeAlignments.removeAll()
        lock.unlock()
    }

    func getAlignments() -> [(phoneme: UInt32, sampleCount: Int)] {
        lock.lock()
        defer { lock.unlock() }
        return phonemeAlignments
    }
}
#endif
