# Skyscraper File Reference Guide

## Critical Files by Category

### API & Networking Layer
- `/Skyscraper/Services/ATProtoClient.swift` (2380 lines)
  - All BlueSky API endpoints
  - Session management
  - Authentication flow
  - All HTTP request/response handling
  
- `/Skyscraper/Services/ATProtoConstants.swift`
  - API endpoint constants
  
- `/Skyscraper/Models/ATProtoModels.swift`
  - Post, Profile, FeedViewPost models
  - Session and authentication models
  - All response types

### Application State Management
- `/Skyscraper/Services/AccountManager.swift`
  - Multi-account switching
  - Current session management
  - Account persistence
  
- `/Skyscraper/Services/KeychainManager.swift`
  - Secure token storage
  - Credential persistence

### Core ViewModels
- `/Skyscraper/ViewModels/TimelineViewModel.swift` (430 lines)
  - Feed loading and state
  - Refresh intervals
  - Background fetching
  
- `/Skyscraper/ViewModels/PostComposerViewModel.swift` (430 lines)
  - Post creation logic
  - Image handling
  - Mention/hashtag detection
  - Draft management
  
- `/Skyscraper/ViewModels/AuthViewModel.swift` (180 lines)
  - Login/logout logic
  - Authentication state
  
- `/Skyscraper/ViewModels/DiscoverViewModel.swift`
  - Trending topics
  - Discover feed state
  
- `/Skyscraper/ViewModels/SearchViewModel.swift`
  - Post and user search
  
- `/Skyscraper/ViewModels/ChatViewModel.swift`
  - DM conversation state
  
- `/Skyscraper/ViewModels/ChatListViewModel.swift`
  - DM list management

### Primary Views (UI)
- `/Skyscraper/Views/MainTabView.swift` (80 lines)
  - Main navigation structure
  - Tab switching logic
  
- `/Skyscraper/Views/TimelineView.swift` (60KB)
  - Main feed display
  - Post rendering
  - Navigation handling
  
- `/Skyscraper/Views/PostComposerView.swift` (24KB)
  - Post creation UI
  - Image upload
  - Alt text editor
  
- `/Skyscraper/Views/PostDetailView.swift` (20KB)
  - Thread/reply view
  - Parent post context
  
- `/Skyscraper/Views/ProfileView.swift` (32KB)
  - User profile display
  - Follower/following lists
  - Content tabs (Posts/Replies/Lists/StarterPacks)
  
- `/Skyscraper/Views/SettingsView.swift` (24KB)
  - User preferences
  - Account management
  - Theme selection
  
- `/Skyscraper/Views/LoginView.swift` (10KB)
  - Authentication UI
  
- `/Skyscraper/Views/NotificationsView.swift` (11KB)
  - Activity/notifications feed
  
- `/Skyscraper/Views/ChatListView.swift` (9KB)
  - DM conversations list
  
- `/Skyscraper/Views/ChatView.swift` (10KB)
  - DM conversation view

### Discovery & Browse Views
- `/Skyscraper/Views/DiscoverView.swift` (9KB)
  - Trending topics display
  - Suggested feeds
  
- `/Skyscraper/Views/FeedBrowserView.swift` (10KB)
  - Custom feed selection
  - Feed browser UI
  
- `/Skyscraper/Views/SearchView.swift` (4KB)
  - Global search UI
  
- `/Skyscraper/Views/HashtagSearchView.swift` (12KB)
  - Hashtag specific search
  
- `/Skyscraper/Views/StarterPackBrowserView.swift` (8KB)
  - Starter pack discovery
  
- `/Skyscraper/Views/StarterPackDetailView.swift` (14KB)
  - Starter pack details

### Settings & Moderation Views
- `/Skyscraper/Views/ModerationSettingsView.swift` (15KB)
  - Muted words management
  - Content filtering options
  
- `/Skyscraper/Views/PostModerationSettingsView.swift` (9KB)
  - Per-post moderation controls
  - Reply restrictions

### Helper Views
- `/Skyscraper/Views/FullScreenImageView.swift`
  - Full-screen image viewer
  
- `/Skyscraper/Views/VideoPlayerView.swift` (4KB)
  - Video playback UI
  
- `/Skyscraper/Views/RetryableAsyncImage.swift` (4KB)
  - Resilient image loading
  
- `/Skyscraper/Views/AltTextEditorView.swift` (7KB)
  - Alt text editing
  
- `/Skyscraper/Views/AttributedTextView.swift` (10KB)
  - Rich text rendering
  
- `/Skyscraper/Views/SafariView.swift`
  - Web view wrapper
  
- `/Skyscraper/Views/LanguagePickerView.swift`
  - Language selection UI
  
- `/Skyscraper/Views/ThemeColorPickerView.swift`
  - Theme color selection
  
- `/Skyscraper/Views/FeedSelectorView.swift`
  - Feed selection UI
  
- `/Skyscraper/Views/CurrentUserProfileView.swift` (7KB)
  - Logged-in user profile
  
- `/Skyscraper/Views/NewConversationView.swift` (12KB)
  - New DM conversation creation
  
- `/Skyscraper/Views/DraftsListView.swift` (3KB)
  - Draft management UI

### Service Layer
- `/Skyscraper/Services/AppTheme.swift`
  - Theme color management
  - Appearance settings
  
- `/Skyscraper/Services/CoreDataStack.swift`
  - Core Data database setup
  - Post caching infrastructure
  
- `/Skyscraper/Services/PostCacheService.swift`
  - Timeline caching operations
  
- `/Skyscraper/Services/ImagePrefetchService.swift`
  - Image preloading
  
- `/Skyscraper/Services/FirehoseService.swift`
  - Real-time WebSocket updates
  - JetStream integration
  
- `/Skyscraper/Services/ImageCaptionService.swift`
  - Image caption generation
  
- `/Skyscraper/Services/Timeline/TimelineFetchService.swift`
  - Timeline fetching logic
  
- `/Skyscraper/Services/Timeline/TimelineCacheService.swift`
  - Timeline caching implementation
  
- `/Skyscraper/Services/Timeline/BackgroundRefreshService.swift`
  - Background refresh scheduling
  
- `/Skyscraper/Services/Timeline/TimelineAnalytics.swift`
  - Timeline event tracking

### Data Models
- `/Skyscraper/Models/ATProtoModels.swift`
  - FeedViewPost, Post, Author, Profile
  - Session, AuthSession
  - Thread, ThreadViewPost
  - All request/response types
  
- `/Skyscraper/Models/ChatModels.swift`
  - DM conversation models
  - Message models
  
- `/Skyscraper/Models/PostDraft.swift`
  - Draft storage model
  
- `/Skyscraper/Models/PostModerationSettings.swift`
  - Per-post moderation options
  
- `/Skyscraper/Models/Language.swift`
  - Language definitions
  
- `/Skyscraper/Models/StarterPackModels.swift`
  - Starter pack data structures

### Extensions
- `/Skyscraper/Extensions/FeedViewPost+Extensions.swift`
  - FeedViewPost helper methods
  
- `/Skyscraper/Extensions/View+ScrollToTop.swift`
  - Scroll position helpers

### Utilities
- `/Skyscraper/Utilities/Logger.swift`
  - Unified logging system
  - Debug and production logging
  
- `/Skyscraper/Utilities/Analytics.swift`
  - Firebase conditional analytics
  
- `/Skyscraper/Utilities/PlatformCompatibility.swift`
  - iOS/macOS abstraction layer
  
- `/Skyscraper/Utilities/ScrollToTopModifier.swift`
  - Scroll restoration helpers

### Application Entry Point
- `/Skyscraper/SkyscraperApp.swift`
  - App initialization
  - Firebase configuration (conditional)
  - Root navigation setup

---

## Files by Feature

### Timeline Feature
- TimelineView.swift (display)
- TimelineViewModel.swift (logic)
- TimelineState.swift (state)
- TimelineFetchService.swift (fetching)
- TimelineCacheService.swift (caching)
- BackgroundRefreshService.swift (refresh)
- ATProtoClient: getTimeline()

### Post Creation Feature
- PostComposerView.swift (UI)
- PostComposerViewModel.swift (logic)
- ATProtoClient: createPost(), uploadImage()
- PostDraft.swift (draft model)
- AltTextEditorView.swift (helper)

### Profile Feature
- ProfileView.swift (display)
- CurrentUserProfileView.swift (current user)
- ATProtoClient: getProfile(), getAuthorFeed(), getFollows(), getFollowers()

### Search Feature
- SearchView.swift (global)
- HashtagSearchView.swift (hashtags)
- SearchViewModel.swift (logic)
- ATProtoClient: searchPosts(), searchUsers()

### Chat/DM Feature
- ChatListView.swift (list)
- ChatView.swift (conversation)
- ChatListViewModel.swift (list logic)
- ChatViewModel.swift (conversation logic)
- NewConversationView.swift (new conversation)
- ATProtoClient: listConvos(), getMessages(), sendMessage(), etc.

### Authentication
- LoginView.swift (UI)
- AuthViewModel.swift (logic)
- KeychainManager.swift (storage)
- AccountManager.swift (multi-account)
- ATProtoClient: login(), refreshSession()

### Settings & Moderation
- SettingsView.swift (main settings)
- ModerationSettingsView.swift (content filters)
- PostModerationSettingsView.swift (per-post)
- AppTheme.swift (theme management)

### Discovery
- DiscoverView.swift (discover hub)
- DiscoverViewModel.swift (logic)
- FeedBrowserView.swift (feed selection)
- StarterPackBrowserView.swift (starter packs)
- StarterPackDetailView.swift (details)
- ATProtoClient: getTrendingTopics(), getSuggestedFeeds(), getStarterPacks()

---

## Where to Add New Features

### To add a new feature, you'll typically need to modify:

1. **For API calls only:**
   - ATProtoClient.swift (add method)
   - Maybe ATProtoModels.swift (add response type)

2. **For a new View Screen:**
   - Create Views/YourFeatureView.swift
   - Create ViewModels/YourFeatureViewModel.swift (if complex)
   - Add to MainTabView.swift or navigation chain
   - Add any needed Models in Models/

3. **For a feature in existing view:**
   - Edit the View file
   - Edit the ViewModel file (if needed)
   - Edit ATProtoClient.swift (if new API call)
   - Add Models in Models/ (if needed)

### Example: Adding User Likes Feature
Files to modify:
1. ProfileView.swift - Add "Likes" tab
2. ProfileViewModel.swift (create new) - Handle getActorLikes() call
3. ATProtoClient.swift - getActorLikes() already exists, so nothing needed
4. Models/ATProtoModels.swift - Check if FeedResponse exists (it does)

### Example: Adding Bookmarks Feature
Files to create/modify:
1. Views/BookmarksView.swift (new)
2. ViewModels/BookmarksViewModel.swift (new)
3. ATProtoClient.swift - Add bookmarkPost(), unbookmarkPost(), getBookmarks()
4. Models/ATProtoModels.swift - Add BookmarkResponse if needed
5. MainTabView.swift - Add Bookmarks tab (conditional or permanent)

---

## Code Size Reference

Largest Files (lines of code):
- ATProtoClient.swift: 2,380 lines
- TimelineView.swift: ~1,500 lines (60KB file)
- ProfileView.swift: ~1,200 lines (32KB file)
- PostComposerView.swift: ~700 lines (24KB file)
- SettingsView.swift: ~700 lines (24KB file)
- ModerationSettingsView.swift: ~450 lines (15KB file)
- PostDetailView.swift: ~550 lines (20KB file)

Most of large file sizes are due to UI complexity, not logic complexity.

---

## Important Code Patterns

### Making an API Call
See TimelineViewModel.swift around line 150-200 for the pattern:
```swift
private let client = ATProtoClient.shared

func loadTimeline() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
        let response = try await client.getTimeline()
        self.posts = response.feed
    } catch {
        self.errorMessage = error.localizedDescription
    }
}
```

### Creating a ViewModel
See PostComposerViewModel.swift (lines 19-80):
```swift
@MainActor
class PostComposerViewModel: ObservableObject {
    @Published var text = ""
    @Published var isPosting = false
    @Published var errorMessage: String?
    
    private let client = ATProtoClient.shared
    
    func submitPost() async {
        // implementation
    }
}
```

### Creating a View
See TimelineView.swift (lines 11-40):
```swift
struct TimelineView: View {
    @StateObject private var viewModel = TimelineViewModel()
    @EnvironmentObject var theme: AppTheme
    
    var body: some View {
        // UI here
    }
}
```

