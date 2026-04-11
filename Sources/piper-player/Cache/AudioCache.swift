import Foundation
import CommonCrypto

public final class AudioCache: @unchecked Sendable {
    public struct Configuration {
        public var maxDiskSizeBytes: UInt64
        public var cacheDirectory: URL
        public var enabled: Bool

        public init(
            maxDiskSizeBytes: UInt64 = 500_000_000,
            cacheDirectory: URL? = nil,
            enabled: Bool = true
        ) {
            self.maxDiskSizeBytes = maxDiskSizeBytes
            self.cacheDirectory = cacheDirectory ?? AudioCache.defaultCacheDirectory
            self.enabled = enabled
        }
    }

    public struct CacheKey: Hashable, Codable {
        public let textHash: String
        public let speakerId: Int32
        public let modelIdentifier: String

        public init(text: String, speakerId: Int32, modelPath: String) {
            self.textHash = Self.sha256(text)
            self.speakerId = speakerId
            self.modelIdentifier = Self.sha256(modelPath)
        }

        private static func sha256(_ string: String) -> String {
            let data = Data(string.utf8)
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes {
                _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
            }
            return hash.map { String(format: "%02x", $0) }.joined()
        }

        var fileName: String {
            "\(textHash)_\(speakerId)_\(modelIdentifier).wav"
        }
    }

    public private(set) var configuration: Configuration
    private let metadata: AudioCacheMetadata
    private let lock = NSLock()

    private static var defaultCacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("piper-audio-cache", isDirectory: true)
    }

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.metadata = AudioCacheMetadata(directory: configuration.cacheDirectory)
        try? FileManager.default.createDirectory(
            at: configuration.cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    public func cachedAudio(for key: CacheKey) -> URL? {
        guard configuration.enabled else { return nil }
        return lock.withLock {
            let path = filePath(for: key)
            guard FileManager.default.fileExists(atPath: path.path) else { return nil }
            metadata.touch(key: key)
            return path
        }
    }

    public func store(audioAt source: URL, for key: CacheKey) {
        guard configuration.enabled else { return }
        lock.withLock {
            let destination = filePath(for: key)
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: source, to: destination)
                let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? UInt64) ?? 0
                metadata.add(key: key, size: size)
                evictIfNeeded()
            } catch {}
        }
    }

    public func store(audioAtPath sourcePath: String, for key: CacheKey) {
        store(audioAt: URL(fileURLWithPath: sourcePath), for: key)
    }

    public var currentSizeBytes: UInt64 {
        lock.withLock { metadata.totalSize }
    }

    public func clearAll() {
        lock.withLock {
            try? FileManager.default.removeItem(at: configuration.cacheDirectory)
            try? FileManager.default.createDirectory(
                at: configuration.cacheDirectory,
                withIntermediateDirectories: true
            )
            metadata.clear()
        }
    }

    private func filePath(for key: CacheKey) -> URL {
        configuration.cacheDirectory.appendingPathComponent(key.fileName)
    }

    private func evictIfNeeded() {
        while metadata.totalSize > configuration.maxDiskSizeBytes {
            guard let oldest = metadata.evictOldest() else { break }
            let path = filePath(for: oldest)
            try? FileManager.default.removeItem(at: path)
        }
    }
}
