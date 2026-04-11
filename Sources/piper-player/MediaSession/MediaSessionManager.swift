#if canImport(MediaPlayer)
import MediaPlayer
import Foundation

public final class MediaSessionManager {
    public struct NowPlayingInfo {
        public var title: String?
        public var artist: String?
        public var albumTitle: String?
        public var artwork: MPMediaItemArtwork?
        public var totalSegments: Int
        public var currentSegment: Int

        public init(
            title: String? = nil,
            artist: String? = nil,
            albumTitle: String? = nil,
            artwork: MPMediaItemArtwork? = nil,
            totalSegments: Int = 0,
            currentSegment: Int = 0
        ) {
            self.title = title
            self.artist = artist
            self.albumTitle = albumTitle
            self.artwork = artwork
            self.totalSegments = totalSegments
            self.currentSegment = currentSegment
        }
    }

    private weak var queue: AudioSegmentQueue?
    private var registeredCommands: [(command: MPRemoteCommand, target: Any)] = []

    public init(queue: AudioSegmentQueue) {
        self.queue = queue
    }

    public func activate() {
        #if os(iOS)
        try? AudioSessionConfigurator.configure(mode: .playback)
        #endif
        registerRemoteCommands()
    }

    public func deactivate() {
        unregisterRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #if os(iOS)
        AudioSessionConfigurator.deactivate()
        #endif
    }

    public func updateNowPlaying(_ info: NowPlayingInfo) {
        var nowPlaying: [String: Any] = [:]

        if let title = info.title {
            nowPlaying[MPMediaItemPropertyTitle] = title
        }
        if let artist = info.artist {
            nowPlaying[MPMediaItemPropertyArtist] = artist
        }
        if let albumTitle = info.albumTitle {
            nowPlaying[MPMediaItemPropertyAlbumTitle] = albumTitle
        }
        if let artwork = info.artwork {
            nowPlaying[MPMediaItemPropertyArtwork] = artwork
        }

        nowPlaying[MPNowPlayingInfoPropertyPlaybackRate] = queue?.playbackRate ?? 1.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
    }

    public func updateProgress(elapsed: TimeInterval, total: TimeInterval) {
        var nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlaying[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        nowPlaying[MPMediaItemPropertyPlaybackDuration] = total
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        let playTarget = center.playCommand.addTarget { [weak self] _ in
            self?.queue?.resume()
            return .success
        }
        registeredCommands.append((center.playCommand, playTarget))

        let pauseTarget = center.pauseCommand.addTarget { [weak self] _ in
            self?.queue?.pause()
            return .success
        }
        registeredCommands.append((center.pauseCommand, pauseTarget))

        let toggleTarget = center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let queue = self?.queue else { return .commandFailed }
            switch queue.state {
            case .playing:
                queue.pause()
            case .paused:
                queue.resume()
            case .idle:
                queue.play()
            }
            return .success
        }
        registeredCommands.append((center.togglePlayPauseCommand, toggleTarget))

        let nextTarget = center.nextTrackCommand.addTarget { [weak self] _ in
            self?.queue?.skipForward()
            return .success
        }
        registeredCommands.append((center.nextTrackCommand, nextTarget))

        let prevTarget = center.previousTrackCommand.addTarget { [weak self] _ in
            self?.queue?.skipBackward()
            return .success
        }
        registeredCommands.append((center.previousTrackCommand, prevTarget))
    }

    private func unregisterRemoteCommands() {
        for (command, target) in registeredCommands {
            command.removeTarget(target)
        }
        registeredCommands.removeAll()
    }

    deinit {
        unregisterRemoteCommands()
    }
}
#endif
