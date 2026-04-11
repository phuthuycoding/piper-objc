import Foundation
import piper_objc

final class PrefetchManager {
    private let piper: piper_objc.Piper
    private let cache: AudioCache
    private let modelPath: String
    private let prefetchQueue = OperationQueue()
    private var pendingKeys: Set<String> = []
    private let lock = NSLock()

    init(piper: piper_objc.Piper, cache: AudioCache, modelPath: String) {
        self.piper = piper
        self.cache = cache
        self.modelPath = modelPath
        prefetchQueue.maxConcurrentOperationCount = 1
        prefetchQueue.qualityOfService = .utility
        prefetchQueue.name = "com.piper.prefetch"
    }

    func prefetch(segment: AudioSegmentQueue.Segment) {
        let key = cacheKey(for: segment)
        if cache.cachedAudio(for: key) != nil { return }

        lock.lock()
        let keyStr = key.fileName
        guard !pendingKeys.contains(keyStr) else {
            lock.unlock()
            return
        }
        pendingKeys.insert(keyStr)
        lock.unlock()

        let operation = BlockOperation { [weak self] in
            guard let self else { return }
            let path = String.temporaryPath(extesnion: "wav")
            let semaphore = DispatchSemaphore(value: 0)

            self.piper.synthesize(segment.text, toFileAtPath: path) {
                semaphore.signal()
            }
            semaphore.wait()

            if FileManager.default.fileExists(atPath: path) {
                self.cache.store(audioAtPath: path, for: key)
                try? FileManager.default.removeItem(atPath: path)
            }

            self.lock.lock()
            self.pendingKeys.remove(keyStr)
            self.lock.unlock()
        }

        prefetchQueue.addOperation(operation)
    }

    func cachedPath(for segment: AudioSegmentQueue.Segment) -> URL? {
        cache.cachedAudio(for: cacheKey(for: segment))
    }

    func cancelAll() {
        prefetchQueue.cancelAllOperations()
        lock.lock()
        pendingKeys.removeAll()
        lock.unlock()
    }

    func cacheKey(for segment: AudioSegmentQueue.Segment) -> AudioCache.CacheKey {
        AudioCache.CacheKey(text: segment.text, speakerId: segment.speakerId, modelPath: modelPath)
    }
}
