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
    private let lock = NSLock()

    var totalSize: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return entries.values.reduce(0) { $0 + $1.size }
    }

    init(directory: URL) {
        self.metadataURL = directory.appendingPathComponent(".cache_metadata.json")
        load()
    }

    func add(key: AudioCache.CacheKey, size: UInt64) {
        lock.lock()
        entries[key] = Entry(key: key, size: size, lastAccess: Date())
        lock.unlock()
        scheduleSave()
    }

    func touch(key: AudioCache.CacheKey) {
        lock.lock()
        entries[key]?.lastAccess = Date()
        isDirty = true
        lock.unlock()
    }

    func evictOldest() -> AudioCache.CacheKey? {
        lock.lock()
        guard let oldest = entries.values.min(by: { $0.lastAccess < $1.lastAccess }) else {
            lock.unlock()
            return nil
        }
        entries.removeValue(forKey: oldest.key)
        lock.unlock()
        scheduleSave()
        return oldest.key
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        isDirty = false
        lock.unlock()
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
        lock.lock()
        isDirty = true
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveNow()
        }
        saveWorkItem = workItem
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func saveNow() {
        lock.lock()
        isDirty = false
        let snapshot = entries
        lock.unlock()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    deinit {
        lock.lock()
        let dirty = isDirty
        let snapshot = entries
        lock.unlock()
        if dirty {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: metadataURL, options: .atomic)
        }
    }
}
