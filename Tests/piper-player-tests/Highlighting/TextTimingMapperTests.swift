import XCTest
@testable import piper_player

final class TextTimingMapperTests: XCTestCase {
    func testBuildWordTimingsBasic() {
        let text = "Hello world"
        let alignments: [(phoneme: UInt32, sampleCount: Int)] = [
            (104, 1000),  // h
            (101, 800),   // e
            (108, 600),   // l
            (108, 600),   // l
            (111, 900),   // o
            (119, 700),   // w
            (111, 800),   // o
            (114, 600),   // r
            (108, 500),   // l
            (100, 700),   // d
        ]

        let timings = TextTimingMapper.buildWordTimings(
            for: text,
            phonemeAlignments: alignments,
            sampleRate: 22050
        )

        XCTAssertEqual(timings.count, 2)
        XCTAssertEqual(timings[0].word, "Hello")
        XCTAssertEqual(timings[1].word, "world")
        XCTAssertEqual(timings[0].startTime, 0)
        XCTAssertGreaterThan(timings[0].endTime, 0)
        XCTAssertGreaterThan(timings[1].endTime, timings[1].startTime)
    }

    func testEmptyText() {
        let timings = TextTimingMapper.buildWordTimings(
            for: "",
            phonemeAlignments: [],
            sampleRate: 22050
        )
        XCTAssertTrue(timings.isEmpty)
    }

    func testZeroSampleRate() {
        let timings = TextTimingMapper.buildWordTimings(
            for: "Hello",
            phonemeAlignments: [(104, 1000)],
            sampleRate: 0
        )
        XCTAssertTrue(timings.isEmpty)
    }

    func testSentenceTimings() {
        let text = "Hello world. Goodbye world."
        let wordTimings = [
            WordTiming(word: "Hello", range: text.range(of: "Hello")!, startTime: 0, endTime: 0.5),
            WordTiming(word: "world", range: text.range(of: "world")!, startTime: 0.5, endTime: 1.0),
            WordTiming(word: "Goodbye", range: text.range(of: "Goodbye")!, startTime: 1.0, endTime: 1.5),
            WordTiming(word: "world", range: text.range(of: "world", range: text.index(text.startIndex, offsetBy: 13)..<text.endIndex)!, startTime: 1.5, endTime: 2.0),
        ]

        let sentences = TextTimingMapper.buildSentenceTimings(
            for: text,
            wordTimings: wordTimings
        )

        XCTAssertEqual(sentences.count, 2)
        XCTAssertEqual(sentences[0].words.count, 2)
        XCTAssertEqual(sentences[1].words.count, 2)
        XCTAssertEqual(sentences[0].startTime, 0)
        XCTAssertEqual(sentences[0].endTime, 1.0)
    }

    func testWordTimingDuration() {
        let text = "test"
        let timing = WordTiming(
            word: "test",
            range: text.startIndex..<text.endIndex,
            startTime: 1.0,
            endTime: 2.5
        )
        XCTAssertEqual(timing.duration, 1.5)
    }

    func testSentenceTimingDuration() {
        let text = "Hello world."
        let timing = SentenceTiming(
            sentence: text,
            range: text.startIndex..<text.endIndex,
            startTime: 0,
            endTime: 1.0,
            words: []
        )
        XCTAssertEqual(timing.duration, 1.0)
    }

    func testMoreWordsThanPhonemes() {
        let text = "one two three four"
        let alignments: [(phoneme: UInt32, sampleCount: Int)] = [
            (111, 1000),
            (116, 1000),
        ]

        let timings = TextTimingMapper.buildWordTimings(
            for: text,
            phonemeAlignments: alignments,
            sampleRate: 22050
        )

        XCTAssertEqual(timings.count, 4)
        for timing in timings {
            XCTAssertGreaterThan(timing.endTime, timing.startTime)
        }
    }
}
