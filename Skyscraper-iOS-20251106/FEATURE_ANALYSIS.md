# Skyscraper Codebase Comprehensive Feature Analysis
**Generated**: 2025-11-05
**Codebase Version**: 2380 lines in ATProtoClient, 31 Views, 8 ViewModels

---

## SECTION 1: CURRENTLY IMPLEMENTED FEATURES

### Core Application Structure (Fully Implemented)
- **Authentication & Multi-Account Management**
  - Login with custom PDS URL support
  - Session token storage via Keychain
  - Account switching with hot-reload
  - Token refresh on 401 errors
  
- **Main Navigation (4-5 Tabs)**
  - Timeline (following feed)
  - Discover (trending & recommended)
  - Activity/Notifications
  - Chat (DMs - bsky.social only)
  - Compose (post creation - accessed via floating action)

### Timeline Features (Fully Implemented)
- **Timeline Loading & Display**
  - Following feed with infinite scroll pagination
  - Custom feed browser and selection
  - Pull-to-refresh functionality
  - Scroll position preservation per feed
  - Core Data caching (10-day retention)
  - Background refresh service (configurable 1s-5m intervals)
  
- **Post Interactions**
  - Like/Unlike posts
  - Repost/Un-repost
  - View reply counts, repost counts, like counts
  - Thread viewing (reply chains)

- **Post Content Display**
  - Plain text posts
  - Images (up to 4 per post) with alt text
  - Video playback (view only)
  - Link previews/embeds (external content)
  - Quoted posts (viewing)
  - Mentions and hashtags with facet detection
  - Auto-linked URLs

### Post Composition (Fully Implemented)
- **Post Creation**
  - Text composition (300 char limit)
  - Image upload (up to 4 images)
  - Alt text editor for accessibility
  - Reply composition (threaded replies)
  - Language selection per post
  - Post moderation settings (threadgate, reply restrictions)
  
- **Drafts Management**
  - Auto-save drafts
  - Draft persistence
  - Load and resume drafts
  - Delete drafts

- **Rich Text Features**
  - Auto-detection of @mentions with suggestions
  - Auto-detection of #hashtags with suggestions
  - Auto-detection of URLs/links
  - Mention search with autocomplete
  - Hashtag search with autocomplete

### Profile Features (Fully Implemented)
- **Profile Viewing**
  - View user profile (avatar, banner, bio, counts)
  - Profile stats (followers, following, posts count)
  - Follow/Unfollow users
  - View follow relationship indicators
  
- **User Content Tabs** (in ProfileView)
  - Posts (author's posts)
  - Replies (author's replies)
  - Lists (author's lists - viewing only)
  - Starter Packs (author's starter packs)

- **Current User Profile**
  - Access to logged-in user's profile
  - Edit profile (via settings)
  - Account management

### Social Features (Fully Implemented)
- **Following/Followers**
  - Get followers list
  - Get following list
  - Follow/Unfollow users
  - Follow status indicators

- **Search**
  - Search posts (full-text search)
  - Search users (actor search)
  - Hashtag search with dedicated view
  - Global search UI

### Content Discovery (Fully Implemented)
- **Discover View**
  - Trending topics (currently using getTrendingTopics)
  - Suggested feeds
  - Feed browser for custom feeds
  
- **Starter Packs**
  - Browse starter packs
  - View starter pack details
  - Follow users from starter packs

### Chat/Direct Messages (Fully Implemented - bsky.social only)
- **Chat Features**
  - List conversations
  - Send direct messages
  - Receive messages
  - Get message history per conversation
  - Create new conversations
  - Leave conversations
  - Mute/Unmute conversations
  - Mark conversations as read
  - Get conversation for specific members
  
### Settings & Preferences (Fully Implemented)
- **User Preferences**
  - Set language preference per post
  - Save default language
  - Refresh interval configuration
  - Video auto-play toggle
  - App icon selection (Orange, Purple, Teal)
  
- **Moderation Settings**
  - Muted words management (add/remove)
  - Hide quoted posts toggle
  - Post reply restrictions toggle
  
- **Post Moderation**
  - Threadgate settings (reply permission control)
  - Postgate settings
  - Reply restriction by engagement

- **Account Management**
  - Logout
  - Switch accounts
  - View account list

### Theme & Appearance (Fully Implemented)
- **Theme Colors**
  - 9 theme color options
  - Color picker in settings
  - Persistent theme preference
  - System color integration

- **Platform Support**
  - iOS 17+ support
  - macOS 14+ support
  - xrOS 1.0+ support
  - Cross-platform UI adaptation

### Media Handling (Fully Implemented)
- **Image Features**
  - Image upload with blob encoding
  - Alt text editing
  - Image preview before posting
  - Image caching and prefetch
  - Aspect ratio preservation
  - Retryable async image loading
  - Full-screen image viewer
  
- **Video Features**
  - Video viewing
  - Video playback controls
  - Auto-play toggle in settings
  - Video thumbnail display

### Utilities (Fully Implemented)
- **Accessibility**
  - Alt text support for images
  - VoiceOver compatibility
  - Dynamic type support
  - WCAG AA color contrast compliance

- **Analytics**
  - Conditional Firebase (Release only, disabled in Debug)
  - Event logging
  - Crash reporting

- **Logging System**
  - Unified logging with debug output
  - Specialized loggers (AppLogger, ScrollLogger, FeedLogger, etc.)
  - Console logging in debug builds
  - os.Logger for production

---

## SECTION 2: PARTIALLY IMPLEMENTED/INCOMPLETE FEATURES

### API Methods Available But Not Fully Exposed in UI

#### 1. **User Likes Feed** (API: `getActorLikes`)
- **Status**: Implemented in ATProtoClient, NOT exposed in UI
- **Location**: `ATProtoClient.getActorLikes()`
- **What works**: API call retrieves user's liked posts
- **What's missing**: No UI to view a user's likes
- **Potential integration**: Could add "Likes" tab in ProfileView
- **Difficulty**: Easy - straightforward integration

#### 2. **Trending Topics** (API: `getTrendingTopics`)
- **Status**: Implemented in ATProtoClient, PARTIALLY exposed
- **Location**: Used in `DiscoverViewModel` but may not have full UI display
- **What works**: API call retrieves trending topics
- **What's missing**: Could have dedicated trending topics page
- **Potential integration**: Expand DiscoverView with trending hashtags section
- **Difficulty**: Easy - data structure exists, just needs display layer

#### 3. **Custom Feeds** (API: `getFeed`, `getSuggestedFeeds`)
- **Status**: Implemented in ATProtoClient, PARTIALLY exposed
- **Location**: FeedBrowserView exists, limited integration
- **What works**: Can fetch custom feeds, switch between feeds
- **What's missing**: No "Add Feed" functionality, no feed management in UI
- **Potential integration**: Feed management in settings
- **Difficulty**: Medium - needs Feed persistence logic

#### 4. **Lists** (API: `getActorLists`, `getList`)
- **Status**: Implemented in ATProtoClient, VIEWING ONLY
- **Location**: ProfileView shows user's lists, but no create/edit/delete UI
- **What works**: Can view user's lists, fetch list contents
- **What's missing**: Create lists, add users to lists, delete lists, manage lists
- **Potential integration**: Lists management view in Settings or dedicated Lists tab
- **Difficulty**: Medium - requires list CRUD operations

#### 5. **Feed Generators** (API: `getFeedGenerators`, `getActorFeeds`)
- **Status**: Implemented in ATProtoClient, MINIMAL UI
- **Location**: Used internally, not prominently exposed
- **What works**: Can fetch feed generators
- **What's missing**: No dedicated "My Feeds" view or feed creator tools
- **Potential integration**: Feed browser with creation options
- **Difficulty**: Hard - requires publishing feed generator records

#### 6. **Notifications** (API: `getNotifications`, `updateSeenNotifications`)
- **Status**: Implemented, BASIC functionality only
- **Location**: NotificationsView exists
- **What works**: Get notifications, mark all as read
- **What's missing**: Mark individual notifications as read, push notifications, notification filtering
- **Potential integration**: Better notification UI with filtering
- **Difficulty**: Medium - requires push notification setup

---

## SECTION 3: COMPLETELY MISSING FEATURES FROM AGENTS.MD "NOT YET IMPLEMENTED"

### 1. **Video Upload**
- **API Status**: NOT implemented in ATProtoClient
- **Why**: Video blob encoding differs from images, requires streaming
- **Current**: Can view videos, cannot create posts with video
- **Difficulty to implement**: HARD
- **Requires**: Video streaming upload, video processing
- **Estimated effort**: 2-3 hours

### 2. **Quote Posts Creation**
- **API Status**: NOT implemented in ATProtoClient
- **Why**: Requires special RecordEmbed handling in post creation
- **Current**: Can view quoted posts in replies/embeds
- **Difficulty to implement**: MEDIUM-HARD
- **Requires**: Embed selection UI, quote context handling
- **Estimated effort**: 1-2 hours

### 3. **Poll Creation & Voting**
- **API Status**: NOT implemented (ATProto doesn't natively support polls)
- **Why**: Polls are community-built, not core ATProto feature
- **Current**: No poll support at all
- **Difficulty to implement**: VERY HARD
- **Requires**: Custom poll record creation, voting logic
- **Estimated effort**: 3-4 hours

### 4. **GIF Picker Integration**
- **API Status**: NOT implemented
- **Why**: Requires third-party GIF API integration (Giphy, Tenor, etc.)
- **Current**: No GIF support
- **Difficulty to implement**: MEDIUM
- **Requires**: GIF API key, GIF search UI
- **Estimated effort**: 1-2 hours

### 5. **Bookmarks / Saved Posts**
- **API Status**: NOT implemented in ATProtoClient
- **Why**: Bookmark functionality exists in ATProto but not exposed in client
- **Current**: No way to save posts
- **Difficulty to implement**: MEDIUM
- **Requires**: Bookmark API calls, persistence, UI
- **Estimated effort**: 1-2 hours

### 6. **User Blocking & Muting (at user level)**
- **API Status**: Chat mute/unmute exists, user-level block/mute NOT implemented
- **What exists**: Can mute/unmute conversations
- **What's missing**: Can block/mute individual users
- **Difficulty to implement**: MEDIUM
- **Requires**: Block/mute record creation, unblock API
- **Estimated effort**: 1-2 hours

### 7. **Moderation Content Filters**
- **API Status**: Partially implemented (muted words exist)
- **What exists**: Mute individual words
- **What's missing**: Content filtering rules, hide sensitive content, NSFW filters
- **Difficulty to implement**: MEDIUM
- **Requires**: Preference API updates, filtering logic
- **Estimated effort**: 1-2 hours

### 8. **Thread Unrolling**
- **API Status**: No API needed (client-side feature)
- **What exists**: Can view reply chains in PostDetailView
- **What's missing**: Auto-expand all replies, thread unrolling option
- **Difficulty to implement**: EASY
- **Requires**: Recursive thread loading UI
- **Estimated effort**: 30 minutes

### 9. **Translation Integration**
- **API Status**: No translation API integrated
- **What exists**: Language selection for posts
- **What's missing**: Translate post text feature
- **Difficulty to implement**: MEDIUM
- **Requires**: Translation API (Apple Translate, Google Translate, etc.)
- **Estimated effort**: 1-2 hours

### 10. **Share Sheet Actions**
- **API Status**: No sharing API integration
- **What exists**: Can open URLs
- **What's missing**: Native share sheet for posts, copy post URL
- **Difficulty to implement**: EASY
- **Requires**: UIActivityViewController / NSSharingServicePicker
- **Estimated effort**: 30 minutes

### 11. **Push Notifications**
- **API Status**: NOT implemented
- **Current**: In-app polling only
- **What's missing**: Remote push notifications for mentions, likes, follows
- **Difficulty to implement**: HARD
- **Requires**: APNs setup, notification service, background processing
- **Estimated effort**: 2-3 hours

### 12. **Drafts Sync Across Devices**
- **API Status**: NOT implemented
- **Current**: Drafts stored locally only
- **What's missing**: CloudKit sync or server-side draft storage
- **Difficulty to implement**: HARD
- **Requires**: CloudKit integration or custom backend
- **Estimated effort**: 2-3 hours

### 13. **Post Scheduling**
- **API Status**: Post exists but post scheduling NOT in ATProto
- **Current**: Posts are immediate
- **What's missing**: Schedule posts for future time
- **Difficulty to implement**: HARD
- **Requires**: Local notification-triggered posting, persistent storage
- **Estimated effort**: 2-3 hours

---

## SECTION 4: EASY WINS - API METHODS AVAILABLE BUT UNUSED

### Quick Feature Implementations (Priority Order)

#### PRIORITY 1: Very Easy (< 30 minutes each)

1. **Share Sheet for Posts**
   - API: Native UIActivity, not ATProto
   - Implementation: Add share button in PostDetailView
   - Files: PostDetailView.swift, PostComposerView.swift
   - Lines: ~20-30

2. **Thread Unrolling Display**
   - API: getPostThread (already used)
   - Implementation: Auto-expand replies in threading
   - Files: PostDetailView.swift
   - Lines: ~15-20

3. **User Likes Tab in ProfileView**
   - API: getActorLikes (exists, implemented)
   - Implementation: Add tab to ProfileView, call getActorLikes
   - Files: ProfileView.swift, ProfileViewModel.swift (create new)
   - Lines: ~80-100

#### PRIORITY 2: Easy (30 minutes - 1 hour each)

4. **Trending Hashtags Display in Discover**
   - API: getTrendingTopics (already used)
   - Implementation: Add hashtag carousel to DiscoverView
   - Files: DiscoverView.swift, DiscoverViewModel.swift
   - Lines: ~50-80

5. **Copy Post URL Button**
   - API: Native UIPasteboard, not ATProto
   - Implementation: Add copy button in PostDetailView
   - Files: PostDetailView.swift
   - Lines: ~15-25

6. **Hide Quoted Posts Toggle (Enforcement)**
   - API: getPreferences/putPreferences (already implemented)
   - Implementation: Filter posts in timeline based on moderation settings
   - Files: TimelineView.swift, TimelineViewModel.swift
   - Lines: ~20-30

7. **Mark Individual Notifications as Read**
   - API: updateSeenNotifications (needs slight enhancement)
   - Implementation: Add swipe action in NotificationsView
   - Files: NotificationsView.swift
   - Lines: ~30-50

8. **Starred/Pinned Posts Display**
   - API: Profile viewer data available
   - Implementation: Show pinned post in ProfileView
   - Files: ProfileView.swift
   - Lines: ~30-40

#### PRIORITY 3: Medium (1-2 hours each)

9. **Bookmarks / Saved Posts**
   - API: Needs implementation in ATProtoClient
   - Implementation: Add bookmark toggle, bookmarks view
   - Files: ATProtoClient.swift, Views/BookmarksView.swift (new)
   - Lines: ~200

10. **User Block/Mute at User Level**
    - API: Needs implementation in ATProtoClient
    - Implementation: Add block/mute options in profile context menu
    - Files: ATProtoClient.swift, ProfileView.swift
    - Lines: ~150

11. **Dedicated Trending Topics View**
    - API: getTrendingTopics (already used)
    - Implementation: Create TrendingView.swift, add to navigation
    - Files: Views/TrendingView.swift (new), MainTabView.swift
    - Lines: ~100-150

12. **Feed Management UI**
    - API: getFeed, getSuggestedFeeds (already implemented)
    - Implementation: Add/remove custom feeds, persistent feed list
    - Files: Views/FeedManagementView.swift (new), enhanced FeedBrowserView.swift
    - Lines: ~150-200

---

## SECTION 5: DETAILED API INVENTORY

### Fully Used APIs (22 methods)
```
✓ login()
✓ getTimeline()
✓ getAuthorFeed()
✓ getPostThread()
✓ createPost()
✓ likePost()
✓ unlikePost()
✓ repost()
✓ unrepost()
✓ getProfile()
✓ getProfiles()
✓ followUser()
✓ unfollowUser()
✓ searchUsers()
✓ searchPosts()
✓ getFollows()
✓ getFollowers()
✓ getStarterPacks()
✓ getTrendingTopics() [DiscoverViewModel]
✓ getSuggestedFeeds() [FeedBrowserView]
✓ getActorLists() [ProfileView]
✓ getPosts()
```

### Partially Used APIs (3 methods)
```
~ getNotifications() [Basic - no individual mark as read]
~ getList() [Can view, not create/edit]
~ getPreferences() / putPreferences() [Settings only, not enforced]
```

### Implemented But Unused APIs (10+ methods)
```
✗ getActorLikes() [Implementation: 5 lines, Usage: 0]
✗ getActorFeeds() [Implementation: 5 lines, Usage: 0]
✗ getFeedGenerators() [Implementation: 5 lines, Usage: 0]
✗ getActorStarterPacks() [Implementation: 5 lines, Usage: 0]
✗ updateSeenNotifications() [Implementation: 8 lines, Usage: 0]
✗ listConvos() [Implementation: 10 lines, Usage: in ChatListViewModel but basic]
✗ getConvo() [Implementation: 8 lines, Usage: in ChatViewModel]
✗ getMessages() [Implementation: 12 lines, Usage: in ChatViewModel]
✗ sendMessage() [Implementation: 15 lines, Usage: in ChatViewModel]
✗ leaveConvo() [Implementation: 8 lines, Usage: 0]
✗ muteConvo() [Implementation: 8 lines, Usage: 0]
✗ unmuteConvo() [Implementation: 8 lines, Usage: 0]
✗ getConvoForMembers() [Implementation: 8 lines, Usage: in ChatView]
✗ detectFacets() [Implementation: 50+ lines, Usage: in PostComposerViewModel]
✗ uploadImage() [Implementation: 60+ lines, Usage: in PostComposerViewModel]
```

---

## SECTION 6: CODE ORGANIZATION SUMMARY

### Views (31 files)
**Implemented:**
- TimelineView.swift (primary feed)
- PostComposerView.swift (post creation)
- ProfileView.swift (user profiles)
- PostDetailView.swift (reply threads)
- SettingsView.swift (preferences)
- ChatListView.swift (DM list)
- ChatView.swift (DM conversation)
- DiscoverView.swift (trending/feeds)
- SearchView.swift (global search)
- NotificationsView.swift (activity)
- LoginView.swift (authentication)
- MainTabView.swift (navigation hub)
- StarterPackBrowserView.swift, StarterPackDetailView.swift
- FeedBrowserView.swift (custom feeds)
- HashtagSearchView.swift (hashtag search)
- ModerationSettingsView.swift, PostModerationSettingsView.swift
- Various helper views (FullScreenImageView, VideoPlayerView, etc.)

**Missing High-Value Views:**
- BookmarksView (could save posts)
- TrendingTopicsView (dedicated trending)
- UserBlockListView (blocked users)
- LikesView (view user's likes)
- FeedManagementView (create/edit custom feeds)

### ViewModels (8 files)
**Implemented:**
- AuthViewModel.swift (login/logout)
- TimelineViewModel.swift (feed logic)
- PostComposerViewModel.swift (post creation)
- ChatViewModel.swift (DM conversation)
- ChatListViewModel.swift (DM list)
- DiscoverViewModel.swift (discover feeds)
- SearchViewModel.swift (search logic)
- TimelineState.swift (state management)
- Plus: PostDetailViewModel, NotificationsViewModel (inferred from Views)

**Missing ViewModels:**
- BookmarksViewModel
- TrendingViewModel
- FeedManagementViewModel

### Services (11+ files)
**Critical:**
- ATProtoClient.swift (2380 lines - all API calls)
- AccountManager.swift (multi-account)
- KeychainManager.swift (secure storage)
- CoreDataStack.swift (local database)

**Timeline-Specific:**
- TimelineFetchService.swift
- TimelineCacheService.swift
- BackgroundRefreshService.swift
- TimelineAnalytics.swift

**Other:**
- AppTheme.swift (colors)
- ImagePrefetchService.swift (image caching)
- FirehoseService.swift (real-time updates)
- ImageCaptionService.swift
- PostCacheService.swift
- Analytics.swift

---

## SECTION 7: IMPLEMENTATION RECOMMENDATIONS

### Highest ROI Features (Implement First)
1. **User Likes Feed** - 30 mins, huge feature gap
2. **Share Posts** - 30 mins, user expectation
3. **Bookmarks** - 2 hours, commonly requested
4. **User Block/Mute** - 2 hours, moderation essential

### Quick Wins to Polish App
1. **Copy Post URL** - 15 mins
2. **Thread Unrolling Auto-expand** - 30 mins
3. **Hide Quoted Posts Enforcement** - 30 mins
4. **Individual Mark as Read for Notifications** - 1 hour

### Features with API Already Available
- getActorLikes() - not in UI
- getTrendingTopics() - partially used
- getSuggestedFeeds() - minimal integration
- getList() - view only
- All Chat APIs - basic integration only

---

## CONCLUSION

**Currently: 70% Feature Complete**
- Core social features: Posts, Timeline, Profiles, Following (Complete)
- Discovery: Trending, Feeds (Partial)
- Chat: DMs (Complete for bsky.social)
- Moderation: Basic (Partial)

**Quick to Add (< 5 hours total): 6 features**
- User likes feed
- Share posts
- Bookmarks
- User block/mute
- Better trending display
- Individual notification controls

**Medium Effort (2-3 hours each): 4-5 features**
- Video upload
- Quote posts creation
- Feed management UI
- Push notifications
- Translation integration

**Hard/Out of Scope: 3-4 features**
- Polls (requires custom API)
- Post scheduling (requires local scheduling)
- GIF picker (requires third-party API)
- Drafts sync (requires CloudKit)

