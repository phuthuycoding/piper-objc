import Foundation

public final class TextTimingMapper {
    public static func buildWordTimings(
        for text: String,
        phonemeAlignments: [(phoneme: UInt32, sampleCount: Int)],
        sampleRate: Int
    ) -> [WordTiming] {
        guard sampleRate > 0 else { return [] }

        let words = splitIntoWords(text)
        guard !words.isEmpty else { return [] }

        let totalPhonemesamples = phonemeAlignments.reduce(0) { $0 + $1.sampleCount }
        guard totalPhonemesamples > 0 else { return [] }

        let totalDuration = Double(totalPhonemesamples) / Double(sampleRate)
        let avgDurationPerWord = totalDuration / Double(words.count)

        var result: [WordTiming] = []
        var currentTime: TimeInterval = 0

        if phonemeAlignments.count >= words.count {
            let phonemesPerWord = phonemeAlignments.count / max(words.count, 1)
            var phonemeIdx = 0

            for (word, range) in words {
                let endIdx = min(phonemeIdx + phonemesPerWord, phonemeAlignments.count)
                var wordSamples = 0
                for i in phonemeIdx..<endIdx {
                    wordSamples += phonemeAlignments[i].sampleCount
                }
                let duration = Double(wordSamples) / Double(sampleRate)
                result.append(WordTiming(
                    word: word,
                    range: range,
                    startTime: currentTime,
                    endTime: currentTime + duration
                ))
                currentTime += duration
                phonemeIdx = endIdx
            }

            if phonemeIdx < phonemeAlignments.count, let last = result.last {
                var remaining = 0
                for i in phonemeIdx..<phonemeAlignments.count {
                    remaining += phonemeAlignments[i].sampleCount
                }
                let extra = Double(remaining) / Double(sampleRate)
                result[result.count - 1] = WordTiming(
                    word: last.word,
                    range: last.range,
                    startTime: last.startTime,
                    endTime: last.endTime + extra
                )
            }
        } else {
            for (word, range) in words {
                result.append(WordTiming(
                    word: word,
                    range: range,
                    startTime: currentTime,
                    endTime: currentTime + avgDurationPerWord
                ))
                currentTime += avgDurationPerWord
            }
        }

        return result
    }

    public static func buildSentenceTimings(
        for text: String,
        wordTimings: [WordTiming]
    ) -> [SentenceTiming] {
        guard !wordTimings.isEmpty else { return [] }

        let sentences = splitIntoSentences(text)
        var result: [SentenceTiming] = []
        var wordIdx = 0

        for (sentence, range) in sentences {
            var sentenceWords: [WordTiming] = []
            let sentenceEnd = range.upperBound

            while wordIdx < wordTimings.count {
                let word = wordTimings[wordIdx]
                if word.range.lowerBound < sentenceEnd {
                    sentenceWords.append(word)
                    wordIdx += 1
                } else {
                    break
                }
            }

            guard !sentenceWords.isEmpty else { continue }

            result.append(SentenceTiming(
                sentence: sentence,
                range: range,
                startTime: sentenceWords.first!.startTime,
                endTime: sentenceWords.last!.endTime,
                words: sentenceWords
            ))
        }

        return result
    }

    private static func splitIntoWords(_ text: String) -> [(String, Range<String.Index>)] {
        var words: [(String, Range<String.Index>)] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { word, range, _, _ in
            if let word {
                words.append((word, range))
            }
        }
        return words
    }

    private static func splitIntoSentences(_ text: String) -> [(String, Range<String.Index>)] {
        var sentences: [(String, Range<String.Index>)] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { sentence, range, _, _ in
            if let sentence {
                sentences.append((sentence, range))
            }
        }
        if sentences.isEmpty {
            sentences.append((text, text.startIndex..<text.endIndex))
        }
        return sentences
    }
}
