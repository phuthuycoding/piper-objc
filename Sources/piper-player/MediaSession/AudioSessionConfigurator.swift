#if canImport(AVFAudio) && os(iOS)
import AVFAudio

public final class AudioSessionConfigurator {
    public enum Mode {
        case playback
        case playbackMixing
    }

    public static func configure(mode: Mode) throws {
        let session = AVAudioSession.sharedInstance()
        switch mode {
        case .playback:
            try session.setCategory(.playback, mode: .spokenAudio)
        case .playbackMixing:
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        try session.setActive(true)
    }

    public static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif
