//
//  RadioPlayerManager.swift
//  Nexus - Phase 5
//
//  Enhanced radio with error handling, playlist fallback, and loading states
//

import Foundation
import AVFoundation
import Combine

class RadioPlayerManager: ObservableObject {
    static let shared = RadioPlayerManager()
    
    @Published var currentStation: RadioStation? = nil
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 0.7
    @Published var playerState: RadioPlayerState = .idle
    @Published var errorMessage: String? = nil
    @Published var isBuffering: Bool = false
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // Track retry attempts
    private var retryCount = 0
    private let maxRetries = 2
    
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
    
    // Fallback URLs for each station
    private let fallbackURLs: [String: String] = [
        "Lofi Study":    "https://streams.fluxfm.de/live/mp3-320/streams.fluxfm.de/",
        "Deep Space":    "https://ice4.somafm.com/deepspaceone-128-mp3",
    ]
    
    init() {
        setupAudioSession()
        loadSavedVolume()
    }
    
    deinit {
        removeTimeObserver()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func loadSavedVolume() {
        if let savedVolume = UserDefaults.standard.object(forKey: "nexus_radio_volume") as? Float {
            volume = savedVolume
        }
    }
    
    // MARK: - Playback Control
    
    func play(_ station: RadioStation) {
        // If already playing this station, just ensure it's playing
        if currentStation?.id == station.id && isPlaying {
            return
        }
        
        // Reset state
        stop()
        retryCount = 0
        errorMessage = nil
        
        currentStation = station
        playerState = .loading
        
        // Check if station has a stream URL
        guard let urlString = station.streamURL ?? streamURLs[station.name],
              !urlString.isEmpty else {
            handleError("No stream available for \(station.name). This station requires local files or Spotify integration.")
            return
        }
        
        // Handle playlist files (PLS, M3U)
        if station.isPlaylist || urlString.hasSuffix(".pls") || urlString.hasSuffix(".m3u") {
            loadPlaylistAndPlay(urlString: urlString, station: station)
        } else {
            loadAndPlay(urlString: urlString, station: station, isFallback: false)
        }
    }
    
    private func loadAndPlay(urlString: String, station: RadioStation, isFallback: Bool) {
        guard let url = URL(string: urlString) else {
            if !isFallback {
                tryFallback(for: station)
            } else {
                handleError("Invalid stream URL")
            }
            return
        }
        
        let item = AVPlayerItem(url: url)
        playerItem = item
        
        // Observe player item status
        item.publisher(for: \.status)
            .sink { [weak self] status in
                self?.handlePlayerItemStatus(status, station: station, isFallback: isFallback)
            }
            .store(in: &cancellables)
        
        // Observe playback buffer
        item.publisher(for: \.isPlaybackBufferEmpty)
            .sink { [weak self] isEmpty in
                self?.isBuffering = isEmpty
            }
            .store(in: &cancellables)
        
        // Observe errors
        item.publisher(for: \.error)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handlePlaybackError(error, station: station, isFallback: isFallback)
            }
            .store(in: &cancellables)
        
        player = AVPlayer(playerItem: item)
        player?.volume = volume
        
        // Add periodic time observer for playback monitoring
        addTimeObserver()
        
        player?.play()
        
        // Update state after a short delay to allow buffer to fill
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            if self.player?.rate ?? 0 > 0 {
                self.isPlaying = true
                self.playerState = .playing(station: station)
            }
        }
    }
    
    private func loadPlaylistAndPlay(urlString: String, station: RadioStation) {
        guard let url = URL(string: urlString) else {
            tryFallback(for: station)
            return
        }
        
        // Download and parse playlist
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("Playlist download error: \(error)")
                    self.tryFallback(for: station)
                    return
                }
                
                guard let data = data,
                      let content = String(data: data, encoding: .utf8) else {
                    self.tryFallback(for: station)
                    return
                }
                
                // Parse playlist to extract stream URL
                if let streamURL = self.parsePlaylist(content) {
                    self.loadAndPlay(urlString: streamURL, station: station, isFallback: false)
                } else {
                    self.tryFallback(for: station)
                }
            }
        }.resume()
    }
    
    private func parsePlaylist(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        
        // Try PLS format first
        for line in lines {
            if line.lowercased().hasPrefix("file1=") {
                return String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Try M3U format
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                return trimmed
            }
        }
        
        return nil
    }
    
    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status, station: RadioStation, isFallback: Bool) {
        switch status {
        case .readyToPlay:
            isPlaying = true
            playerState = .playing(station: station)
            errorMessage = nil
            retryCount = 0
            
        case .failed:
            if !isFallback {
                tryFallback(for: station)
            } else {
                handleError("Failed to load stream. The station may be offline.")
            }
            
        case .unknown:
            break
            
        @unknown default:
            break
        }
    }
    
    private func handlePlaybackError(_ error: Error, station: RadioStation, isFallback: Bool) {
        print("Playback error: \(error.localizedDescription)")
        
        if !isFallback {
            tryFallback(for: station)
        } else if retryCount < maxRetries {
            retryCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.play(station)
            }
        } else {
            handleError("Stream error: \(error.localizedDescription)")
        }
    }
    
    private func tryFallback(for station: RadioStation) {
        if let fallback = station.fallbackURL ?? fallbackURLs[station.name],
           !fallback.isEmpty {
            print("Trying fallback URL for \(station.name)")
            loadAndPlay(urlString: fallback, station: station, isFallback: true)
        } else {
            handleError("Unable to connect to \(station.name). No fallback available.")
        }
    }
    
    private func handleError(_ message: String) {
        errorMessage = message
        playerState = .error(message: message)
        isPlaying = false
        print("Radio error: \(message)")
    }
    
    func stop() {
        player?.pause()
        player = nil
        playerItem = nil
        removeTimeObserver()
        cancellables.removeAll()
        isPlaying = false
        isBuffering = false
        playerState = .idle
        errorMessage = nil
        currentStation = nil
    }
    
    func togglePlayPause() {
        guard currentStation != nil else { return }
        
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }
    
    func setVolume(_ v: Float) {
        volume = max(0, min(1, v))
        player?.volume = volume
        UserDefaults.standard.set(volume, forKey: "nexus_radio_volume")
    }
    
    // MARK: - Time Observer
    
    private func addTimeObserver() {
        removeTimeObserver()
        
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            // Monitor playback - could be used for UI updates
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    // MARK: - Station Info
    
    func canPlayStation(_ station: RadioStation) -> Bool {
        return (station.streamURL ?? streamURLs[station.name]) != nil
    }
}

// MARK: - Radio Station View Model
extension RadioStation {
    var displayStatus: String {
        if streamURL == nil {
            return "Coming Soon"
        }
        return "Live"
    }
    
    var isPlayable: Bool {
        return streamURL != nil
    }
}
