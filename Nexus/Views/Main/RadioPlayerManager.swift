import Foundation
import AVFoundation
import Combine

class RadioPlayerManager: ObservableObject {
    static let shared = RadioPlayerManager()

    @Published var currentStation: RadioStation? = nil
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 0.7

    private var player: AVPlayer?

    // Stable, publicly accessible direct-file or HLS streams
    private let streamURLs: [String: String] = [
        "Fireplace":     "https://assets.mixkit.co/sfx/preview/mixkit-fireplace-crackling-1330.mp3",
        "Rain":          "https://assets.mixkit.co/sfx/preview/mixkit-rain-and-thunder-ambiance-1291.mp3",
        "Lofi Study":    "https://stream.laut.fm/lofi",
        "Deep Space":    "https://somafm.com/deepspaceone130.pls",
        "Café":          "https://stream.laut.fm/cafe-del-mar-chillout-mix",
        // Orchestral / themed — no free public stream; placeholder for Spotify or local file
        "Skyrim":        "",
        "Lord of Rings": "",
        "Harry Potter":  "",
    ]

    func play(_ station: RadioStation) {
        stop()
        currentStation = station
        guard let urlString = streamURLs[station.name],
              !urlString.isEmpty,
              let url = URL(string: urlString) else {
            isPlaying = false
            return
        }
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentStation = nil
    }

    func togglePlayPause() {
        guard currentStation != nil else { return }
        if isPlaying { player?.pause(); isPlaying = false }
        else         { player?.play();  isPlaying = true  }
    }

    func setVolume(_ v: Float) {
        volume = v
        player?.volume = v
    }
}
