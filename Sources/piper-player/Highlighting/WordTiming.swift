import Foundation

public struct WordTiming: Sendable {
    public let word: String
    public let range: Range<String.Index>
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public var duration: TimeInterval {
        endTime - startTime
    }
}

public struct SentenceTiming: Sendable {
    public let sentence: String
    public let range: Range<String.Index>
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let words: [WordTiming]

    public var duration: TimeInterval {
        endTime - startTime
    }
}

public protocol PiperHighlightDelegate: AnyObject {
    func piperPlayer(didStartSpeakingWord word: WordTiming, inSegment segment: Int)
    func piperPlayer(didStartSpeakingSentence sentence: SentenceTiming, inSegment segment: Int)
}
