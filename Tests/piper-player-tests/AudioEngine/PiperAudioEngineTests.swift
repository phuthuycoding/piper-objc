#if canImport(AVFoundation)
import XCTest
@testable import piper_player

final class PiperAudioEngineTests: XCTestCase {
    var engine: PiperAudioEngine!

    override func setUp() {
        super.setUp()
        engine = PiperAudioEngine()
    }

    override func tearDown() {
        engine.stop()
        engine = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(engine.state, .idle)
        XCTAssertFalse(engine.isPlaying)
    }

    func testDefaultRateAndPitch() {
        XCTAssertEqual(engine.rate, 1.0)
        XCTAssertEqual(engine.pitch, 0.0)
        XCTAssertEqual(engine.volume, 1.0)
    }

    func testRateClamping() {
        engine.rate = 10.0
        XCTAssertEqual(engine.rate, 4.0)

        engine.rate = 0.1
        XCTAssertEqual(engine.rate, 0.25)

        engine.rate = 2.0
        XCTAssertEqual(engine.rate, 2.0)
    }

    func testPitchClamping() {
        engine.pitch = 5000
        XCTAssertEqual(engine.pitch, 2400)

        engine.pitch = -5000
        XCTAssertEqual(engine.pitch, -2400)

        engine.pitch = 100
        XCTAssertEqual(engine.pitch, 100)
    }

    func testVolumeClamping() {
        engine.volume = 2.0
        XCTAssertEqual(engine.volume, 1.0)

        engine.volume = -1.0
        XCTAssertEqual(engine.volume, 0.0)

        engine.volume = 0.5
        XCTAssertEqual(engine.volume, 0.5)
    }

    func testPrepareAndState() throws {
        try engine.prepare(sampleRate: 22050)
        XCTAssertEqual(engine.state, .playing)
    }

    func testPauseAndResume() throws {
        try engine.prepare(sampleRate: 22050)

        engine.pause()
        XCTAssertEqual(engine.state, .paused)

        engine.resume()
        XCTAssertEqual(engine.state, .playing)
    }

    func testStop() throws {
        try engine.prepare(sampleRate: 22050)
        engine.stop()
        XCTAssertEqual(engine.state, .idle)
    }

    func testPauseOnlyWhenPlaying() {
        engine.pause()
        XCTAssertEqual(engine.state, .idle)
    }

    func testResumeOnlyWhenPaused() throws {
        try engine.prepare(sampleRate: 22050)
        engine.resume()
        XCTAssertEqual(engine.state, .playing)
    }

    func testScheduleBuffer() throws {
        try engine.prepare(sampleRate: 22050)

        var samples = [Float](repeating: 0.0, count: 1024)
        samples.withUnsafeMutableBufferPointer { ptr in
            engine.scheduleBuffer(samples: ptr.baseAddress!, count: 1024)
        }
        XCTAssertEqual(engine.state, .playing)
    }
}
#endif
