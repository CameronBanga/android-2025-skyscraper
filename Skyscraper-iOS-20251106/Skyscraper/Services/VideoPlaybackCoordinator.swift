//
//  VideoPlaybackCoordinator.swift
//  Skyscraper
//
//  Coordinates video playback to ensure only one video plays audio at a time
//

import Foundation
import AVFoundation

@MainActor
final class VideoPlaybackCoordinator {
    static let shared = VideoPlaybackCoordinator()

    private weak var currentPlayer: AVPlayer?
    private var currentID: UUID?

    private init() {}

    func requestPlayback(id: UUID, player: AVPlayer) {
        if currentID != id {
            // Pause whatever was playing before
            currentPlayer?.pause()
            currentPlayer = player
            currentID = id
            AppLogger.debug("VideoPlaybackCoordinator: Started playback for \(id)", subsystem: "Video")
        }
    }

    func stopPlayback(id: UUID) {
        guard currentID == id else { return }
        currentPlayer?.pause()
        currentPlayer = nil
        currentID = nil
        AppLogger.debug("VideoPlaybackCoordinator: Stopped playback for \(id)", subsystem: "Video")
    }
}
