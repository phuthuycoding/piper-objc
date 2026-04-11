#if canImport(AVFoundation)
import XCTest
@testable import piper_player

final class PiperStreamingDelegateTests: XCTestCase {
    var engine: PiperAudioEngine!
    var delegate: PiperStreamingDelegate!

    override func setUp() {
        super.setUp()
        engine = PiperAudioEngine()
        delegate = PiperStreamingDelegate(audioEngine: engine)
    }

    override func tearDown() {
        engine.stop()
        delegate = nil
        engine = nil
        super.tearDown()
    }

    func testAccumulatesSamples() {
        var samples = [Float](repeating: 0.5, count: 100)
        samples.withUnsafeMutableBufferPointer { ptr in
            delegate.piperDidReceiveSamples(ptr.baseAddress!, withSize: 100)
        }
        // Should not crash; samples are accumulated internally
    }

    func testFlushDoesNotCrashWhenEmpty() {
        delegate.flush()
    }

    func testResetClearsState() {
        var samples = [Float](repeating: 0.5, count: 100)
        samples.withUnsafeMutableBufferPointer { ptr in
            delegate.piperDidReceiveSamples(ptr.baseAddress!, withSize: 100)
        }
        delegate.reset()
        delegate.flush()
    }

    func testAutoFlushAtMinBufferSize() {
        var samples = [Float](repeating: 0.1, count: 5000)
        samples.withUnsafeMutableBufferPointer { ptr in
            delegate.piperDidReceiveSamples(ptr.baseAddress!, withSize: 5000)
        }
        // Buffer >= 4096, should auto-flush without crash
    }
}
#endif
