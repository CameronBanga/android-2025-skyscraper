# Skyscraper

A polished native multi-platform BlueSky client for iOS, macOS, and visionOS, inspired by Ivory for Mastodon.

**Current Version:** 0.7

## Features

### Core Features
- **Multi-Platform Support**: Native support for iOS, macOS, and visionOS
- **Authentication**: Secure login with BlueSky credentials and app passwords
- **Keychain Storage**: Session persistence across app rebuilds with optional "Remember Me"
- **Timeline**: Beautiful, smooth-scrolling feed with pull-to-refresh
- **Post Composition**: Create posts and replies with character counter, draft saving, and alt text support
- **Interactions**: Like, repost, and reply to posts
- **User Search**: Find people on BlueSky with real-time search
- **Profile Viewing**: View any user's profile including your own
- **Rich Media**: Support for images with full-screen viewing, video playback, external links, and embedded posts
- **Direct Messages**: Chat functionality with conversation management
- **Notifications**: Stay updated with real-time notifications
- **Discover**: Explore new content and trending topics
- **Custom Feeds**: Browse and subscribe to custom feeds
- **Hashtag Search**: Search and explore content by hashtags
- **Starter Packs**: Browse and share starter pack collections
- **Post Moderation**: Customize content moderation settings
- **Drafts**: Save and manage post drafts
- **Multi-Language Support**: Interface supports multiple languages

### Design Highlights
- Clean, minimal interface inspired by Ivory
- Customizable theme with accent color picker (default orange)
- Smooth animations and transitions
- Modern SwiftUI with latest Swift 6 features
- Responsive and polished UI across all platforms
- Support for light and dark modes
- Native platform-specific navigation (tab bar on iOS/visionOS, optimized window sizing for macOS)
- Image prefetching for smooth scrolling
- Advanced caching for optimal performance

## Architecture

Built with modern Apple platform best practices:

- **MVVM Pattern**: Clean separation of concerns with ViewModels
- **SwiftUI**: Modern declarative UI framework with Swift 6 features
- **Async/Await**: Modern Swift concurrency with MainActor isolation
- **ATProtocol**: Native implementation of the ATProtocol/BlueSky API
- **Core Data**: Local persistence and caching layer
- **Firebase Integration**: Analytics and Crashlytics (Release builds only for faster debug compilation)
- **Keychain**: Secure credential storage
- **WebSocket**: Real-time firehose service for live updates
- **URLCache**: Optimized image prefetching and caching (100MB memory, 500MB disk)
- **Account Management**: Multi-account support with secure session handling

## Project Structure

```
Skyscraper/
├── Models/
│   ├── ATProtoModels.swift           # Data models for ATProtocol
│   ├── ChatModels.swift              # Direct messaging models
│   ├── Language.swift                # Language support
│   ├── PostDraft.swift               # Draft post persistence
│   ├── PostModerationSettings.swift  # Moderation preferences
│   └── StarterPackModels.swift       # Starter pack data structures
├── Services/
│   ├── ATProtoClient.swift           # Main API client for BlueSky
│   ├── ATProtoConstants.swift        # API constants
│   ├── AccountManager.swift          # Multi-account management
│   ├── AppTheme.swift                # Theme customization
│   ├── CoreDataStack.swift           # Core Data persistence
│   ├── FirehoseService.swift         # Real-time WebSocket updates
│   ├── ImagePrefetchService.swift    # Image prefetching & optimization
│   ├── KeychainManager.swift         # Secure credential storage
│   └── PostCacheService.swift        # Post caching layer
├── ViewModels/
│   ├── AuthViewModel.swift           # Authentication state
│   ├── TimelineViewModel.swift       # Timeline/feed management
│   ├── PostComposerViewModel.swift   # Post composition
│   ├── ChatListViewModel.swift       # DM list management
│   ├── ChatViewModel.swift           # Individual chat handling
│   ├── SearchViewModel.swift         # User search
│   └── DiscoverViewModel.swift       # Discovery feed
└── Views/
    ├── LoginView.swift               # Login screen
    ├── MainTabView.swift             # Main tab navigation
    ├── TimelineView.swift            # Timeline feed
    ├── PostComposerView.swift        # Post composer with drafts
    ├── ProfileView.swift             # User profiles
    ├── CurrentUserProfileView.swift  # Current user profile
    ├── PostDetailView.swift          # Thread/detail view
    ├── ChatListView.swift            # Direct messages list
    ├── ChatView.swift                # Chat interface
    ├── NewConversationView.swift     # Start new DM
    ├── NotificationsView.swift       # Notifications feed
    ├── SearchView.swift              # User search
    ├── DiscoverView.swift            # Discovery feed
    ├── FeedBrowserView.swift         # Custom feeds browser
    ├── HashtagSearchView.swift       # Hashtag search & results
    ├── StarterPackBrowserView.swift  # Starter packs browser
    ├── StarterPackDetailView.swift   # Starter pack details
    ├── SettingsView.swift            # App settings
    ├── PostModerationSettingsView.swift # Content moderation
    ├── DraftsListView.swift          # Saved drafts
    ├── FullScreenImageView.swift     # Image viewer
    ├── VideoPlayerView.swift         # Video player
    ├── ThemeColorPickerView.swift    # Theme customization
    └── DeveloperNotesView.swift      # Developer tools
```

## Getting Started

### Requirements
- **iOS 26.0+** / **macOS 26.0+** / **visionOS 26.0+**
- **Xcode 26.0+**
- **Swift 5.0+** with Swift 6 language features

### Setup

1. Clone the repository
2. Open `Skyscraper/Skyscraper.xcodeproj` in Xcode
3. Build and run on the iOS Simulator, macOS, visionOS Simulator, or physical device

**Note:** Firebase Analytics and Crashlytics are only enabled in Release builds to speed up debug compilation. Debug builds will run without Firebase integration.

### First Launch

1. Create an app password at https://bsky.app/settings/app-passwords
2. Launch Skyscraper
3. Sign in with your BlueSky handle and app password
4. Enjoy!

## ATProtocol Features Implemented

- **Authentication**: Session creation, management, and multi-account support
- **Feeds**: Timeline retrieval with pagination, custom feeds, and discovery
- **Posts**: Create posts, replies, quotes with rich text, links, and mentions
- **Interactions**: Like/unlike, repost/unrepost, reply, and quote posts
- **Profiles**: User profile viewing, editing, and following/unfollowing
- **Media**: Image upload/display with alt text, video playback support
- **Direct Messages**: Chat conversations and message management
- **Notifications**: Real-time notification feed
- **Search**: User search, hashtag search, and content discovery
- **Moderation**: Content filtering and moderation preferences
- **Firehose**: Real-time WebSocket connection for live updates
- **Starter Packs**: Browse and share starter pack collections

## Future Enhancements

Potential features for future versions:

- Enhanced threading and conversation views
- Advanced post filtering and muting options
- Bookmarks and saved posts
- Enhanced accessibility features (VoiceOver optimization, dynamic type, etc.)
- Widgets for iOS/macOS home screen
- Watch app companion
- Share extension for posting from other apps
- Enhanced analytics dashboard
- Collaborative filtering and recommendations
- Advanced media editing capabilities

## Contributing

This is a personal project, but feel free to fork and extend it!

## License

Created by Cameron Banga

---

Built with the ATProtocol and BlueSky API
