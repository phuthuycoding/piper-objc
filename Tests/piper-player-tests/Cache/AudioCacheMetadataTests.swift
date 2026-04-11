import XCTest
@testable import piper_player

final class AudioCacheMetadataTests: XCTestCase {
    var metadata: AudioCacheMetadata!
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        metadata = AudioCacheMetadata(directory: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        metadata = nil
        super.tearDown()
    }

    func testAddAndTotalSize() {
        let key = AudioCache.CacheKey(text: "test", speakerId: 0, modelPath: "/model")
        metadata.add(key: key, size: 1000)
        XCTAssertEqual(metadata.totalSize, 1000)
    }

    func testMultipleEntries() {
        let key1 = AudioCache.CacheKey(text: "test1", speakerId: 0, modelPath: "/model")
        let key2 = AudioCache.CacheKey(text: "test2", speakerId: 0, modelPath: "/model")
        metadata.add(key: key1, size: 500)
        metadata.add(key: key2, size: 300)
        XCTAssertEqual(metadata.totalSize, 800)
    }

    func testEvictOldest() {
        let key1 = AudioCache.CacheKey(text: "old", speakerId: 0, modelPath: "/model")
        metadata.add(key: key1, size: 500)

        Thread.sleep(forTimeInterval: 0.05)

        let key2 = AudioCache.CacheKey(text: "new", speakerId: 0, modelPath: "/model")
        metadata.add(key: key2, size: 300)

        let evicted = metadata.evictOldest()
        XCTAssertEqual(evicted, key1)
        XCTAssertEqual(metadata.totalSize, 300)
    }

    func testEvictOldestReturnsNilWhenEmpty() {
        XCTAssertNil(metadata.evictOldest())
    }

    func testClear() {
        let key = AudioCache.CacheKey(text: "test", speakerId: 0, modelPath: "/model")
        metadata.add(key: key, size: 1000)
        metadata.clear()
        XCTAssertEqual(metadata.totalSize, 0)
    }

    func testTouchUpdatesAccessTime() {
        let key1 = AudioCache.CacheKey(text: "first", speakerId: 0, modelPath: "/model")
        metadata.add(key: key1, size: 500)

        Thread.sleep(forTimeInterval: 0.05)

        let key2 = AudioCache.CacheKey(text: "second", speakerId: 0, modelPath: "/model")
        metadata.add(key: key2, size: 300)

        // Touch key1 to make it newer
        metadata.touch(key: key1)

        let evicted = metadata.evictOldest()
        XCTAssertEqual(evicted, key2)
    }

    func testPersistence() {
        let key = AudioCache.CacheKey(text: "persist", speakerId: 0, modelPath: "/model")
        metadata.add(key: key, size: 1234)

        // Wait for debounced save to complete
        let expectation = expectation(description: "debounce save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // Create new instance from same directory
        let metadata2 = AudioCacheMetadata(directory: tempDir)
        XCTAssertEqual(metadata2.totalSize, 1234)
    }
}
