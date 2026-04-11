import Foundation

final class AudioCacheMetadata {
    struct Entry: Codable {
        let key: AudioCache.CacheKey
        var size: UInt64
        var lastAccess: Date
    }

    private var entries: [AudioCache.CacheKey: Entry] = [:]
    private let metadataURL: URL
    private var isDirty = false
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "com.piper.cache.metadata")

    var totalSize: UInt64 {
        entries.values.reduce(0) { $0 + $1.size }
    }

    init(directory: URL) {
        self.metadataURL = directory.appendingPathComponent(".cache_metadata.json")
        load()
    }

    func add(key: AudioCache.CacheKey, size: UInt64) {
        entries[key] = Entry(key: key, size: size, lastAccess: Date())
        scheduleSave()
    }

    func touch(key: AudioCache.CacheKey) {
        entries[key]?.lastAccess = Date()
        isDirty = true
    }

    func evictOldest() -> AudioCache.CacheKey? {
        guard let oldest = entries.values.min(by: { $0.lastAccess < $1.lastAccess }) else {
            return nil
        }
        entries.removeValue(forKey: oldest.key)
        scheduleSave()
        return oldest.key
    }

    func clear() {
        entries.removeAll()
        saveNow()
    }

    func flushIfNeeded() {
        guard isDirty else { return }
        saveNow()
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([AudioCache.CacheKey: Entry].self, from: data) else {
            return
        }
        entries = decoded
    }

    private func scheduleSave() {
        isDirty = true
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func saveNow() {
        isDirty = false
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    deinit {
        if isDirty {
            saveNow()
        }
    }
}
