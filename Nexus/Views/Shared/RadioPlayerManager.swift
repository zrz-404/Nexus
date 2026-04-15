import Foundation
import AVFoundation
import Combine

// MARK: - Playback state
enum RadioPlaybackState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case error(String)

    var isActive: Bool {
        switch self { case .playing, .loading: return true; default: return false }
    }
}

// MARK: - Radio player manager
final class RadioPlayerManager: NSObject, ObservableObject {
    static let shared = RadioPlayerManager()

    @Published var currentStation: RadioStation? = nil
    @Published var state: RadioPlaybackState = .idle
    @Published var volume: Float = 0.7

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObserver: AnyCancellable?
    private var timeObserver: Any?
    private var retryCount = 0
    private let maxRetries = 2

    // Convenience shims used by existing UI
    var isPlaying: Bool { state == .playing }

    private override init() {
        super.init()
        // Configure audio session for macOS background playback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Public API
    func play(_ station: RadioStation) {
        guard !station.streamURL.isEmpty else {
            state = .error("No stream available for \(station.name) yet.")
            return
        }
        stop()
        currentStation = station
        retryCount = 0
        startPlayback(urlString: station.streamURL)
    }

    func stop() {
        tearDown()
        state = .idle
        currentStation = nil
    }

    func togglePlayPause() {
        switch state {
        case .playing:
            player?.pause()
            state = .paused
        case .paused:
            player?.play()
            state = .playing
        case .error:
            // Retry the current station
            if let station = currentStation { play(station) }
        default:
            break
        }
    }

    func setVolume(_ v: Float) {
        volume = v
        player?.volume = v
    }

    // MARK: - Internal
    private func startPlayback(urlString: String) {
        state = .loading

        // Handle .pls playlists
        if urlString.hasSuffix(".pls") {
            resolvePLS(urlString: urlString)
            return
        }

        guard let url = URL(string: urlString) else {
            state = .error("Invalid stream URL")
            return
        }
        setupPlayer(url: url)
    }

    private func setupPlayer(url: URL) {
        tearDown()

        let item = AVPlayerItem(url: url)
        playerItem = item
        player = AVPlayer(playerItem: item)
        player?.volume = volume

        // Observe item status via Combine
        statusObserver = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.player?.play()
                    self.state = .playing
                case .failed:
                    let msg = item.error?.localizedDescription ?? "Playback failed"
                    self.handleError(msg)
                default:
                    break
                }
            }

        // Observe stall / playback ended
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailed),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemStalled),
            name: AVPlayerItem.playbackStalledNotification,
            object: item
        )
    }

    @objc private func playerItemFailed(_ n: Notification) {
        let err = (n.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
        DispatchQueue.main.async { self.handleError(err ?? "Playback ended unexpectedly") }
    }

    @objc private func playerItemStalled(_ n: Notification) {
        // Auto-rebuffer — AVPlayer usually recovers, but give it a nudge
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, case .playing = self.state else { return }
            self.player?.play()
        }
    }

    private func handleError(_ message: String) {
        if retryCount < maxRetries, let station = currentStation {
            retryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.startPlayback(urlString: station.streamURL)
            }
        } else {
            state = .error(message)
        }
    }

    /// Parse a SHOUTcast/Icecast .pls playlist and play the first valid URL
    private func resolvePLS(urlString: String) {
        guard let url = URL(string: urlString) else { state = .error("Invalid PLS URL"); return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            guard let data, error == nil,
                  let text = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async { self.state = .error("Could not fetch playlist") }
                return
            }
            // Parse File1=... lines
            let lines = text.components(separatedBy: "\n")
            let streamURL = lines
                .first(where: { $0.lowercased().hasPrefix("file") && $0.contains("=") })
                .flatMap { $0.components(separatedBy: "=").dropFirst().first }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            DispatchQueue.main.async {
                if let resolved = streamURL, !resolved.isEmpty {
                    self.setupPlayer(url: URL(string: resolved)!)
                } else {
                    self.state = .error("No stream found in playlist")
                }
            }
        }.resume()
    }

    private func tearDown() {
        statusObserver?.cancel()
        statusObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.playbackStalledNotification, object: playerItem)
        player?.pause()
        player = nil
        playerItem = nil
    }
}
