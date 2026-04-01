# Piper‑ObjC [![Build](https://github.com/IhorShevchuk/piper-objc/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/IhorShevchuk/piper-objc/actions/workflows/build.yml)

Objective‑C bindings for the [Piper](https://github.com/rhasspy/piper) speech synthesis engine, with a ready‑to‑use Swift player.

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
- **piper-player** — High‑level Swift player built on AVFoundation.

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

### Synthesize to file

Returns the path to the generated `.wav` file, useful when you need custom playback (e.g. pitch shifting, speed control via `AVAudioEngine`).

```swift
// From plain text
if let path = await player.synthesizeToFile(text: "Hello, world!") {
    // use the .wav file at `path`
}

// From SSML
if let path = await player.synthesizeSSMLToFile(ssml: "<speak>Hello</speak>", speakerId: 0) {
    // use the .wav file at `path`
}
```

### Stop playback

```swift
await player.stopAndCancel()
```

### Low‑level Objective‑C API

```objc
#import <piper_objc/piper_objc.h>

Piper *piper = [[Piper alloc] initWithModelPath:@"model.onnx"
                                      configPath:@"model.onnx.json"
                                    espeakNGData:@""];

// Synthesize text to file
[piper synthesize:@"Hello" toFileAtPath:@"/tmp/out.wav" completion:^{
    // playback or processing
}];

// Synthesize SSML to file
[piper synthesizeSSML:@"<speak>Hello</speak>"
            speakerId:0
         toFileAtPath:@"/tmp/out.wav"
           completion:^{
    // playback or processing
}];
```

## License

GPL-2.0
