# Skyscraper: Comprehensive Codebase Overview

## Project Summary

**Skyscraper** is a polished native iOS/macOS BlueSky client inspired by Ivory for Mastodon. It provides a modern, feature-rich interface for interacting with the BlueSky social network using the ATProtocol API.

- **Version**: 0.7
- **Bundle Identifier**: com.cameronbanga.Skyscraper
- **Development Team**: Cameron Banga
- **Deployment Target**: iOS 17.0+, macOS 13.0+
- **Swift Version**: 5.9+
- **Total Swift Files**: 58

---

## 1. Project Structure

```
Skyscraper/
├── Skyscraper/                    # Main app bundle
│   ├── Models/                    # Data models (6 files)
│   │   ├── ATProtoModels.swift    # Core BlueSky data structures
│   │   ├── ChatModels.swift       # Direct message models
│   │   ├── Language.swift         # Language preference models
│   │   ├── PostDraft.swift        # Draft post management
│   │   ├── PostModerationSettings.swift  # Moderation settings
│   │   └── StarterPackModels.swift # Starter pack models
│   │
│   ├── Services/                  # Business logic layer (10 files)
│   │   ├── ATProtoClient.swift    # Main API client (~900 lines)
│   │   ├── ATProtoConstants.swift # API constants
│   │   ├── AppTheme.swift         # Theme color management
│   │   ├── AccountManager.swift   # Multi-account management
│   │   ├── KeychainManager.swift  # Secure credential storage
│   │   ├── CoreDataStack.swift    # Post caching with Core Data
│   │   ├── PostCacheService.swift # Timeline cache management
│   │   ├── ImagePrefetchService.swift # Image preloading
│   │   ├── FirehoseService.swift  # Real-time JetStream updates
│   │   └── (Others)
│   │
│   ├── ViewModels/                # MVVM view models (7 files)
│   │   ├── AuthViewModel.swift    # Authentication state (~180 lines)
│   │   ├── TimelineViewModel.swift # Timeline/feed (~430 lines)
│   │   ├── PostComposerViewModel.swift # Post creation (~430 lines)
│   │   ├── ChatListViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   ├── SearchViewModel.swift
│   │   └── DiscoverViewModel.swift
│   │
│   ├── Views/                     # SwiftUI views (31 files)
│   │   ├── MainTabView.swift      # Tab navigation
│   │   ├── LoginView.swift        # Authentication UI
│   │   ├── TimelineView.swift     # Main feed
│   │   ├── PostComposerView.swift # Post creation (~25 KB)
│   │   ├── ProfileView.swift      # User profiles (~31 KB)
│   │   ├── PostDetailView.swift   # Post details/threading
│   │   ├── ChatListView.swift     # Direct message list
│   │   ├── ChatView.swift         # Conversation UI
│   │   ├── DiscoverView.swift     # Discover feeds
│   │   ├── SearchView.swift       # Global search
│   │   ├── NotificationsView.swift # Activity/mentions
│   │   ├── SettingsView.swift     # App settings (~24 KB)
│   │   ├── (And 19 more specialized views)
│   │
│   ├── Extensions/                # SwiftUI/model extensions (2 files)
│   │   ├── FeedViewPost+Extensions.swift
│   │   └── View+ScrollToTop.swift
│   │
│   ├── Utilities/                 # Cross-platform helpers (2 files)
│   │   ├── PlatformCompatibility.swift # iOS/macOS abstraction
│   │   └── Analytics.swift        # Conditional Firebase analytics
│   │
│   ├── Resources/                 # App assets
│   ├── Icons/                     # App icon assets
│   ├── Assets.xcassets/
│   └── GoogleService-Info.plist   # Firebase config
│
├── Skyscraper.xcodeproj/          # Xcode project
├── SkyscraperTests/               # Unit tests
├── SkyscraperUITests/             # UI tests
└── Scripts/                       # Build scripts
```

---

## 2. Architectural Patterns

### MVVM Architecture
The app follows a clean MVVM (Model-View-ViewModel) pattern:

**Models** → Data structures representing BlueSky objects
- `ATProtoModels.swift`: Core Post, Author, Profile, Feed structures
- Codable implementations for JSON serialization

**ViewModels** → Business logic and state management
- `@MainActor` annotation ensures UI updates on main thread
- `@Published` properties for reactive state
- Handle API calls, caching, and data transformations

**Views** → SwiftUI declarative UI
- Observe ViewModels via `@ObservedObject` and `@StateObject`
- NavigationStack for routing
- Sheet and NavigationDestination for navigation

### Service-Oriented Architecture
Core functionality is isolated in reusable services:

1. **ATProtoClient** - Central API orchestrator
2. **KeychainService/KeychainManager** - Secure storage
3. **CoreDataStack** - Post caching
4. **ImagePrefetchService** - Image preloading
5. **FirehoseService** - Real-time updates
6. **AccountManager** - Multi-account support

### Reactive Patterns
- **Combine framework** for async operations
- **async/await** for modern concurrency
- **@Published properties** for state changes
- **NotificationCenter** for cross-component communication

---

## 3. Main Features & Functionality

### Authentication & Multi-Account
- ✅ Secure login with BlueSky credentials
- ✅ App password support (recommended for security)
- ✅ Keychain storage with optional "Remember Me"
- ✅ Multi-account switching with automatic session management
- ✅ Custom PDS URL support for federated instances
- ✅ Session persistence across app launches

**Files**: `AuthViewModel.swift`, `KeychainManager.swift`, `AccountManager.swift`

### Timeline & Feed Management
- ✅ Pull-to-refresh timeline feed
- ✅ Infinite scroll with pagination (cursor-based)
- ✅ Multiple feed support (Following + Custom Feeds)
- ✅ Background fetch for new posts
- ✅ Post caching with Core Data (10-day retention)
- ✅ Scroll position restoration per feed
- ✅ Real-time post updates via JetStream firehose

**Files**: `TimelineViewModel.swift`, `TimelineView.swift`, `PostCacheService.swift`, `FirehoseService.swift`

### Post Composition
- ✅ Create posts with text (300 char limit)
- ✅ Multi-image support (up to 4 images)
- ✅ Alt text editor for accessibility
- ✅ Mention suggestions (@user autocomplete)
- ✅ Hashtag suggestions
- ✅ Language selection for posts
- ✅ Content moderation settings (labels)
- ✅ Draft saving with persistence
- ✅ Reply to posts with threading

**Files**: `PostComposerViewModel.swift`, `PostComposerView.swift`, `PostDraft.swift`

### Interactions
- ✅ Like/unlike posts
- ✅ Repost/un-repost
- ✅ Reply to posts
- ✅ Quote posts (embedded post replies)
- ✅ View post details and threads
- ✅ Like/repost counters

**Files**: Integrated in `ATProtoClient.swift`

### User Profiles
- ✅ View any user's profile
- ✅ Profile info (name, bio, avatar, follower counts)
- ✅ User's posts feed
- ✅ Follow/unfollow
- ✅ Block/mute users
- ✅ List management
- ✅ Feed subscriptions

**Files**: `ProfileView.swift`

### Direct Messages (Chat)
- ✅ List conversations
- ✅ Send/receive messages
- ✅ Message history with pagination
- ✅ Rich text support via facets
- ✅ Mute conversations
- ✅ Message deletion support
- ⚠️ Only available on bsky.social PDS

**Files**: `ChatViewModel.swift`, `ChatView.swift`, `ChatModels.swift`

### Discovery
- ✅ Discover trending feeds
- ✅ Custom feed browser
- ✅ Starter packs
- ✅ Hashtag search
- ✅ User search

**Files**: `DiscoverView.swift`, `DiscoverViewModel.swift`

### Settings & Customization
- ✅ Theme color picker (9 colors)
- ✅ Dark/Light mode support
- ✅ Keep screen awake toggle
- ✅ Refresh interval settings
- ✅ Multi-account management
- ✅ Developer notes/debug info

**Files**: `SettingsView.swift`, `AppTheme.swift`

---

## 4. Core Services & Their Responsibilities

### ATProtoClient (Main API Client)
**Size**: ~1,800 lines | **Type**: @MainActor class

**Responsibilities**:
- Session management (create, refresh, validate)
- All BlueSky API endpoints
- JSON encoding/decoding with snake_case conversion
- Error handling with detailed diagnostics
- Base URL management (supports custom PDS)
- Chat availability detection

**Key Methods**:
```
login() - Authenticate user
getProfile() - Fetch user profile
getTimeline() - Fetch feed posts
createPost() - Create new post
likePost() / repostPost() - Interactions
getFeed() - Get custom feed
```

### KeychainService & KeychainManager
**Responsibility**: Secure credential and session storage using iOS Keychain
- Store/retrieve sessions per account
- Store/retrieve credentials
- Support multi-account scenarios
- Delete data on logout/account removal

### AccountManager
**Responsibility**: Multi-account state management
- Track stored accounts
- Switch between accounts
- Persist account list
- Notify app of account changes via NotificationCenter

### CoreDataStack
**Responsibility**: Post caching infrastructure
- Programmatic Core Data model creation
- Persistent store configuration
- Automatic migration on schema changes
- Batch deletion of old posts (>10 days)

### PostCacheService
**Responsibility**: Timeline post caching
- Cache posts per feed
- Load cached posts on app startup
- Manage scroll positions
- Track last viewed timestamps
- Cleanup old data

### ImagePrefetchService
**Responsibility**: Image preloading for performance
- Prefetch images from posts in view
- Concurrent prefetch with max 3 concurrent downloads
- Download images to URLCache
- Extract from various embed types (images, videos, avatars)

### FirehoseService
**Responsibility**: Real-time post updates via WebSocket
- Connect to JetStream firehose endpoint
- Subscribe to specific DIDs or all posts
- Handle connection/reconnection logic
- Save cursor for resumption
- Notify app of new posts

### AppTheme
**Responsibility**: App-wide theme color management
- Track current accent color
- Persist color preference
- Support 9 theme colors
- Observable for reactive updates

---

## 5. Key Data Models & Relationships

### Post Hierarchy
```
Post (root post record)
├── Author (creator info)
├── PostRecord (text, facets, metadata)
├── PostEmbed (media container)
│   ├── ImageView[] (images)
│   ├── VideoView (video)
│   ├── ExternalView (link preview)
│   ├── EmbeddedPostRecord (quote)
│   └── MediaEmbed (record with media)
├── PostViewer (current user's interaction state)
│   ├── like (URI if liked)
│   ├── repost (URI if reposted)
│   └── bookmarked
└── ReplyRef (parent post for replies)
    └── Parent Post (recursive)

FeedViewPost (API response wrapper)
├── post: Post
├── reply: ReplyRef? (if reply)
└── reason: FeedReason? (if promoted)
```

### Profile Hierarchy
```
Profile
├── did (Decentralized Identifier)
├── handle (username)
├── displayName
├── description (bio)
├── avatar (image URL)
├── viewer (current user's relationship)
│   ├── muted
│   ├── blockedBy
│   ├── following
│   └── followedBy
└── associated
    ├── chat (DM settings)
    └── activitySubscription
```

### Chat Models
```
ConvoView (conversation)
├── id (DID-based)
├── members: ConvoMember[]
├── lastMessage: MessageUnion
└── unreadCount

MessageUnion (discriminated union)
├── messageView (active message)
│   └── text, facets, embed, sender, sentAt
└── deletedMessageView (deleted message)
    └── just metadata
```

### Facets (Text Formatting)
```
Facet (inline formatting metadata)
├── index: ByteSlice (character range)
└── features: Feature[]
    ├── Link (URL)
    ├── Mention (@user)
    ├── Tag (#hashtag)
    └── RichText (bold, italic, etc.)
```

---

## 6. Third-Party Dependencies & Frameworks

### Native Apple Frameworks
- **SwiftUI** - UI framework (iOS 17+)
- **Combine** - Reactive programming
- **Foundation** - Core functionality
- **CoreData** - Local data persistence
- **Security** - Keychain access
- **URLSession** - HTTP networking
- **PhotosUI** - Image/photo picker
- **AVKit** - Video playback

### Firebase (Conditional)
- **FirebaseCore** - Firebase initialization
- **FirebaseAnalytics** - Event tracking
- **FirebaseCrashlytics** - Crash reporting
- **Note**: Only compiled in Release builds for faster debug builds

### Platform-Specific
- **UIKit** (iOS) - Alt icon support, screen lock
- **AppKit** (macOS) - Native macOS integration

### Network & Images
- **URLCache** - HTTP caching (100MB memory, 500MB disk)
- **AsyncImage** - SwiftUI image loading
- **URLSessionWebSocketTask** - WebSocket for firehose

---

## 7. Build Configuration & Targets

### App Target
```
Product Name: Skyscraper
Bundle ID: com.cameronbanga.Skyscraper
Version: 0.7
Build: 1
Development Team: 5YESB723BS
Supported Platforms: iOS, macOS, xrOS (tvOS prep)
```

### Schemes
- **Skyscraper** (Debug/Release) - Main app
- Separate build configurations for optimization

### Build Optimization: Firebase
**Problem**: Firebase adds 30-45 seconds to debug builds
**Solution**: Conditional compilation with `#if !DEBUG`

```
Debug builds:    Firebase disabled, console logging only
Release builds:  Full Firebase functionality
```

**Benefits**:
- 50% faster debug builds (~30-45 sec vs 60-90 sec)
- No impact on production telemetry
- Automatic based on build config

### Build Settings
- String Catalog symbols generation enabled
- Hardened runtime enabled (macOS)
- App sandbox enabled (macOS)
- Outgoing network connections only
- Swift Approachable Concurrency enabled

---

## 8. Swift/SwiftUI Patterns & Conventions

### Concurrency
```swift
// Modern async/await throughout
async func login(identifier: String, password: String) async throws

// Task management
Task { @MainActor in
    // UI updates
}

// Background timers
nonisolated(unsafe) var backgroundTimer: Timer?
```

### State Management
```swift
// ViewModel pattern
@MainActor
class TimelineViewModel: ObservableObject {
    @Published var posts: [FeedViewPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
}

// View observation
struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @ObservedObject private var accountManager = AccountManager.shared
}
```

### Reactive Data Flow
```swift
// NotificationCenter for cross-component events
NotificationCenter.default.post(name: .accountDidSwitch, object: nil)
NotificationCenter.default.addObserver(
    forName: .refreshIntervalDidChange,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.startBackgroundFetching()
    }
}
```

### Navigation
```swift
// NavigationStack for hierarchical navigation
NavigationStack {
    // Root view
}
.navigationDestination(item: $profileToShow) { wrapper in
    ProfileView(actor: wrapper.actor)
}

// Sheet for modal presentation
.sheet(isPresented: $showComposer) {
    PostComposerView { posted in
        // Callback
    }
}
```

### Codable Customization
```swift
// Custom encoding/decoding for complex types
struct ATProtoSession: Codable {
    enum CodingKeys: String, CodingKey {
        case did, handle, accessJwt, refreshJwt, pdsURL
    }
}

// Discriminated unions (MessageUnion example)
enum MessageUnion: Codable {
    case messageView(MessageView)
    case deletedMessageView(DeletedMessageView)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        // Type-based initialization
    }
}
```

### Cross-Platform Type Aliases
```swift
// PlatformCompatibility.swift abstracts iOS/macOS
#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#endif
```

### Resource Management
```swift
// Proper cleanup in deinit
deinit {
    if let observer = refreshIntervalObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}

// WeakSelf capture to prevent cycles
Task { [weak self] in
    guard let self = self else { return }
}
```

### Error Handling
```swift
// Detailed error types
enum ATProtoError: Error, LocalizedError {
    case networkError(Error, url: String? = nil, statusCode: Int? = nil)
    case decodingError(Error)
    
    var errorDescription: String? {
        // Helpful error messages with debugging info
    }
}
```

---

## 9. Key Implementation Details

### Session Management Flow
```
Login Screen
    ↓
AuthViewModel.login(identifier, password, customPDS)
    ↓
ATProtoClient.login() → API call
    ↓
KeychainService.saveSession() → Secure storage
    ↓
AccountManager.addAccount() → Track all accounts
    ↓
Profile fetch → Avatar, display name
    ↓
MainTabView → Authenticated state
```

### Post Loading Pipeline
```
TimelineView appears
    ↓
TimelineViewModel loads available feeds
    ↓
Load cached posts from PostCacheService (Core Data)
    ↓
Show cached posts while fetching fresh
    ↓
ATProtoClient.getTimeline() → API call
    ↓
PostCacheService.cachePosts() → Store in Core Data
    ↓
Update view with new posts
    ↓
Start background fetch timer (configurable interval)
    ↓
FirehoseService monitors new posts
    ↓
Insert new posts when user scrolls to top
```

### Image Handling
```
Post with images appears on screen
    ↓
ImagePrefetchService.prefetchImages() triggered
    ↓
Extract all URLs from post embeds
    ↓
URLSession.download to URLCache
    ↓
AsyncImage in SwiftUI shows from cache
    ↓
Smooth scrolling performance
```

### Multi-Account Switching
```
User selects different account in Settings
    ↓
AccountManager.switchAccount(to:)
    ↓
KeychainService.retrieveSession() for new account
    ↓
ATProtoClient.switchToAccount()
    ↓
NotificationCenter.post(accountDidSwitch)
    ↓
TimelineViewModel resets and reloads
    ↓
New account's feed displays
```

---

## 10. Notable Architecture Decisions

### 1. Main Thread Enforcement
All ViewModels and Services use `@MainActor` annotation to guarantee UI thread safety:
```swift
@MainActor
class TimelineViewModel: ObservableObject { }
```

### 2. Conditional Firebase
Debug builds skip Firebase compilation entirely for 50% faster builds:
```swift
#if !DEBUG
import FirebaseCore
#endif
```

### 3. Programmatic Core Data
Core Data model is created programmatically rather than .xcdatamodeld:
- Easier version control
- No conflicts
- Self-documenting schema

### 4. Singleton Pattern
Key services use singletons for app-wide state:
- `ATProtoClient.shared`
- `AccountManager.shared`
- `KeychainService.shared`
- `CoreDataStack.shared`

### 5. Service Separation
Clear separation of concerns:
- API calls → `ATProtoClient`
- Storage → `KeychainService`, `PostCacheService`, `AccountManager`
- UI State → `ViewModels`
- Presentation → `Views`

### 6. Real-Time Updates
JetStream firehose provides real-time post updates without polling:
- Efficient WebSocket connection
- Cursor-based resumption
- DID filtering support

### 7. Graceful Degradation
Features work with custom PDS instances:
- Chat only enabled on bsky.social
- Multi-account within same PDS
- Custom PDS URL support in login

---

## 11. Performance Optimizations

### Image Caching
- URLCache: 100MB memory, 500MB disk
- Prefetch images ahead of viewport

### Post Caching
- Core Data cache with 10-day retention
- Scroll position restoration per feed
- Batch cleanup of old posts

### Background Fetching
- Configurable refresh interval
- Limits consecutive failures
- Graceful timeout handling

### Lazy Loading
- Infinite scroll with cursor-based pagination
- Only load posts as needed
- Thread counts without full replies

---

## 12. Testing Structure

- **SkyscraperTests/** - Unit tests (empty/minimal)
- **SkyscraperUITests/** - UI tests (empty/minimal)
- Manual testing via simulator and devices

---

## 13. File Size Distribution

```
SkyscraperApp.swift           116 lines
ATProtoClient.swift           ~1800 lines (largest)
TimelineViewModel.swift       ~430 lines
PostComposerViewModel.swift   ~430 lines
PostComposerView.swift        ~25KB visual
ProfileView.swift             ~31KB visual
SettingsView.swift            ~24KB visual
PostDetailView.swift          ~19KB visual
(Most other views)            ~10-15KB visual
```

---

## 14. Key External Resources

- **BlueSky/ATProtocol**: https://atproto.com
- **JetStream Firehose**: wss://jetstream2.us-east.bsky.network
- **GoogleService-Info.plist**: Firebase configuration (checked in)

---

## Summary

**Skyscraper** is a well-architected, modern iOS/macOS application that demonstrates professional Swift development practices:

✅ Clean MVVM architecture
✅ Reactive state management with Combine
✅ Modern async/await concurrency
✅ Comprehensive error handling
✅ Multi-account support
✅ Efficient caching strategies
✅ Real-time updates via WebSocket
✅ Cross-platform iOS/macOS support
✅ Accessibility considerations (alt text)
✅ Performance optimizations

The codebase is well-organized, maintainable, and ready for an AI agent to understand and extend.
