//
//  FirehoseService.swift
//  Skyscraper
//
//  Service for consuming Bluesky's JetStream firehose for real-time post updates
//

import Foundation
import Combine

// MARK: - JetStream Event Models

struct JetStreamEvent: Codable {
    let did: String
    let timeUs: Int64
    let kind: String
    let commit: JetStreamCommit?

    enum CodingKeys: String, CodingKey {
        case did
        case timeUs = "time_us"
        case kind
        case commit
    }
}

struct JetStreamCommit: Codable {
    let rev: String
    let operation: String
    let collection: String
    let rkey: String
    let record: JetStreamRecord?
    let cid: String?
}

struct JetStreamRecord: Codable {
    let type: String
    let text: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case type = "$type"
        case text
        case createdAt
    }
}

// MARK: - Firehose Service

@MainActor
class FirehoseService: NSObject, ObservableObject {
    static let shared = FirehoseService()

    // Published state
    @Published var isConnected = false
    @Published var connectionError: String?
    @Published var eventsReceived: Int = 0

    // WebSocket
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    // Configuration
    private let endpoint = "wss://jetstream2.us-east.bsky.network/subscribe"
    private let wantedCollection = "app.bsky.feed.post"
    private var wantedDids: Set<String> = [] // DIDs to filter (empty = all DIDs)

    // Cursor management for resumption
    private var lastEventTimeUs: Int64?
    private let cursorKey = "FirehoseLastEventTimeUs"

    // Reconnection
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private var reconnectTimer: Timer?

    // Callback for new post URIs
    var onNewPost: ((String) -> Void)?

    // Track if we should auto-reconnect
    private var shouldMaintainConnection = false

    override init() {
        super.init()

        // Load saved cursor
        let savedCursor = UserDefaults.standard.object(forKey: cursorKey) as? Int64
        lastEventTimeUs = savedCursor

        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    // MARK: - DID Filter Management

    /// Update the list of DIDs to filter. Pass empty set to receive all DIDs.
    func updateWantedDids(_ dids: Set<String>) {
        let didArray = Array(dids).prefix(10000) // JetStream max is 10,000 DIDs
        wantedDids = Set(didArray)

        print("🔥 Firehose: Updating DID filter to \(wantedDids.count) DIDs")

        // If connected, send dynamic update
        if isConnected {
            sendDidsUpdate()
        }
    }

    /// Clear DID filter to receive posts from all users
    func clearDidFilter() {
        updateWantedDids([])
    }

    private func sendDidsUpdate() {
        guard let webSocketTask = webSocketTask else { return }

        // Build subscriber-sourced message to update filter
        let updateMessage: [String: Any] = [
            "type": "update",
            "payload": [
                "wantedDids": Array(wantedDids)
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updateMessage)
            let message = URLSessionWebSocketTask.Message.data(jsonData)
            let didCount = wantedDids.count // Capture before closure

            webSocketTask.send(message) { error in
                if let error = error {
                    print("🔥 Firehose: Failed to send DID update: \(error)")
                } else {
                    print("🔥 Firehose: DID filter updated dynamically (\(didCount) DIDs)")
                }
            }
        } catch {
            print("🔥 Firehose: Failed to encode DID update: \(error)")
        }
    }

    // MARK: - Connection Management

    func connect() {
        guard !isConnected else {
            print("🔥 Firehose: Already connected")
            return
        }

        shouldMaintainConnection = true
        reconnectAttempts = 0
        attemptConnection()
    }

    private func attemptConnection() {
        guard shouldMaintainConnection else { return }

        // Build URL with query parameters
        var urlComponents = URLComponents(string: endpoint)
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "wantedCollections", value: wantedCollection)
        ]

        // Add DIDs filter if specified (empty = all DIDs)
        if !wantedDids.isEmpty {
            let didsString = wantedDids.joined(separator: ",")
            queryItems.append(URLQueryItem(name: "wantedDids", value: didsString))
            print("🔥 Firehose: Filtering by \(wantedDids.count) DIDs")
        } else {
            print("🔥 Firehose: No DID filter (receiving all users)")
        }

        // Add cursor if we have one (subtract 5 seconds for safety buffer)
        if let cursor = lastEventTimeUs {
            let bufferUs: Int64 = 5_000_000 // 5 seconds in microseconds
            let resumeCursor = cursor - bufferUs
            queryItems.append(URLQueryItem(name: "cursor", value: String(resumeCursor)))
            print("🔥 Firehose: Resuming from cursor \(resumeCursor)")
        }

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            connectionError = "Invalid WebSocket URL"
            return
        }

        print("🔥 Firehose: Connecting to \(url.absoluteString)")

        // Create WebSocket task
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()

        // Start receiving messages
        receiveMessage()

        isConnected = true
        connectionError = nil
        reconnectAttempts = 0

        print("🔥 Firehose: Connected successfully")
    }

    func disconnect() {
        print("🔥 Firehose: Disconnecting...")
        shouldMaintainConnection = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    /// Clear saved cursor to start fresh (required when changing DID filter)
    func clearCursor() {
        lastEventTimeUs = nil
        UserDefaults.standard.removeObject(forKey: cursorKey)
        print("🔥 Firehose: Cleared saved cursor")
    }

    private func handleDisconnection(error: Error?) {
        isConnected = false

        if let error = error {
            print("🔥 Firehose: Disconnected with error: \(error.localizedDescription)")
            connectionError = error.localizedDescription
        } else {
            print("🔥 Firehose: Disconnected")
        }

        // Attempt reconnection if we should maintain connection
        guard shouldMaintainConnection else { return }

        reconnectAttempts += 1

        if reconnectAttempts <= maxReconnectAttempts {
            // Exponential backoff: 1s, 2s, 4s, 8s, up to 60s
            let delay = min(pow(2.0, Double(reconnectAttempts - 1)), 60.0)
            print("🔥 Firehose: Reconnecting in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")

            reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.attemptConnection()
                }
            }
        } else {
            print("🔥 Firehose: Max reconnection attempts reached")
            connectionError = "Failed to reconnect after \(maxReconnectAttempts) attempts"
        }
    }

    // MARK: - Message Handling

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    switch message {
                    case .data(let data):
                        self.handleData(data)
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            self.handleData(data)
                        }
                    @unknown default:
                        break
                    }

                    // Continue receiving
                    self.receiveMessage()

                case .failure(let error):
                    self.handleDisconnection(error: error)
                }
            }
        }
    }

    private func handleData(_ data: Data) {
        do {
            let event = try JSONDecoder().decode(JetStreamEvent.self, from: data)

            // Update cursor
            lastEventTimeUs = event.timeUs
            UserDefaults.standard.set(event.timeUs, forKey: cursorKey)

            // Increment counter
            eventsReceived += 1

            // Log every 100 events to show activity
            if eventsReceived % 100 == 0 {
                print("🔥 Firehose: Received \(eventsReceived) total events")
            }

            // Process commit events
            if event.kind == "commit",
               let commit = event.commit,
               commit.collection == wantedCollection,
               commit.operation == "create" {

                // Construct post URI from the event
                let postURI = "at://\(event.did)/\(commit.collection)/\(commit.rkey)"

                print("🔥 Firehose: New post detected - \(postURI)")
                print("   DID: \(event.did)")
                print("   Collection: \(commit.collection)")
                print("   Operation: \(commit.operation)")

                // Notify callback
                onNewPost?(postURI)
            }

        } catch {
            print("🔥 Firehose: Failed to decode event: \(error)")
            // Log the raw data for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   Raw JSON: \(jsonString.prefix(200))...")
            }
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension FirehoseService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            print("🔥 Firehose: WebSocket opened")
        }
    }

    nonisolated func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        Task { @MainActor in
            print("🔥 Firehose: WebSocket closed with code: \(closeCode.rawValue)")
            self.handleDisconnection(error: nil)
        }
    }
}
