//
//  ATProtoClient.swift
//  Skyscraper
//
//  ATProtocol API client for BlueSky
//

import Foundation
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum ATProtoError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case networkError(Error, url: String? = nil, statusCode: Int? = nil)
    case decodingError(Error)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required"
        case .networkError(let error, let url, let statusCode):
            let nsError = error as NSError
            var message = "Network error: \(error.localizedDescription)"

            // Add error code and domain for debugging
            message += "\n\nDebug info:"
            message += "\nError: \(nsError.domain) (\(nsError.code))"

            if let url = url {
                message += "\nEndpoint: \(url)"
            }

            if let statusCode = statusCode {
                message += "\nStatus: \(statusCode)"
            }

            // Add specific guidance based on error code
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorTimedOut:
                    message += "\n\nThe server took too long to respond. The PDS server may be slow or unreachable."
                case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                    message += "\n\nCouldn't find the server. Check that the PDS URL is correct."
                case NSURLErrorNetworkConnectionLost:
                    message += "\n\nConnection was interrupted. Check your internet connection and PDS server status."
                case NSURLErrorNotConnectedToInternet:
                    message += "\n\nNo internet connection available."
                case NSURLErrorSecureConnectionFailed:
                    message += "\n\nSecure connection failed. The PDS server may have certificate issues."
                case NSURLErrorServerCertificateUntrusted:
                    message += "\n\nServer certificate is not trusted."
                case NSURLErrorCannotConnectToHost:
                    message += "\n\nCouldn't connect to the server. The PDS server may be down or unreachable."
                default:
                    break
                }
            }

            return message
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return message
        }
    }
}

@MainActor
class ATProtoClient: ObservableObject {
    static let shared = ATProtoClient()

    @Published var session: ATProtoSession?
    @Published var isAuthenticated = false
    @Published var isChatAvailable = false

    private var baseURL = "https://bsky.social"  // Default, can be changed per session

    /// Update chat availability based on current session
    private func updateChatAvailability() {
        guard let session = session else {
            isChatAvailable = false
            return
        }

        if let pdsURL = session.pdsURL {
            isChatAvailable = pdsURL.contains("bsky.social")
        } else {
            isChatAvailable = baseURL == "https://bsky.social"
        }
    }
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    init() {
        loadSession()
    }

    // MARK: - Session Management

    private func loadSession() {
        // Load session synchronously on init
        // Note: KeychainService accesses AccountManager which is @MainActor
        // We need to ensure this runs on MainActor
        Task { @MainActor in
            if let session = KeychainService.shared.retrieveSession() {
                self.session = session
                self.isAuthenticated = true
                // Restore the PDS URL from the session
                if let pdsURL = session.pdsURL {
                    self.baseURL = pdsURL
                    print("✅ Loaded session from keychain: \(session.handle) (PDS: \(pdsURL))")
                } else {
                    print("✅ Loaded session from keychain: \(session.handle) (using default PDS)")
                }
                self.updateChatAvailability()
            } else {
                print("ℹ️ No session found in keychain")
                self.updateChatAvailability()
            }
        }
    }

    private func saveSession(_ session: ATProtoSession) {
        // Update session immediately (synchronously)
        self.session = session
        self.isAuthenticated = true

        // Update baseURL from session
        if let pdsURL = session.pdsURL {
            self.baseURL = pdsURL
        }

        // Update chat availability
        updateChatAvailability()

        // Save to keychain asynchronously
        Task { @MainActor in
            try? KeychainService.shared.saveSession(session)
            print("💾 Session saved to keychain for DID: \(session.did)")
        }
    }

    func logout() {
        Task { @MainActor in
            KeychainService.shared.clearSession()
            session = nil
            isAuthenticated = false
            baseURL = "https://bsky.social"  // Reset to default
            updateChatAvailability()
        }
    }

    func switchToAccount(accountId: String) {
        // Load the session for this account
        // This is already on @MainActor, so we can do this synchronously
        if let session = KeychainManager.shared.retrieveSession(for: accountId) {
            self.session = session
            self.isAuthenticated = true
            // Update baseURL from the session
            if let pdsURL = session.pdsURL {
                self.baseURL = pdsURL
            } else {
                self.baseURL = "https://bsky.social"  // Default if no PDS URL stored
            }
            updateChatAvailability()
            print("✅ Switched to account: \(session.handle)")
        } else {
            print("❌ No session found for account: \(accountId)")
            self.session = nil
            self.isAuthenticated = false
            self.baseURL = "https://bsky.social"  // Reset to default
            updateChatAvailability()
        }
    }

    private func refreshSession() async throws {
        print("🔄 refreshSession() called")
        guard let currentSession = session else {
            print("❌ No current session to refresh")
            throw ATProtoError.unauthorized
        }

        print("🔑 Using refresh token to get new access token")
        let url = URL(string: "\(baseURL)/xrpc/com.atproto.server.refreshSession")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(currentSession.refreshJwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response from refresh endpoint")
            throw ATProtoError.invalidResponse
        }

        print("📡 Refresh response status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorBody = try? decoder.decode([String: String].self, from: data),
               let message = errorBody["message"] {
                print("❌ Failed to refresh session: \(message)")
                throw ATProtoError.apiError(message)
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Refresh response body: \(responseString)")
            }
            throw ATProtoError.unauthorized
        }

        let sessionResponse = try decoder.decode(CreateSessionResponse.self, from: data)
        let newSession = ATProtoSession(
            did: sessionResponse.did,
            handle: sessionResponse.handle,
            email: sessionResponse.email,
            accessJwt: sessionResponse.accessJwt,
            refreshJwt: sessionResponse.refreshJwt,
            pdsURL: currentSession.pdsURL  // Preserve the PDS URL from the current session
        )
        saveSession(newSession)
        print("✅ Session refreshed successfully, new tokens saved")
    }

    private func performAuthenticatedRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        print("🔐 Making authenticated request to: \(request.url?.path ?? "unknown")")
        var (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw ATProtoError.invalidResponse
        }

        print("📡 Response status code: \(httpResponse.statusCode), Data length: \(data.count) bytes")

        // Check if this is a token expiration error
        var shouldRefreshToken = false

        // Check for 401 (unauthorized)
        if httpResponse.statusCode == 401 {
            shouldRefreshToken = true
            print("⚠️ Received 401 Unauthorized")
        }

        // Check for 400 with "token" or "expired" in error message (BlueSky sometimes returns 400 for expired tokens)
        if httpResponse.statusCode == 400 {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                print("📋 Error message: \(message)")

                // Don't trigger refresh for app password permission issues
                // "Token could not be verified" for DMs means the app password doesn't have DM permissions
                if message.lowercased().contains("token could not be verified") {
                    print("⚠️ App password permission issue (not a token expiration)")
                    shouldRefreshToken = false
                } else if message.lowercased().contains("token") || message.lowercased().contains("expired") {
                    shouldRefreshToken = true
                    print("⚠️ Token expired based on error message")
                }
            }
        }

        // If we need to refresh the token, try refreshing and retry once
        if shouldRefreshToken {
            print("🔄 Token expired, attempting to refresh...")
            do {
                try await refreshSession()
                print("✅ Session refreshed successfully, retrying original request")
            } catch {
                print("❌ Failed to refresh session: \(error.localizedDescription)")
                throw error
            }

            // Retry the request with the new token
            var retryRequest = request
            if let session = session {
                retryRequest.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
                print("🔑 Retrying with new access token")
            }

            (data, response) = try await URLSession.shared.data(for: retryRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type on retry")
                throw ATProtoError.invalidResponse
            }

            print("📡 Retry response status code: \(httpResponse.statusCode), Data length: \(data.count) bytes")

            // Log if retry also returned empty data
            if data.isEmpty {
                print("⚠️ Retry returned empty data!")
                if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                    print("📋 Response headers: \(allHeaders)")
                }
            }

            return (data, httpResponse)
        }

        // Log if initial request returned empty data
        if data.isEmpty {
            print("⚠️ Initial request returned empty data!")
            if let allHeaders = httpResponse.allHeaderFields as? [String: String] {
                print("📋 Response headers: \(allHeaders)")
            }
        }

        return (data, httpResponse)
    }

    // MARK: - Authentication

    func login(identifier: String, password: String, customPDSURL: String? = nil) async throws {
        // Use custom PDS URL if provided, otherwise use default
        let pdsURL = customPDSURL ?? baseURL

        // Ensure the URL doesn't have a trailing slash
        let cleanPDSURL = pdsURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Add https:// if not present
        let fullPDSURL: String
        if cleanPDSURL.lowercased().hasPrefix("http://") || cleanPDSURL.lowercased().hasPrefix("https://") {
            fullPDSURL = cleanPDSURL
        } else {
            fullPDSURL = "https://\(cleanPDSURL)"
        }

        print("🌐 Creating session URL: \(fullPDSURL)/xrpc/com.atproto.server.createSession")

        guard let url = URL(string: "\(fullPDSURL)/xrpc/com.atproto.server.createSession") else {
            print("❌ Failed to create URL from: \(fullPDSURL)")
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateSessionRequest(identifier: identifier, password: password)
        request.httpBody = try encoder.encode(body)

        print("🔗 Sending login request to: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            print("📡 Login response received - Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw ATProtoError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                print("❌ Login failed with status code: \(httpResponse.statusCode)")
                if let errorBody = try? decoder.decode([String: String].self, from: data),
                   let message = errorBody["message"] {
                    print("❌ API error message: \(message)")
                    throw ATProtoError.apiError(message)
                }
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Response body: \(responseString)")
                }
                throw ATProtoError.unauthorized
            }

            let sessionResponse = try decoder.decode(CreateSessionResponse.self, from: data)
            print("📥 Received session from BlueSky API:")
            print("   DID: \(sessionResponse.did)")
            print("   Handle: \(sessionResponse.handle)")
            print("   Email: \(sessionResponse.email ?? "nil")")
            print("   PDS URL: \(fullPDSURL)")

            let session = ATProtoSession(
                did: sessionResponse.did,
                handle: sessionResponse.handle,
                email: sessionResponse.email,
                accessJwt: sessionResponse.accessJwt,
                refreshJwt: sessionResponse.refreshJwt,
                pdsURL: fullPDSURL  // Store the PDS URL with the session
            )
            saveSession(session)
        } catch let error as ATProtoError {
            print("❌ ATProtoError during login: \(error)")
            throw error
        } catch {
            print("❌ Network error during login: \(error)")
            throw ATProtoError.networkError(error, url: url.absoluteString, statusCode: nil)
        }
    }

    // MARK: - Feed Operations

    func getTimeline(limit: Int = 50, cursor: String? = nil) async throws -> FeedResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        // Validate and clamp limit to API maximum
        let clampedLimit = ATProtoLimits.clampFeedLimit(limit, max: ATProtoLimits.Feed.maxTimelinePosts)

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getTimeline")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(clampedLimit)")
        ]
        if let cursor = cursor {
            components.queryItems?.append(URLQueryItem(name: "cursor", value: cursor))
        }

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        print("📊 getTimeline response - Status: \(httpResponse.statusCode), Data length: \(data.count) bytes")

        guard httpResponse.statusCode == 200 else {
            // Log response for non-200 status codes
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Non-200 response (\(httpResponse.statusCode)): \(responseString)")
            }

            // Try to decode error message
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                throw ATProtoError.apiError(message)
            }
            throw ATProtoError.invalidResponse
        }

        // Check if data is empty
        if data.isEmpty {
            print("❌ Response data is empty despite 200 status code")
            throw ATProtoError.apiError("Empty response from server")
        }

        do {
            return try decoder.decode(FeedResponse.self, from: data)
        } catch {
            // Log the actual JSON for debugging
            print("❌ Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Response JSON: \(jsonString.prefix(500))...") // First 500 chars
            }
            throw ATProtoError.decodingError(error)
        }
    }

    // MARK: - Post Operations

    /// Process image for upload: strip metadata and compress to <925KB
    private func processImageForUpload(_ image: PlatformImage) -> Data? {
        let maxSize = 925 * 1024 // 925 KB in bytes

        #if os(iOS)
        // iOS: Strip metadata by re-rendering the image with proper orientation
        let strippedImage: UIImage

        // Use UIGraphicsImageRenderer for better orientation handling
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        strippedImage = renderer.image { context in
            // This properly handles image orientation
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        #elseif os(macOS)
        // macOS: Strip metadata by re-rendering the image
        let strippedImage: NSImage

        let newImage = NSImage(size: image.size)
        newImage.lockFocus()
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        strippedImage = newImage
        #endif

        // Try compression with decreasing quality
        var quality: CGFloat = 0.9
        var imageData = strippedImage.jpegData(compressionQuality: quality)

        while let data = imageData, data.count > maxSize && quality > 0.1 {
            quality -= 0.1
            imageData = strippedImage.jpegData(compressionQuality: quality)
            print("🔄 Compressing image with quality \(String(format: "%.1f", quality)): \(data.count) bytes")
        }

        // If still too large, resize the image
        if let data = imageData, data.count > maxSize {
            print("⚠️ Image still too large after compression, resizing...")

            var scaleFactor: CGFloat = 0.9
            var resizedImage = strippedImage

            while let data = resizedImage.jpegData(compressionQuality: 0.8), data.count > maxSize && scaleFactor > 0.3 {
                let newSize = CGSize(
                    width: strippedImage.size.width * scaleFactor,
                    height: strippedImage.size.height * scaleFactor
                )

                #if os(iOS)
                let resizeFormat = UIGraphicsImageRendererFormat()
                resizeFormat.scale = 1.0
                resizeFormat.opaque = false

                let resizeRenderer = UIGraphicsImageRenderer(size: newSize, format: resizeFormat)
                resizedImage = resizeRenderer.image { context in
                    strippedImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
                #elseif os(macOS)
                let newImage = NSImage(size: newSize)
                newImage.lockFocus()
                strippedImage.draw(in: NSRect(origin: .zero, size: newSize))
                newImage.unlockFocus()
                resizedImage = newImage
                #endif

                imageData = resizedImage.jpegData(compressionQuality: 0.8)
                scaleFactor -= 0.1

                if let finalData = imageData {
                    print("🔄 Resized image to \(newSize.width)x\(newSize.height): \(finalData.count) bytes")
                }
            }
        }

        if let finalData = imageData {
            print("✅ Image processed: \(finalData.count) bytes (quality: \(String(format: "%.1f", quality)))")
            return finalData
        }

        return nil
    }

    /// Upload an image blob to the server
    func uploadImage(_ image: PlatformImage, altText: String? = nil) async throws -> UploadedImage? {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        // Process and compress image (strip metadata, compress to <925KB)
        guard let imageData = processImageForUpload(image) else {
            print("Failed to process image for upload")
            return nil
        }

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.uploadBlob")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData

        print("📤 Uploading image (\(imageData.count) bytes)...")

        let (data, httpResponse): (Data, HTTPURLResponse)
        do {
            (data, httpResponse) = try await performAuthenticatedRequest(request)
        } catch {
            // Add context to network errors
            print("❌ Network error during image upload: \(error)")
            throw ATProtoError.networkError(error, url: url.absoluteString, statusCode: nil)
        }

        guard httpResponse.statusCode == 200 else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                print("Failed to upload blob: \(message)")
                throw ATProtoError.apiError("Failed to upload image: \(message)\n\nPDS: \(baseURL)")
            }
            print("Failed to upload blob with status code: \(httpResponse.statusCode)")
            throw ATProtoError.apiError("Failed to upload image (HTTP \(httpResponse.statusCode))\n\nPDS: \(baseURL)")
        }

        // Parse the response to get the blob reference
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let blobData = json["blob"] as? [String: Any],
           let type = blobData["$type"] as? String,
           let refData = blobData["ref"] as? [String: Any],
           let link = refData["$link"] as? String,
           let mimeType = blobData["mimeType"] as? String,
           let size = blobData["size"] as? Int {

            let blobRef = BlobRef(
                type: type,
                ref: BlobLink(link: link),
                mimeType: mimeType,
                size: size
            )

            // Calculate aspect ratio
            let aspectRatio = UploadedImage.AspectRatio(
                width: Int(image.size.width),
                height: Int(image.size.height)
            )

            print("✅ Image uploaded successfully: \(link)")

            return UploadedImage(blob: blobRef, aspectRatio: aspectRatio, alt: altText)
        }

        print("Failed to parse blob upload response")
        return nil
    }

    func createPost(text: String, reply: ReplyRef? = nil, images: [UploadedImage]? = nil, langs: [String]? = nil, moderationSettings: PostModerationSettings? = nil) async throws -> Post {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.createRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let createdAt = ISO8601DateFormatter().string(from: Date())

        // Detect facets in the text
        let facets = await detectFacets(in: text)

        var recordDict: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "createdAt": createdAt
        ]

        // Add language if provided
        if let langs = langs, !langs.isEmpty {
            recordDict["langs"] = langs
        }

        // Add facets if any were detected
        if !facets.isEmpty {
            recordDict["facets"] = facets.map { facet in
                let facetDict: [String: Any] = [
                    "index": [
                        "byteStart": facet.index.byteStart,
                        "byteEnd": facet.index.byteEnd
                    ],
                    "features": facet.features.map { feature -> [String: Any] in
                        switch feature {
                        case .link(let uri):
                            return [
                                "$type": "app.bsky.richtext.facet#link",
                                "uri": uri
                            ]
                        case .mention(let did):
                            return [
                                "$type": "app.bsky.richtext.facet#mention",
                                "did": did
                            ]
                        case .tag(let tag):
                            return [
                                "$type": "app.bsky.richtext.facet#tag",
                                "tag": tag
                            ]
                        }
                    }
                ]
                return facetDict
            }
            print("📝 Including \(facets.count) facets in post")
        }

        // Add image embed if images are provided
        if let images = images, !images.isEmpty {
            recordDict["embed"] = [
                "$type": "app.bsky.embed.images",
                "images": images.map { uploadedImage in
                    var imageDict: [String: Any] = [
                        "alt": uploadedImage.alt ?? "",
                        "image": [
                            "$type": uploadedImage.blob.type,
                            "ref": ["$link": uploadedImage.blob.ref.link],
                            "mimeType": uploadedImage.blob.mimeType,
                            "size": uploadedImage.blob.size
                        ]
                    ]

                    if let aspectRatio = uploadedImage.aspectRatio {
                        imageDict["aspectRatio"] = [
                            "width": aspectRatio.width,
                            "height": aspectRatio.height
                        ]
                    }

                    return imageDict
                }
            ]
            print("📝 Including \(images.count) images in post")
        }

        if let reply = reply {
            recordDict["reply"] = [
                "root": ["uri": reply.root.uri, "cid": reply.root.cid],
                "parent": ["uri": reply.parent.uri, "cid": reply.parent.cid]
            ]
        }

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.post",
            "record": recordDict
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse): (Data, HTTPURLResponse)
        do {
            (data, httpResponse) = try await performAuthenticatedRequest(request)
        } catch {
            // Add context to network errors
            print("❌ Network error during post creation: \(error)")
            throw ATProtoError.networkError(error, url: url.absoluteString, statusCode: nil)
        }

        guard httpResponse.statusCode == 200 else {
            // Try to decode error message
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                print("Failed to create post: \(message)")
                throw ATProtoError.apiError("Failed to create post: \(message)\n\nPDS: \(baseURL)")
            }
            print("Failed to create post with status code: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            throw ATProtoError.apiError("Failed to create post (HTTP \(httpResponse.statusCode))\n\nPDS: \(baseURL)")
        }

        print("Post created successfully!")

        // Parse the response to get the URI and rkey
        guard let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let postUri = responseDict["uri"] as? String else {
            throw ATProtoError.invalidResponse
        }

        // Extract rkey from URI (format: at://did/collection/rkey)
        let rkey = postUri.split(separator: "/").last.map(String.init) ?? ""

        // Create threadgate if needed
        if let moderationSettings = moderationSettings,
           moderationSettings.replyRestriction != .everybody {
            do {
                try await createThreadgate(postUri: postUri, rkey: rkey, replyRestriction: moderationSettings.replyRestriction)
            } catch {
                print("Failed to create threadgate: \(error)")
            }
        }

        // Create postgate if quote posts are disabled
        if let moderationSettings = moderationSettings,
           !moderationSettings.allowQuotePosts {
            do {
                try await createPostgate(postUri: postUri, rkey: rkey)
            } catch {
                print("Failed to create postgate: \(error)")
            }
        }

        // For now, return a mock post - in production, you'd fetch the created post
        let record = PostRecord(text: text, createdAt: createdAt, facets: nil, langs: nil, tags: nil)
        let author = Author(
            did: session.did,
            handle: session.handle,
            displayName: nil,
            description: nil,
            avatar: nil,
            associated: nil,
            viewer: nil,
            labels: nil,
            createdAt: nil
        )

        return Post(
            uri: postUri,
            cid: "temp",
            author: author,
            record: record,
            replyCount: 0,
            repostCount: 0,
            likeCount: 0,
            quoteCount: 0,
            bookmarkCount: 0,
            indexedAt: createdAt,
            viewer: nil,
            embed: nil,
            replyRef: reply,
            labels: nil
        )
    }

    // MARK: - Threadgate (Reply Controls)

    private func createThreadgate(postUri: String, rkey: String, replyRestriction: ReplyRestriction) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.createRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build allow rules based on restriction type
        var allowRules: [[String: Any]] = []

        switch replyRestriction {
        case .everybody:
            // No threadgate needed
            return
        case .nobody:
            // Empty array means nobody can reply
            break
        case .mentioned:
            allowRules.append(["$type": "app.bsky.feed.threadgate#mentionRule"])
        case .following:
            allowRules.append(["$type": "app.bsky.feed.threadgate#followingRule"])
        case .followers:
            allowRules.append(["$type": "app.bsky.feed.threadgate#followerRule"])
        case .combined(let mentioned, let following, let followers):
            if mentioned {
                allowRules.append(["$type": "app.bsky.feed.threadgate#mentionRule"])
            }
            if following {
                allowRules.append(["$type": "app.bsky.feed.threadgate#followingRule"])
            }
            if followers {
                allowRules.append(["$type": "app.bsky.feed.threadgate#followerRule"])
            }
        }

        let record: [String: Any] = [
            "$type": "app.bsky.feed.threadgate",
            "post": postUri,
            "allow": allowRules,
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.threadgate",
            "rkey": rkey,
            "record": record
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        print("Threadgate created successfully!")
    }

    // MARK: - Postgate (Quote Post Controls)

    private func createPostgate(postUri: String, rkey: String) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.createRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let record: [String: Any] = [
            "$type": "app.bsky.feed.postgate",
            "post": postUri,
            "embeddingRules": [
                ["$type": "app.bsky.feed.postgate#disableRule"]
            ],
            "createdAt": ISO8601DateFormatter().string(from: Date())
        ]

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.postgate",
            "rkey": rkey,
            "record": record
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        print("Postgate created successfully!")
    }

    func likePost(uri: String, cid: String) async throws -> String {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.createRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let createdAt = ISO8601DateFormatter().string(from: Date())

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.like",
            "record": [
                "$type": "app.bsky.feed.like",
                "subject": ["uri": uri, "cid": cid],
                "createdAt": createdAt
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        // Parse response to get the URI of the created like record
        guard let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let likeUri = response["uri"] as? String else {
            throw ATProtoError.invalidResponse
        }

        return likeUri
    }

    func unlikePost(likeUri: String) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        // Extract rkey from URI
        let components = likeUri.split(separator: "/")
        guard components.count >= 2 else {
            throw ATProtoError.invalidURL
        }
        let rkey = String(components.last!)

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.deleteRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.like",
            "rkey": rkey
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }

    func repost(uri: String, cid: String) async throws -> String {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.createRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let createdAt = ISO8601DateFormatter().string(from: Date())

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.repost",
            "record": [
                "$type": "app.bsky.feed.repost",
                "subject": ["uri": uri, "cid": cid],
                "createdAt": createdAt
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        // Parse response to get the URI of the created repost record
        guard let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let repostUri = response["uri"] as? String else {
            throw ATProtoError.invalidResponse
        }

        return repostUri
    }

    func unrepost(repostUri: String) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        // Extract rkey from the repost URI (format: at://did:plc:xxx/app.bsky.feed.repost/rkey)
        let components = repostUri.split(separator: "/")
        guard components.count >= 2 else {
            throw ATProtoError.invalidURL
        }
        let rkey = String(components.last!)

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.deleteRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.repost",
            "rkey": rkey
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }

    // MARK: - Starter Packs Operations

    func getStarterPacks(limit: Int = 50, cursor: String? = nil) async throws -> StarterPacksResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.graph.getStarterPacks")!
        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {
                throw ATProtoError.apiError(message)
            }
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(StarterPacksResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode starter packs response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    // MARK: - Search Operations

    func getFollows(actor: String, limit: Int = 50) async throws -> [Profile] {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.graph.getFollows")!
        components.queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        struct FollowsResponse: Codable {
            let follows: [Profile]
        }

        let response = try decoder.decode(FollowsResponse.self, from: data)
        return response.follows
    }

    func getFollowers(actor: String, limit: Int = 50) async throws -> [Profile] {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.graph.getFollowers")!
        components.queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        struct FollowersResponse: Codable {
            let followers: [Profile]
        }

        let response = try decoder.decode(FollowersResponse.self, from: data)
        return response.followers
    }

    func searchUsers(query: String, limit: Int = 25) async throws -> [Profile] {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.actor.searchActors")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        struct SearchResponse: Codable {
            let actors: [Profile]
        }

        let searchResponse = try decoder.decode(SearchResponse.self, from: data)
        return searchResponse.actors
    }

    func searchPosts(query: String, cursor: String? = nil, limit: Int = 50) async throws -> SearchPostsResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.searchPosts")!
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(SearchPostsResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode search posts response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    // MARK: - Profile Operations

    func getProfile(actor: String) async throws -> Profile {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.actor.getProfile")!
        components.queryItems = [URLQueryItem(name: "actor", value: actor)]

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        // Debug: Print raw JSON to check for pinnedPost field
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 Profile JSON for \(actor):")
            print(jsonString)
        }

        return try decoder.decode(Profile.self, from: data)
    }

    func getProfiles(actors: [String]) async throws -> [Profile] {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        guard !actors.isEmpty else { return [] }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.actor.getProfiles")!
        components.queryItems = actors.map { URLQueryItem(name: "actors", value: $0) }

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        struct ProfilesResponse: Codable {
            let profiles: [Profile]
        }

        return try decoder.decode(ProfilesResponse.self, from: data).profiles
    }

    func followUser(did: String) async throws -> String {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.createRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let createdAt = ISO8601DateFormatter().string(from: Date())

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.graph.follow",
            "record": [
                "$type": "app.bsky.graph.follow",
                "subject": did,
                "createdAt": createdAt
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        // Decode the response to get the URI of the follow record
        struct CreateRecordResponse: Codable {
            let uri: String
            let cid: String
        }

        let createResponse = try decoder.decode(CreateRecordResponse.self, from: data)
        return createResponse.uri
    }

    func unfollowUser(followUri: String) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        // Extract rkey from URI
        let components = followUri.split(separator: "/")
        guard components.count >= 2 else {
            throw ATProtoError.invalidURL
        }
        let rkey = String(components.last!)

        let url = URL(string: "\(baseURL)/xrpc/com.atproto.repo.deleteRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.graph.follow",
            "rkey": rkey
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }

    // MARK: - Thread Operations

    func getPostThread(uri: String, depth: Int? = nil, parentHeight: Int? = nil) async throws -> ThreadResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getPostThread")!
        var queryItems = [URLQueryItem(name: "uri", value: uri)]

        if let depth = depth {
            queryItems.append(URLQueryItem(name: "depth", value: "\(depth)"))
        }

        if let parentHeight = parentHeight {
            queryItems.append(URLQueryItem(name: "parentHeight", value: "\(parentHeight)"))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(ThreadResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode thread response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    // Get posts by URIs (batch fetch)
    func getPosts(uris: [String]) async throws -> PostsResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getPosts")!
        components.queryItems = uris.map { URLQueryItem(name: "uris", value: $0) }

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(PostsResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode posts response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    // Response model for getPosts
    struct PostsResponse: Codable {
        let posts: [FeedViewPost]
    }

    // MARK: - Feeds

    func getPreferences() async throws -> PreferencesResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/app.bsky.actor.getPreferences")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        // Log the raw JSON for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📥 Preferences JSON: \(jsonString)")
        }

        do {
            return try decoder.decode(PreferencesResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("❌ Failed to decode preferences response. JSON: \(jsonString)")
            }
            print("❌ Decoding error: \(error)")
            throw ATProtoError.decodingError(error)
        }
    }

    func getFeedGenerators(feeds: [String]) async throws -> FeedGeneratorsResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getFeedGenerators")!
        components.queryItems = feeds.map { URLQueryItem(name: "feeds", value: $0) }

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(FeedGeneratorsResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode feed generators response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    func getFeed(feed: String, limit: Int = 50, cursor: String? = nil) async throws -> FeedResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        // Validate and clamp limit to API maximum
        let clampedLimit = ATProtoLimits.clampFeedLimit(limit, max: ATProtoLimits.Feed.maxFeedPosts)

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getFeed")!
        var queryItems = [
            URLQueryItem(name: "feed", value: feed),
            URLQueryItem(name: "limit", value: "\(clampedLimit)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        print("📊 getFeed response - Status: \(httpResponse.statusCode), Data length: \(data.count) bytes")

        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Non-200 response (\(httpResponse.statusCode)): \(responseString)")
            }
            throw ATProtoError.invalidResponse
        }

        // Check if data is empty
        if data.isEmpty {
            print("❌ Response data is empty despite 200 status code")
            throw ATProtoError.apiError("Empty response from server")
        }

        do {
            return try decoder.decode(FeedResponse.self, from: data)
        } catch {
            print("❌ Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Response JSON: \(jsonString.prefix(500))...")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    func getSuggestedFeeds(limit: Int = 50, cursor: String? = nil) async throws -> FeedGeneratorsResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        // Validate and clamp limit to API maximum
        let clampedLimit = ATProtoLimits.clampFeedLimit(limit, max: ATProtoLimits.Feed.maxSuggestedFeeds)

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getSuggestedFeeds")!
        var queryItems = [URLQueryItem(name: "limit", value: "\(clampedLimit)")]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(FeedGeneratorsResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode suggested feeds response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    func getTrendingTopics(limit: Int = 10) async throws -> TrendingTopicsResponse {
        // Note: This is a public API endpoint that doesn't require authentication
        let publicBaseURL = "https://public.api.bsky.app"
        var components = URLComponents(string: "\(publicBaseURL)/xrpc/app.bsky.unspecced.getTrendingTopics")!
        components.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        let request = URLRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ATProtoError.invalidResponse
        }

        print("📊 getTrendingTopics response - Status: \(httpResponse.statusCode), Data length: \(data.count) bytes")

        guard httpResponse.statusCode == 200 else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Non-200 response (\(httpResponse.statusCode)): \(responseString)")
            }
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(TrendingTopicsResponse.self, from: data)
        } catch {
            print("❌ Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Response JSON: \(jsonString.prefix(500))...")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    func getActorLists(actor: String, limit: Int = 50, cursor: String? = nil) async throws -> ActorListsResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.graph.getLists")!
        var queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(ActorListsResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode actor lists response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    func putPreferences(preferences: [Preference]) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/app.bsky.actor.putPreferences")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "preferences": preferences.map { pref -> [String: Any] in
                switch pref {
                case .savedFeeds(let savedFeeds):
                    return [
                        "$type": "app.bsky.actor.defs#savedFeedsPref",
                        "pinned": savedFeeds.pinned,
                        "saved": savedFeeds.saved
                    ]
                case .adultContent(let adultContentPref):
                    return [
                        "$type": "app.bsky.actor.defs#adultContentPref",
                        "enabled": adultContentPref.enabled
                    ]
                case .contentLabel(let labelPref):
                    return [
                        "$type": "app.bsky.actor.defs#contentLabelPref",
                        "label": labelPref.label,
                        "visibility": labelPref.visibility
                    ]
                case .other(let dict):
                    return dict.mapValues { $0.value }
                }
            }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }

    func getStarterPacks(uris: [String]) async throws -> StarterPacksResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.graph.getStarterPacks")!
        components.queryItems = uris.map { URLQueryItem(name: "uris", value: $0) }

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(StarterPacksResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode starter packs response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    func getList(list: String, limit: Int = 100, cursor: String? = nil) async throws -> ListResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.graph.getList")!
        var queryItems = [
            URLQueryItem(name: "list", value: list),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(ListResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode list response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    // MARK: - Notifications

    func getNotifications(cursor: String? = nil, limit: Int = 50) async throws -> NotificationsResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.notification.listNotifications")!
        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(NotificationsResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode notifications response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    func updateSeenNotifications(seenAt: Date = Date()) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        let url = URL(string: "\(baseURL)/xrpc/app.bsky.notification.updateSeen")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Format seenAt as ISO 8601 timestamp
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let seenAtString = formatter.string(from: seenAt)

        let body: [String: Any] = [
            "seenAt": seenAtString
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }

    // MARK: - Rich Text Facet Detection

    /// Detects and creates facets for mentions, links, and hashtags in text
    func detectFacets(in text: String) async -> [Facet] {
        var facets: [Facet] = []

        // Detect mentions (@handle)
        let mentionPattern = #"(?:^|\s)@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"#
        if let mentionRegex = try? NSRegularExpression(pattern: mentionPattern, options: []) {
            let matches = mentionRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let matchText = String(text[range])
                    let handle = matchText.trimmingCharacters(in: .whitespaces).dropFirst() // Remove @

                    // Calculate UTF-8 byte positions
                    let byteStart = text.utf8.distance(from: text.startIndex, to: range.lowerBound)
                    let byteEnd = text.utf8.distance(from: text.startIndex, to: range.upperBound)

                    // Try to resolve handle to DID
                    do {
                        let profile = try await getProfile(actor: String(handle))
                        let facet = Facet(
                            index: ByteSlice(byteStart: byteStart, byteEnd: byteEnd),
                            features: [.mention(profile.did)]
                        )
                        facets.append(facet)
                        print("✅ Detected mention: @\(handle) -> \(profile.did)")
                    } catch {
                        print("⚠️ Failed to resolve handle @\(handle): \(error)")
                    }
                }
            }
        }

        // Detect URLs
        let urlPattern = #"https?://[^\s<>"\{\}\|\\^`\[\]]+"#
        if let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: []) {
            let matches = urlRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let url = String(text[range])

                    // Calculate UTF-8 byte positions
                    let byteStart = text.utf8.distance(from: text.startIndex, to: range.lowerBound)
                    let byteEnd = text.utf8.distance(from: text.startIndex, to: range.upperBound)

                    let facet = Facet(
                        index: ByteSlice(byteStart: byteStart, byteEnd: byteEnd),
                        features: [.link(url)]
                    )
                    facets.append(facet)
                    print("✅ Detected link: \(url)")
                }
            }
        }

        // Detect hashtags (#tag)
        let hashtagPattern = #"(?:^|\s)#([a-zA-Z0-9_]+)"#
        if let hashtagRegex = try? NSRegularExpression(pattern: hashtagPattern, options: []) {
            let matches = hashtagRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let matchText = String(text[range])
                    let tag = matchText.trimmingCharacters(in: .whitespaces).dropFirst() // Remove #

                    // Calculate UTF-8 byte positions
                    let byteStart = text.utf8.distance(from: text.startIndex, to: range.lowerBound)
                    let byteEnd = text.utf8.distance(from: text.startIndex, to: range.upperBound)

                    let facet = Facet(
                        index: ByteSlice(byteStart: byteStart, byteEnd: byteEnd),
                        features: [.tag(String(tag))]
                    )
                    facets.append(facet)
                    print("✅ Detected hashtag: #\(tag)")
                }
            }
        }

        // Sort facets by byte position
        facets.sort { $0.index.byteStart < $1.index.byteStart }

        return facets
    }

    // MARK: - Profile Content Methods

    /// Gets an author's feed (posts and optionally replies)
    func getAuthorFeed(actor: String, filter: String = "posts_with_replies", limit: Int = 50, cursor: String? = nil) async throws -> FeedResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getAuthorFeed")!
        var queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "filter", value: filter),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(FeedResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode author feed response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    /// Gets an actor's liked posts
    func getActorLikes(actor: String, limit: Int = 50, cursor: String? = nil) async throws -> FeedResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getActorLikes")!
        var queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(FeedResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode actor likes response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    /// Gets feeds created by an actor
    func getActorFeeds(actor: String, limit: Int = 50, cursor: String? = nil) async throws -> FeedGeneratorsResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.feed.getActorFeeds")!
        var queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(FeedGeneratorsResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                AppLogger.error("Failed to decode actor feeds response. JSON: \(jsonString)", subsystem: "Network")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    /// Gets starter packs created by an actor
    func getActorStarterPacks(actor: String, limit: Int = 50, cursor: String? = nil) async throws -> StarterPacksResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        var components = URLComponents(string: "\(baseURL)/xrpc/app.bsky.graph.getActorStarterPacks")!
        var queryItems = [
            URLQueryItem(name: "actor", value: actor),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        do {
            return try decoder.decode(StarterPacksResponse.self, from: data)
        } catch {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to decode actor starter packs response. JSON: \(jsonString)")
            }
            throw ATProtoError.decodingError(error)
        }
    }

    // MARK: - Chat (Direct Messages) API

    private let chatBaseURL = "https://api.bsky.chat"

    /// Check if the current PDS supports chat/DMs (only bsky.social currently)
    private func checkChatSupport() throws {
        guard session != nil else {
            throw ATProtoError.unauthorized
        }

        // Chat is only supported on bsky.social PDS
        // See: https://docs.bsky.app/blog/2025-protocol-roadmap-spring
        if !isChatAvailable {
            let pdsURL = session?.pdsURL ?? baseURL
            throw ATProtoError.apiError("Direct Messages are not yet supported with alternate PDS servers.\n\nDMs currently only work with bsky.social accounts. The AT Protocol team plans to add federated, end-to-end encrypted DMs in the future.\n\nYour PDS: \(pdsURL)")
        }
    }

    func listConvos(limit: Int = 50, cursor: String? = nil) async throws -> ListConvosResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        // Check if chat is supported with this PDS
        try checkChatSupport()

        var urlComponents = URLComponents(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.listConvos")!
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        urlComponents.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = urlComponents.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            // Parse error response to provide better error messages
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorBody["message"] as? String {

                // Check if this is an app password permission issue
                if message.lowercased().contains("token could not be verified") ||
                   message.lowercased().contains("invalid token") ||
                   message.lowercased().contains("unauthorized") {
                    throw ATProtoError.apiError("Direct Messages Not Enabled\n\nYour app password doesn't have permission to access Direct Messages.\n\nTo fix this:\n1. Go to Settings > App Passwords on bsky.app\n2. Delete your current app password\n3. Create a new app password\n4. Check \"Allow access to direct messages\"\n5. Sign in to Skyscraper with the new password")
                }

                throw ATProtoError.apiError(message)
            }

            throw ATProtoError.invalidResponse
        }

        return try decoder.decode(ListConvosResponse.self, from: data)
    }

    func getConvo(convoId: String) async throws -> GetConvoResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        try checkChatSupport()

        var urlComponents = URLComponents(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.getConvo")!
        urlComponents.queryItems = [URLQueryItem(name: "convoId", value: convoId)]

        guard let url = urlComponents.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        return try decoder.decode(GetConvoResponse.self, from: data)
    }

    func getConvoForMembers(members: [String]) async throws -> GetConvoForMembersResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        try checkChatSupport()

        var urlComponents = URLComponents(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.getConvoForMembers")!
        urlComponents.queryItems = members.map { URLQueryItem(name: "members", value: $0) }

        guard let url = urlComponents.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        return try decoder.decode(GetConvoForMembersResponse.self, from: data)
    }

    func getMessages(convoId: String, limit: Int = 50, cursor: String? = nil) async throws -> GetMessagesResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        try checkChatSupport()

        var urlComponents = URLComponents(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.getMessages")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "convoId", value: convoId),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw ATProtoError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }

        return try decoder.decode(GetMessagesResponse.self, from: data)
    }

    func sendMessage(convoId: String, message: MessageInput) async throws -> SendMessageResponse {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        try checkChatSupport()

        let url = URL(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.sendMessage")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "convoId": convoId,
            "message": [
                "text": message.text
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Failed to send message. Response: \(jsonString)")
            }
            throw ATProtoError.invalidResponse
        }

        return try decoder.decode(SendMessageResponse.self, from: data)
    }

    func updateRead(convoId: String, messageId: String? = nil) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        try checkChatSupport()

        let url = URL(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.updateRead")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["convoId": convoId]
        if let messageId = messageId {
            body["messageId"] = messageId
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }

    func muteConvo(convoId: String) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        try checkChatSupport()

        let url = URL(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.muteConvo")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["convoId": convoId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }

    func unmuteConvo(convoId: String) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        try checkChatSupport()

        let url = URL(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.unmuteConvo")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["convoId": convoId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }

    func leaveConvo(convoId: String) async throws {
        guard let session = session else {
            throw ATProtoError.unauthorized
        }

        try checkChatSupport()

        let url = URL(string: "\(chatBaseURL)/xrpc/chat.bsky.convo.leaveConvo")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["convoId": convoId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, httpResponse) = try await performAuthenticatedRequest(request)

        guard httpResponse.statusCode == 200 else {
            throw ATProtoError.invalidResponse
        }
    }
}
