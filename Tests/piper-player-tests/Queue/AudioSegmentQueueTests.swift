#if canImport(AVFoundation)
import XCTest
@testable import piper_player

final class AudioSegmentQueueTests: XCTestCase {
    func testSegmentInit() {
        let segment = AudioSegmentQueue.Segment(text: "Hello")
        XCTAssertEqual(segment.text, "Hello")
        XCTAssertEqual(segment.speakerId, 0)
        XCTAssertNil(segment.metadata)
    }

    func testSegmentWithMetadata() {
        let segment = AudioSegmentQueue.Segment(
            text: "Hello",
            speakerId: 1,
            metadata: ["chapter": "1"]
        )
        XCTAssertEqual(segment.text, "Hello")
        XCTAssertEqual(segment.speakerId, 1)
        XCTAssertEqual(segment.metadata?["chapter"], "1")
    }

    func testStateEquatable() {
        XCTAssertEqual(AudioSegmentQueue.State.idle, AudioSegmentQueue.State.idle)
        XCTAssertEqual(
            AudioSegmentQueue.State.playing(segmentIndex: 0),
            AudioSegmentQueue.State.playing(segmentIndex: 0)
        )
        XCTAssertNotEqual(
            AudioSegmentQueue.State.playing(segmentIndex: 0),
            AudioSegmentQueue.State.playing(segmentIndex: 1)
        )
        XCTAssertNotEqual(
            AudioSegmentQueue.State.idle,
            AudioSegmentQueue.State.paused(segmentIndex: 0)
        )
    }
}
#endif
