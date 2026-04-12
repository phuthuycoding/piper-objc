# Piper‑ObjC [![Build](https://github.com/phuthuycoding/piper-objc/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/phuthuycoding/piper-objc/actions/workflows/build.yml)

Objective‑C bindings for the [Piper](https://github.com/rhasspy/piper) speech synthesis engine, with a full-featured Swift audiobook engine.

## Requirements

| Platform | Minimum |
|----------|---------|
| iOS      | 13.0    |
| macOS    | 10.15   |

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/phuthuycoding/piper-objc.git", from: "0.1.0")
]
```

Two library products are available:

- **piper-objc** — Low‑level Objective‑C bindings.
- **piper-player** — High‑level Swift audiobook engine built on AVAudioEngine.

## Usage

### Setup

```swift
import piper_player

let params = PiperPlayer.Params(
    modelPath: "/path/to/model.onnx",
    configPath: "/path/to/model.onnx.json",
    espeakNGData: "/path/to/espeak-ng-data"  // optional
)

let player = try PiperPlayer(params: params)
```

### Play text

```swift
try await player.play(text: "Hello, world!")
```

### Play SSML

```swift
try await player.play(ssml: "<speak>Hello</speak>")

// With a specific speaker (for multi-speaker models)
try await player.play(ssml: "<speak>Hello</speak>", speakerId: 1)
```

### Speed and pitch control

```swift
player.playbackRate = 1.5  // 0.25x to 4.0x
player.pitch = 200         // -2400 to 2400 cents
player.volume = 0.8        // 0.0 to 1.0
```

### Pause and resume

```swift
player.pause()
player.resume()
player.stopAndCancel()
```

### Synthesize to file

Returns the path to the generated `.wav` file for custom processing.

```swift
if let path = await player.synthesizeToFile(text: "Hello, world!") {
    // use the .wav file at `path`
}

if let path = await player.synthesizeSSMLToFile(ssml: "<speak>Hello</speak>", speakerId: 0) {
    // use the .wav file at `path`
}
```

### Audiobook queue

Play a sequence of text segments with automatic prefetching.

```swift
let segments = paragraphs.map {
    AudioSegmentQueue.Segment(text: $0)
}
player.queue.replaceAll(segments)
player.queue.delegate = self
player.queue.prefetchCount = 2
player.queue.play()

// Controls
player.queue.skipForward()
player.queue.skipBackward()
player.queue.seek(to: 5)
player.queue.pause()
player.queue.resume()
```

### Queue delegate

```swift
extension MyClass: AudioSegmentQueueDelegate {
    func queue(_ queue: AudioSegmentQueue, didStartSegment index: Int) {
        // update UI
    }

    func queue(_ queue: AudioSegmentQueue, didFinishSegment index: Int) {
        // segment completed
    }

    func queue(_ queue: AudioSegmentQueue, didChangeState state: AudioSegmentQueue.State) {
        // .idle, .playing(segmentIndex:), .paused(segmentIndex:)
    }

    func queue(_ queue: AudioSegmentQueue, didProduceWordTimings timings: [WordTiming], forSegment segment: Int) {
        // word-level timing data for text highlighting
        for word in timings {
            print("\(word.word): \(word.startTime)s - \(word.endTime)s")
        }
    }

    func queueDidFinishAll(_ queue: AudioSegmentQueue) {
        // all segments completed
    }
}
```

### Background audio and lock screen controls (iOS)

```swift
player.mediaSession.activate()
player.mediaSession.updateNowPlaying(.init(
    title: "Chapter 1",
    artist: "Author Name",
    albumTitle: "Book Title"
))

// Lock screen controls automatically map to queue:
// Play/Pause → queue.pause() / queue.resume()
// Next/Previous → queue.skipForward() / queue.skipBackward()
```

### Audio caching

Synthesized audio is cached to avoid repeated synthesis of the same text.

```swift
// Cache is enabled by default (500MB limit)
// Access via player.cache
player.cache.clearAll()
```

### Low‑level Objective‑C API

```objc
#import <piper_objc/piper_objc.h>

Piper *piper = [[Piper alloc] initWithModelPath:@"model.onnx"
                                      configPath:@"model.onnx.json"
                                    espeakNGData:@""];

[piper synthesize:@"Hello" toFileAtPath:@"/tmp/out.wav" completion:^{
    // playback or processing
}];

[piper synthesizeSSML:@"<speak>Hello</speak>"
            speakerId:0
         toFileAtPath:@"/tmp/out.wav"
           completion:^{
    // playback or processing
}];
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  PiperPlayer                     │
│  playbackRate / pitch / volume / pause / resume  │
├──────────┬──────────┬───────────┬───────────────┤
│ AudioSeg │  Audio   │  Media    │    Audio      │
│ mentQueue│  Cache   │  Session  │    Engine     │
│ + Prefet │  (LRU)   │  (Lock    │  (AVAudio     │
│   ch     │          │   Screen) │   Engine)     │
├──────────┴──────────┴───────────┴───────────────┤
│              piper-objc (C++ bridge)             │
├─────────────────────────────────────────────────┤
│           Piper TTS Engine (ONNX)                │
└─────────────────────────────────────────────────┘
```

## License

GPL-2.0
