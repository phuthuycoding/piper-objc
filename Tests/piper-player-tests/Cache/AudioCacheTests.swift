import XCTest
@testable import piper_player

final class AudioCacheTests: XCTestCase {
    var cache: AudioCache!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        cache = AudioCache(configuration: .init(
            maxDiskSizeBytes: 10_000,
            cacheDirectory: tempDir,
            enabled: true
        ))
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        cache = nil
        super.tearDown()
    }

    func testStoreAndRetrieve() throws {
        let key = AudioCache.CacheKey(text: "hello", speakerId: 0, modelPath: "/test/model")
        let sourceFile = tempDir.appendingPathComponent("source.wav")
        let testData = Data(repeating: 0x42, count: 100)
        try testData.write(to: sourceFile)

        cache.store(audioAt: sourceFile, for: key)

        let result = cache.cachedAudio(for: key)
        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result!.path))
    }

    func testCacheMiss() {
        let key = AudioCache.CacheKey(text: "nonexistent", speakerId: 0, modelPath: "/test/model")
        XCTAssertNil(cache.cachedAudio(for: key))
    }

    func testDisabledCache() throws {
        let disabledCache = AudioCache(configuration: .init(
            maxDiskSizeBytes: 10_000,
            cacheDirectory: tempDir,
            enabled: false
        ))
        let key = AudioCache.CacheKey(text: "hello", speakerId: 0, modelPath: "/test/model")
        let sourceFile = tempDir.appendingPathComponent("source.wav")
        try Data(repeating: 0x42, count: 100).write(to: sourceFile)

        disabledCache.store(audioAt: sourceFile, for: key)
        XCTAssertNil(disabledCache.cachedAudio(for: key))
    }

    func testLRUEviction() throws {
        let sourceFile = tempDir.appendingPathComponent("source.wav")
        let bigData = Data(repeating: 0x42, count: 6000)
        try bigData.write(to: sourceFile)

        let key1 = AudioCache.CacheKey(text: "first", speakerId: 0, modelPath: "/test/model")
        cache.store(audioAt: sourceFile, for: key1)

        Thread.sleep(forTimeInterval: 0.1)

        let key2 = AudioCache.CacheKey(text: "second", speakerId: 0, modelPath: "/test/model")
        cache.store(audioAt: sourceFile, for: key2)

        XCTAssertNil(cache.cachedAudio(for: key1))
        XCTAssertNotNil(cache.cachedAudio(for: key2))
    }

    func testClearAll() throws {
        let key = AudioCache.CacheKey(text: "hello", speakerId: 0, modelPath: "/test/model")
        let sourceFile = tempDir.appendingPathComponent("source.wav")
        try Data(repeating: 0x42, count: 100).write(to: sourceFile)

        cache.store(audioAt: sourceFile, for: key)
        XCTAssertNotNil(cache.cachedAudio(for: key))

        cache.clearAll()
        XCTAssertNil(cache.cachedAudio(for: key))
        XCTAssertEqual(cache.currentSizeBytes, 0)
    }

    func testDifferentSpeakerIdsDifferentKeys() {
        let key1 = AudioCache.CacheKey(text: "hello", speakerId: 0, modelPath: "/test/model")
        let key2 = AudioCache.CacheKey(text: "hello", speakerId: 1, modelPath: "/test/model")
        XCTAssertNotEqual(key1, key2)
        XCTAssertNotEqual(key1.fileName, key2.fileName)
    }

    func testSameTextSameKey() {
        let key1 = AudioCache.CacheKey(text: "hello", speakerId: 0, modelPath: "/test/model")
        let key2 = AudioCache.CacheKey(text: "hello", speakerId: 0, modelPath: "/test/model")
        XCTAssertEqual(key1, key2)
        XCTAssertEqual(key1.fileName, key2.fileName)
    }

    func testConfigurationIsReadOnly() {
        XCTAssertTrue(cache.configuration.enabled)
        XCTAssertEqual(cache.configuration.maxDiskSizeBytes, 10_000)
    }
}
