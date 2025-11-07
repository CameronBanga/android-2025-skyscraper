# Skyscraper: Quick Reference Guide for AI Agents

## Essential File Paths

### Core Application Entry
- `/Users/cameronbanga/Developer/git/apple-2025-skyscraper/Skyscraper/Skyscraper/SkyscraperApp.swift` - App root

### Key Services (Business Logic)
- `Services/ATProtoClient.swift` - BlueSky API client (THE most important file)
- `Services/AccountManager.swift` - Multi-account state
- `Services/KeychainManager.swift` - Secure storage
- `Services/PostCacheService.swift` - Timeline caching
- `Services/FirehoseService.swift` - Real-time updates
- `Services/ImagePrefetchService.swift` - Image preloading

### ViewModels (State Management)
- `ViewModels/AuthViewModel.swift` - Login/auth state
- `ViewModels/TimelineViewModel.swift` - Main feed state
- `ViewModels/PostComposerViewModel.swift` - Post creation state

### Views (UI Layer)
- `Views/MainTabView.swift` - Tab navigation hub
- `Views/LoginView.swift` - Auth screen
- `Views/TimelineView.swift` - Main feed screen
- `Views/PostComposerView.swift` - Post composer

### Data Models
- `Models/ATProtoModels.swift` - Post, Profile, Author, etc. (complex file)
- `Models/ChatModels.swift` - Message, Conversation models
- `Models/PostDraft.swift` - Draft management

---

## Critical Patterns

### ViewModels are @MainActor
```swift
@MainActor
class TimelineViewModel: ObservableObject {
    @Published var posts: [FeedViewPost] = []
}
```

### All API calls through ATProtoClient.shared
```swift
let client = ATProtoClient.shared
let profile = try await client.getProfile(actor: "did:plc:...")
```

### Account-aware operations
```swift
let accountManager = AccountManager.shared
accountManager.switchAccount(to: accountId)
```

### Session management via KeychainService
```swift
let keychain = KeychainService.shared
try keychain.saveSession(session)
```

---

## Key Classes to Know

| Class | Location | Purpose |
|-------|----------|---------|
| `ATProtoClient` | Services/ | API calls to BlueSky |
| `AccountManager` | Services/ | Track multiple accounts |
| `KeychainManager` | Services/ | Secure storage |
| `CoreDataStack` | Services/ | Post caching infrastructure |
| `PostCacheService` | Services/ | Cache operations |
| `TimelineViewModel` | ViewModels/ | Feed state management |
| `AuthViewModel` | ViewModels/ | Auth state management |
| `AppTheme` | Services/ | Theme color management |

---

## Important Data Models

### Post Structure
```swift
struct FeedViewPost: Codable {
    let post: Post           // Main post data
    let reply: ReplyRef?     // Parent if reply
    let reason: FeedReason?  // Why shown (promoted, etc.)
}

struct Post: Codable {
    let uri: String
    let author: Author
    let record: PostRecord
    let embed: PostEmbed?    // Images, videos, links
    let viewer: PostViewer?  // Current user's interaction
    let replyCount, repostCount, likeCount: Int?
}
```

### Session Storage
```swift
struct ATProtoSession: Codable {
    let did: String           // Decentralized identifier
    let handle: String        // Username
    let accessJwt: String     // API token
    let refreshJwt: String    // Refresh token
    let pdsURL: String?       // Custom PDS endpoint
}
```

---

## Common Tasks

### Get User's Timeline
```swift
let viewModel = TimelineViewModel()
await viewModel.loadTimeline() // Uses cached posts + fresh API
```

### Create a Post
```swift
let composerVM = PostComposerViewModel()
composerVM.text = "Hello BlueSky!"
try await composerVM.submitPost()
```

### Switch Accounts
```swift
let accountMgr = AccountManager.shared
accountMgr.switchAccount(to: newAccountDid)
// Triggers TimelineViewModel reload via NotificationCenter
```

### Cache Posts
```swift
let cacheService = PostCacheService.shared
cacheService.cachePosts(posts, feedId: "following")
// Stored in Core Data with 10-day cleanup
```

### Handle Authentication
```swift
let authVM = AuthViewModel()
let success = await authVM.login(
    identifier: "user.bsky.social",
    password: "app_password",
    rememberMe: true,
    customPDSURL: nil
)
```

---

## API Endpoints Used (in ATProtoClient)

### Authentication
- `POST /xrpc/com.atproto.server.createSession`
- `POST /xrpc/com.atproto.server.refreshSession`

### Posts
- `GET /xrpc/app.bsky.feed.getTimeline` - Main feed
- `POST /xrpc/app.bsky.feed.createPost` - Create post
- `POST /xrpc/app.bsky.feed.like` - Like
- `POST /xrpc/app.bsky.feed.repost` - Repost

### Profiles
- `GET /xrpc/app.bsky.actor.getProfile` - Profile info
- `POST /xrpc/app.bsky.graph.follow` - Follow user

### Chat
- `GET /xrpc/chat.bsky.convo.listConvos` - List conversations
- `POST /xrpc/chat.bsky.convo.sendMessage` - Send message

---

## Build & Debug

### Firebase Build Optimization
- Debug builds: Firebase disabled (50% faster builds)
- Release builds: Full Firebase enabled
- See `FIREBASE_BUILD_OPTIMIZATION.md`

### Debugging Logs
All major operations log to console:
- Account operations: "📂", "🔑", "✅", "❌"
- Network: "🔥", "ℹ️", "❌"
- Cache: "💾", "Cached post", "Loaded"

### Testing Credentials
Use BlueSky test accounts with app passwords (not your main password!)
Create at: https://bsky.app/settings/app-passwords

---

## Common Modifications

### Add New API Endpoint
1. Add method to `ATProtoClient` class
2. Return proper Codable types
3. Handle errors with `ATProtoError`

### Add New ViewModel
1. Create `@MainActor class XyzViewModel: ObservableObject`
2. Use `@Published` for observable state
3. Call `ATProtoClient.shared` for API
4. Include error handling

### Add New View
1. Create struct conforming to `View`
2. Inject ViewModel via `@StateObject` or `@Environment`
3. Use `NavigationStack` and `.navigationDestination` for routing
4. Use `.sheet` for modals

---

## File Sizes Reference

```
Largest files (most complex):
- ATProtoClient.swift       ~1,800 lines (API client)
- TimelineViewModel.swift   ~430 lines (feed state)
- PostComposerViewModel.swift ~430 lines (post creation)
- ProfileView.swift         ~31 KB (user profile UI)
- SettingsView.swift        ~24 KB (settings UI)
- PostComposerView.swift    ~25 KB (post creation UI)

Total: 58 Swift files
```

---

## NotificationCenter Events

These are used for inter-component communication:

| Event | Posted By | Observers |
|-------|-----------|-----------|
| `.accountDidSwitch` | AccountManager | TimelineViewModel (to reload) |
| `.refreshIntervalDidChange` | SettingsView | TimelineViewModel (restart timer) |

---

## Threading Notes

- All ViewModels are `@MainActor` - UI thread guaranteed
- All API calls use `async/await`
- Image prefetch happens in background
- CoreData operations use view context (main thread)
- WebSocket (firehose) updates trigger main thread dispatch

---

## Performance Characteristics

- Image Cache: 100MB memory, 500MB disk
- Post Cache: Up to 50 posts per feed in Core Data
- Background Fetch: Configurable 5-60 minute intervals
- Prefetch Concurrency: Max 3 simultaneous image downloads
- URL Session: Persistent, shared across app

---

## Testing the App

### Minimum Test
1. Open Xcode
2. Select iOS Simulator (or device)
3. Build & Run
4. Login with BlueSky credentials
5. See timeline feed

### Features to Test
- Pull to refresh timeline
- Tap post to see details
- Tap profile name to see user profile
- Compose new post
- Switch accounts (if logged in to multiple)
- Change theme color in settings
- Verify images load and cache works

---

## Useful References

- ATProtocol Spec: https://atproto.com
- Bluesky Developer Docs: https://docs.bsky.app
- Xcode 16 Release Notes
- SwiftUI documentation
- Core Data documentation

---

**Last Updated**: 2025-11-03
**Version**: 0.7
