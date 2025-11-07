# Skyscraper: AI Agent Preparation Guide

This document is your complete guide to understanding the Skyscraper codebase for AI-assisted development.

## Overview

**Skyscraper** is a polished native iOS/macOS BlueSky client (version 0.7) with ~58 Swift files totaling ~2,700 lines of production code. It implements the full MVVM architecture pattern with reactive state management using Combine and modern async/await concurrency.

**Key Fact**: The app connects to the BlueSky social network using the ATProtocol API, providing a feature-rich interface for posting, browsing timelines, managing direct messages, and discovering content.

---

## What This Project Does

### Core Functionality
1. **Social Networking Client** - View timelines, posts, profiles, likes, reposts
2. **Content Creation** - Compose posts with images, mentions, hashtags, language selection
3. **Direct Messaging** - Send and receive direct messages (bsky.social only)
4. **User Profiles** - Browse user profiles, follow/unfollow, manage lists
5. **Accounts** - Multi-account support with easy switching
6. **Discovery** - Discover feeds, trending content, hashtag search
7. **Caching** - Local caching of posts and images for offline viewing

### Technical Highlights
- Cross-platform (iOS + macOS)
- Real-time updates via WebSocket (JetStream firehose)
- Secure credential storage via Keychain
- Core Data-based post caching
- Image prefetching for smooth scrolling
- Conditional Firebase (debug vs. release builds)

---

## Documentation Files

### 1. CODEBASE_OVERVIEW.md (21 KB)
**Purpose**: Comprehensive architectural documentation

Contains:
- Complete project structure with file organization
- MVVM architectural patterns and implementation
- All 14 major features explained
- Service responsibilities and data flow
- Complete data model hierarchies
- Code examples for critical patterns
- Implementation details with flowcharts
- Architecture decisions and rationale
- Performance optimizations
- Testing structure

**When to Use**: Understanding overall architecture, design patterns, how components interact

**Key Sections**:
- Section 2: Architectural Patterns (MVVM, Services, Reactive)
- Section 3: Features (Auth, Timeline, Posts, Chat, Profiles)
- Section 4: Core Services (ATProtoClient, KeychainService, etc.)
- Section 8: Swift/SwiftUI Patterns (Concurrency, State, Navigation)
- Section 9: Implementation Details (Flowcharts for key flows)

---

### 2. QUICK_REFERENCE.md (7.5 KB)
**Purpose**: Fast lookup for developers and AI agents

Contains:
- Essential file paths with descriptions
- Critical coding patterns used throughout
- Key classes reference table
- Important data models
- Common task examples with code
- API endpoints used
- Build and debug info
- Common modifications guide
- File size reference
- Threading and performance notes

**When to Use**: Quick lookup during development, implementation reference, pattern examples

**Best For**: 
- Finding the right file quickly
- Understanding how to implement something
- Copy-paste code patterns
- Threading and performance checks

---

### 3. FIREBASE_BUILD_OPTIMIZATION.md (3.2 KB)
**Purpose**: Explains the Firebase conditional compilation optimization

**Key Points**:
- Firebase disabled in Debug builds (50% faster builds)
- Full Firebase in Release builds
- How the `#if !DEBUG` pattern works
- Build performance improvements documented

---

### 4. README.md (3 KB)
**Purpose**: User-facing project information

Contains:
- Feature list
- Architecture overview
- Project structure
- Getting started instructions
- First launch setup

---

## How to Use These Documents

### Scenario 1: "I need to understand the whole codebase"
1. Start with **QUICK_REFERENCE.md** (overview)
2. Read **CODEBASE_OVERVIEW.md** Sections 1-3 (structure and architecture)
3. Skim Section 4 (services)
4. Read Section 5 (data models)

### Scenario 2: "How do I add a new feature?"
1. Check **QUICK_REFERENCE.md** → "Common Modifications"
2. Look at existing similar feature in relevant ViewModel/View
3. Check **CODEBASE_OVERVIEW.md** → Section 8 (Patterns)
4. Reference Section 9 (Implementation Details) for flow examples

### Scenario 3: "I need to fix a bug in the timeline"
1. **QUICK_REFERENCE.md** → Essential File Paths → TimelineViewModel
2. **CODEBASE_OVERVIEW.md** → Section 4 (Services) → PostCacheService
3. Check implementation details for the "Post Loading Pipeline" flow

### Scenario 4: "How do I authenticate a user?"
1. **QUICK_REFERENCE.md** → "Handle Authentication" code example
2. **CODEBASE_OVERVIEW.md** → Section 3 (Authentication & Multi-Account)
3. Look at `AuthViewModel.swift` and `AccountManager.swift`

---

## Key Concepts (Must Know)

### 1. Service Layer (Business Logic)
- `ATProtoClient.shared` - Singleton for ALL API calls
- `AccountManager.shared` - Track current account and switch between accounts
- `KeychainService.shared` - Secure credential storage
- `PostCacheService.shared` - Post caching operations

**Critical**: Always use `.shared` singleton instances, never create new ones.

### 2. ViewModel Layer (State Management)
- All ViewModels are `@MainActor` class
- Use `@Published` for observable properties
- Handle API calls and errors
- Notify views of state changes

### 3. View Layer (UI)
- SwiftUI views observe ViewModels
- Use `@StateObject` for creating new VMs
- Use `@ObservedObject` for injected VMs
- Use `NavigationStack` for routing

### 4. Data Flow
```
View → ViewModel → Service → ATProtoClient → BlueSky API → JSON Decoding → Service → ViewModel → View
```

### 5. Threading Model
- **Main Thread**: UI updates, ViewModels, most Services
- **Background**: Image downloads, WebSocket (firehose)
- **Always**: Use `async/await`, no `.background()` dispatch queues

---

## Critical File: ATProtoClient.swift

**This is THE most important file in the entire app.** It's ~1,800 lines and contains:

- Session management (login, token refresh)
- Every BlueSky API endpoint call
- JSON encoding/decoding
- Error handling with detailed diagnostics
- Chat availability detection
- Base URL management

**Every feature** ultimately calls methods from this class. When adding API functionality, you're almost certainly adding a method here first.

**Location**: `/Skyscraper/Services/ATProtoClient.swift`

---

## Critical ViewModel: TimelineViewModel

**This is the most complex ViewModel** because it manages:
- Timeline post fetching and pagination
- Post caching
- Multiple feeds (Following + Custom)
- Background refresh timer
- Real-time updates
- Scroll position restoration
- Account switching

Understanding this ViewModel helps you understand how state management works in the app.

**Location**: `/Skyscraper/ViewModels/TimelineViewModel.swift`

---

## Critical Data Model: ATProtoModels.swift

**This file is complex** with ~900 lines defining:
- Post and PostRecord structures
- Author and Profile information
- Embed types (Images, Videos, External links, Quoted posts)
- Facets (text formatting and mentions)
- Feed response structures

Understanding the Post hierarchy (Post → Author → PostEmbed → various embed types) is essential for working with content.

---

## Code Patterns You'll See Everywhere

### Pattern 1: @MainActor with async/await
```swift
@MainActor
func loadData() async {
    do {
        let data = try await apiClient.fetchData()
        self.data = data
    } catch {
        self.errorMessage = error.localizedDescription
    }
}
```

### Pattern 2: Singleton access
```swift
let client = ATProtoClient.shared
let accountMgr = AccountManager.shared
```

### Pattern 3: NotificationCenter for component communication
```swift
// Post notification
NotificationCenter.default.post(name: .accountDidSwitch, object: nil)

// Listen for notification
NotificationCenter.default.addObserver(
    forName: .refreshIntervalDidChange,
    object: nil,
    queue: .main
) { [weak self] _ in
    Task { @MainActor [weak self] in
        self?.restartTimer()
    }
}
```

### Pattern 4: Codable with custom keys
```swift
enum CodingKeys: String, CodingKey {
    case accessJwt = "accessJwt"
    case pdsURL = "pdsUrl"
}
```

---

## Common Issues & Solutions

### Issue: "Thread safety warning"
**Solution**: Add `@MainActor` to the class if missing

### Issue: "ViewModel not updating UI"
**Solution**: Check if property is marked `@Published`

### Issue: "API call hanging"
**Solution**: Check if using `try await`, ensure on async context

### Issue: "Account switching doesn't reload content"
**Solution**: Make sure ViewModel listens to `.accountDidSwitch` notification

### Issue: "Firebase build slow"
**Solution**: That's only in Release builds. Debug builds have Firebase disabled by design.

---

## Development Workflow for AI Agents

### When Adding a Feature:

1. **Identify the layer needed**
   - UI only? → New View or modify View
   - State/logic? → New ViewModel or modify existing
   - API call? → Add method to ATProtoClient
   - Storage? → Use PostCacheService or KeychainService

2. **Follow the singleton pattern**
   ```swift
   let client = ATProtoClient.shared
   let cache = PostCacheService.shared
   ```

3. **Use @MainActor and async/await**
   ```swift
   @MainActor
   class MyViewModel: ObservableObject {
       async func loadData() { }
   }
   ```

4. **Add proper error handling**
   ```swift
   @Published var errorMessage: String?
   // Set this when errors occur
   ```

5. **Use @Published for state**
   ```swift
   @Published var items: [Item] = []
   ```

6. **Test with print debugging**
   - Console logs use emoji prefixes for easy scanning
   - Look for 🔥, 📂, 🔑, ✅, ❌, 💾

---

## File Organization Reference

```
Models/              → Data structures only (no logic)
Services/            → Business logic, singletons, API calls
ViewModels/          → State management (@MainActor, @Published)
Views/               → UI only (observe ViewModels)
Extensions/          → Protocol extensions
Utilities/           → Helper functions, cross-platform abstractions
Resources/           → Assets, strings, colors
```

---

## Build System Notes

### Schemes
- Single scheme: "Skyscraper"
- Debug vs Release configured separately

### Targets
- Main app target: "Skyscraper"
- Test targets: "SkyscraperTests", "SkyscraperUITests"

### Firebase Optimization
- Debug: Disabled (faster builds)
- Release: Enabled (crash reporting, analytics)

### Supported Platforms
- iOS (primary)
- macOS (secondary, uses sidebar adaptation)
- xrOS (prepared, not fully integrated)

---

## Testing Guidance

### Manual Testing Checklist
1. Login/logout flow
2. Timeline loads and refresh works
3. Composing post with images
4. Like/repost interactions
5. Profile viewing and following
6. Account switching
7. Offline viewing (cached posts)
8. Theme color changes

### Debugging Tips
- Check console for emoji-prefixed logs
- Use breakpoints in ViewModels
- Monitor Network tab in Xcode for API calls
- Check Core Data in Debug navigator (Timeline Cache)

---

## Integration Points

### What Skyscraper Depends On
- BlueSky ATProtocol API (external)
- JetStream WebSocket (wss://jetstream2.us-east.bsky.network)
- Firebase (conditional)
- Apple frameworks (SwiftUI, Combine, CoreData, etc.)

### What Can Depend on Skyscraper
- Share extensions
- Widgets (future)
- App clips (future)
- Watch app (future)

---

## Performance Expectations

- Initial load: ~2 seconds (cached posts show immediately)
- Fresh timeline fetch: ~1-2 seconds
- Image scroll: Smooth at 60fps (thanks to prefetching)
- Memory usage: ~100-200MB typical
- Battery impact: Minimal (no continuous polling)

---

## Version History Notes

- **v0.7** (current): Multi-account support, chat, real-time updates
- **v0.6**: Initial release
- Future: Streaming preferences, list management, advanced moderation

---

## Where to Get Help

1. **Architecture questions** → Read CODEBASE_OVERVIEW.md
2. **Quick lookup** → Use QUICK_REFERENCE.md
3. **BlueSky API questions** → https://docs.bsky.app
4. **Swift/SwiftUI questions** → Apple's official documentation
5. **Code examples** → Look at existing similar implementations

---

## Summary for AI Agents

You are now equipped to:
- Understand the overall architecture
- Navigate the codebase quickly
- Add new features following established patterns
- Fix bugs in context
- Write performant, correct Swift code
- Handle async/await and threading correctly
- Work with multi-account support
- Interact with the BlueSky API

The codebase is well-organized, well-documented, and ready for AI-assisted development.

**Most Important**: Always refer to existing code patterns before writing new code. The app is consistent and intentional in its design.

---

**Prepared for**: AI Agent Development
**Date**: 2025-11-03
**Version**: 0.7
**Status**: Production Ready
