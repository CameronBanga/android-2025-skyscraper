//
//  VideoPlayerView.swift
//  Skyscraper
//
//  Video player component for HLS video playback
//

import SwiftUI
import AVKit
import AVFoundation
import Combine

struct VideoPlayerView: View {
    let video: VideoView
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = true
    @State private var muteObserver: AnyCancellable?
    @Environment(\.scenePhase) private var scenePhase

    // Unique ID for this player instance to coordinate playback
    private let playerID = UUID()

    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(
                        video.aspectRatio.map { CGFloat($0.width) / CGFloat($0.height) } ?? 16/9,
                        contentMode: .fit
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        togglePlayback()
                    }
            } else {
                // Show thumbnail while loading
                RetryableAsyncImage(
                    url: video.thumbnail.flatMap { URL(string: $0) },
                    maxRetries: 3,
                    retryDelay: 1.0,
                    content: { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    },
                    placeholder: {
                        ZStack {
                            Color.gray.opacity(0.3)
                            ProgressView()
                        }
                    }
                )
                .aspectRatio(video.aspectRatio.map { CGFloat($0.width) / CGFloat($0.height) } ?? 16/9, contentMode: .fit)
                .overlay {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .shadow(radius: 10)
                }
            }
        }
        .onAppear {
            setupPlayer()
            // Auto-play when view appears (if enabled in settings)
            let shouldAutoPlay = UserDefaults.standard.object(forKey: "autoPlayVideos") as? Bool ?? true
            if shouldAutoPlay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    player?.play()
                    isPlaying = true
                }
            }
        }
        .onDisappear {
            pauseAndReset()
            VideoPlaybackCoordinator.shared.stopPlayback(id: playerID)
            cleanupPlayer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                // Pause and cleanup when app goes to background
                pauseAndReset()
                VideoPlaybackCoordinator.shared.stopPlayback(id: playerID)
                deactivateAudioSession()
            case .active:
                // Don't auto-resume, let user decide
                break
            @unknown default:
                break
            }
        }
    }

    private func setupPlayer() {
        guard let url = URL(string: video.playlist) else {
            return
        }

        let playerItem = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: playerItem)

        // Configure audio session to NOT take over system media controls
        // Using .ambient means it mixes with other audio and doesn't show in Control Center
        // This respects the device silent switch for autoplay
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        #endif

        // Configure player for inline playback
        avPlayer.allowsExternalPlayback = true
        avPlayer.isMuted = true  // Mute by default for autoplay

        // Observe mute state changes - switch audio session when user unmutes
        muteObserver = avPlayer.publisher(for: \.isMuted)
            .removeDuplicates()
            .sink { muted in
                if muted {
                    deactivatePlaybackAudioSession()
                } else {
                    activatePlaybackAudioSession()
                }
            }

        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            if isPlaying {
                avPlayer.play()
            }
        }

        self.player = avPlayer
    }

    private func activatePlaybackAudioSession() {
        // Switch to .playback category to play audio even when device is silenced
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [.notifyOthersOnDeactivation])
            AppLogger.debug("Switched to .playback audio session for unmuted video", subsystem: "Video")
        } catch {
            print("Failed to activate playback audio session: \(error)")
        }
        #endif
    }

    private func deactivatePlaybackAudioSession() {
        // Switch back to .ambient category when pausing
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: [.notifyOthersOnDeactivation])
            AppLogger.debug("Switched back to .ambient audio session", subsystem: "Video")
        } catch {
            print("Failed to switch back to ambient audio session: \(error)")
        }
        #endif
    }

    private func togglePlayback() {
        guard let player = player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            VideoPlaybackCoordinator.shared.stopPlayback(id: playerID)
        } else {
            // Request playback - this pauses any other active players
            VideoPlaybackCoordinator.shared.requestPlayback(id: playerID, player: player)
            player.isMuted = false  // Unmute when user explicitly interacts to play
            player.play()
            isPlaying = true
            // Note: The muteObserver will automatically switch to .playback audio session
        }
    }

    private func pauseAndReset() {
        guard let player = player else { return }
        player.pause()
        player.isMuted = true  // Re-mute so observer switches back to .ambient
        isPlaying = false
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        #endif
    }

    private func cleanupPlayer() {
        // Cancel the mute observer to prevent leaks
        muteObserver?.cancel()
        muteObserver = nil

        player?.pause()
        isPlaying = false
        player = nil

        // Switch back to ambient and deactivate audio session
        deactivatePlaybackAudioSession()
        deactivateAudioSession()
    }
}
