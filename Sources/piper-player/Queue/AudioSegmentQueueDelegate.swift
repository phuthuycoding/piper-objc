import Foundation

public protocol AudioSegmentQueueDelegate: AnyObject {
    func queue(_ queue: AudioSegmentQueue, didStartSegment index: Int)
    func queue(_ queue: AudioSegmentQueue, didFinishSegment index: Int)
    func queue(_ queue: AudioSegmentQueue, didChangeState state: AudioSegmentQueue.State)
    func queue(_ queue: AudioSegmentQueue, progressUpdate progress: Float, inSegment segment: Int)
    func queueDidFinishAll(_ queue: AudioSegmentQueue)
    func queue(_ queue: AudioSegmentQueue, didStartSpeakingWord word: WordTiming, inSegment segment: Int)
}

public extension AudioSegmentQueueDelegate {
    func queue(_ queue: AudioSegmentQueue, didStartSegment index: Int) {}
    func queue(_ queue: AudioSegmentQueue, didFinishSegment index: Int) {}
    func queue(_ queue: AudioSegmentQueue, didChangeState state: AudioSegmentQueue.State) {}
    func queue(_ queue: AudioSegmentQueue, progressUpdate progress: Float, inSegment segment: Int) {}
    func queueDidFinishAll(_ queue: AudioSegmentQueue) {}
    func queue(_ queue: AudioSegmentQueue, didStartSpeakingWord word: WordTiming, inSegment segment: Int) {}
}
