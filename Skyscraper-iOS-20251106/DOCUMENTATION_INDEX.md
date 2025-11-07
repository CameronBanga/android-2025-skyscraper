# Skyscraper Documentation Index

This is the central index for all Skyscraper project documentation.

## Documentation Files

### 1. AGENT_GUIDE.md (13 KB)
**For**: AI Agents preparing to work on the codebase
**Start here if**: You're an AI agent tasked with understanding and extending Skyscraper

**Contains**:
- What the project does (core functionality)
- How to use other documentation files
- Key concepts (services, ViewModels, Views, data flow)
- Critical files to know (ATProtoClient, TimelineViewModel, ATProtoModels)
- Code patterns you'll see everywhere
- Common issues and solutions
- Development workflow for AI agents
- File organization reference

**Read this first**: ~5-10 minutes for overview, ~20-30 minutes for complete reading

---

### 2. CODEBASE_OVERVIEW.md (21 KB)
**For**: Deep architectural understanding
**Start here if**: You need to understand how the app is designed and why

**Contains**:
- Complete project structure (Models, Services, ViewModels, Views)
- Architectural patterns (MVVM, Services, Reactive)
- 14 major features explained (Auth, Timeline, Posts, Chat, etc.)
- Core service responsibilities with code examples
- Data model hierarchies and relationships
- Third-party dependencies
- Build configuration details
- Swift/SwiftUI patterns used throughout
- Implementation flows (session management, post loading, etc.)
- Architecture decisions and rationale
- Performance optimizations

**Section Map**:
1. Project Summary
2. Architectural Patterns - MVVM, Services, Reactive
3. Main Features - Auth, Timeline, Composition, Interactions, Profiles, Chat, Discovery, Settings
4. Core Services - ATProtoClient, KeychainService, AccountManager, CoreDataStack, PostCacheService, ImagePrefetchService, FirehoseService, AppTheme
5. Key Data Models - Post hierarchy, Profile, Chat, Facets
6. Dependencies - Frameworks and third-party libraries
7. Build Configuration - Targets, schemes, Firebase optimization
8. Swift/SwiftUI Patterns - Concurrency, State, Navigation, Codable, Cross-platform
9. Implementation Details - Session flow, post loading, images, multi-account
10. Architecture Decisions - Threading, Firebase, Core Data, Singletons, Services, Real-time, Graceful degradation
11. Performance Optimizations
12. Testing Structure
13. File Sizes
14. External Resources

**Read time**: ~30-45 minutes for thorough understanding

---

### 3. QUICK_REFERENCE.md (7.5 KB)
**For**: Fast lookup during development
**Start here if**: You're actively coding and need quick answers

**Contains**:
- Essential file paths organized by category
- Critical coding patterns (code examples)
- Key classes reference table
- Important data models
- Common task examples with code
- API endpoints
- Build and debug information
- Common modifications guide
- File sizes reference
- Threading and performance notes
- NotificationCenter events
- Testing the app

**Best for**:
- Finding a file location quickly
- Looking up a code pattern
- Understanding threading
- Checking API endpoints
- Troubleshooting common issues

**Read time**: ~2-5 minutes per lookup

---

### 4. FIREBASE_BUILD_OPTIMIZATION.md (3.2 KB)
**For**: Understanding the Firebase conditional compilation optimization
**Read if**: You're curious about why debug builds are 50% faster

**Contains**:
- How the optimization works (#if !DEBUG)
- Why it matters (build speed)
- What's different between Debug and Release
- How to test Firebase features locally
- Files that were modified for this optimization

**Read time**: ~3-5 minutes

---

### 5. README.md (3 KB)
**For**: User-facing project information
**Read if**: You want a high-level overview for non-technical people

**Contains**:
- Feature list
- Design highlights
- Architecture overview (brief)
- Project structure (condensed)
- Getting started instructions
- ATProtocol features

**Read time**: ~2-3 minutes

---

## Recommended Reading Paths

### Path 1: "I'm an AI agent. Where do I start?"
1. **AGENT_GUIDE.md** (10 min) - Overview and key concepts
2. **QUICK_REFERENCE.md** (5 min) - File paths and critical patterns
3. **CODEBASE_OVERVIEW.md** Sections 1-3 (15 min) - Structure and features
4. **CODEBASE_OVERVIEW.md** Section 4 (10 min) - Services overview
5. When doing actual coding: Refer back to QUICK_REFERENCE.md

**Total time**: 40 minutes for solid understanding

---

### Path 2: "I need to understand the architecture"
1. **CODEBASE_OVERVIEW.md** Section 2 (Patterns) - 10 min
2. **CODEBASE_OVERVIEW.md** Section 4 (Services) - 10 min
3. **CODEBASE_OVERVIEW.md** Section 8 (Swift Patterns) - 10 min
4. **CODEBASE_OVERVIEW.md** Section 9 (Implementation Details) - 10 min

**Total time**: 40 minutes

---

### Path 3: "I'm adding a new feature. What do I need to know?"
1. **AGENT_GUIDE.md** Section "Development Workflow for AI Agents"
2. **QUICK_REFERENCE.md** Section "Common Modifications"
3. Look at existing similar feature in code
4. **CODEBASE_OVERVIEW.md** Section 8 (Patterns)

**Total time**: 20 minutes + code review time

---

### Path 4: "I'm debugging an issue"
1. **QUICK_REFERENCE.md** - Find relevant file paths
2. **CODEBASE_OVERVIEW.md** Section 9 - Check implementation flows
3. **QUICK_REFERENCE.md** - Look up threading and performance
4. **AGENT_GUIDE.md** - Common issues and solutions

**Total time**: 10-20 minutes depending on issue

---

### Path 5: "I want to understand everything"
Read all files in order:
1. AGENT_GUIDE.md (10 min)
2. QUICK_REFERENCE.md (10 min)
3. CODEBASE_OVERVIEW.md (45 min)
4. FIREBASE_BUILD_OPTIMIZATION.md (5 min)
5. README.md (3 min)
6. Then explore the actual code

**Total time**: ~75 minutes + code exploration

---

## Quick Lookup Table

| Question | Document | Section |
|----------|----------|---------|
| What does this app do? | AGENT_GUIDE | "What This Project Does" |
| How is it structured? | CODEBASE_OVERVIEW | Section 1 |
| What architectural pattern? | CODEBASE_OVERVIEW | Section 2 |
| How do features work? | CODEBASE_OVERVIEW | Section 3 |
| What does [Service] do? | CODEBASE_OVERVIEW | Section 4 |
| What's this data model? | CODEBASE_OVERVIEW | Section 5 |
| What frameworks are used? | CODEBASE_OVERVIEW | Section 6 |
| Where's the build config? | CODEBASE_OVERVIEW | Section 7 |
| How do I write code like this? | CODEBASE_OVERVIEW | Section 8 |
| How does [feature] flow work? | CODEBASE_OVERVIEW | Section 9 |
| Why was [decision] made? | CODEBASE_OVERVIEW | Section 10 |
| What file should I modify? | QUICK_REFERENCE | "Essential File Paths" |
| How do I implement [pattern]? | QUICK_REFERENCE | "Critical Patterns" or "Common Tasks" |
| What API endpoints are available? | QUICK_REFERENCE | "API Endpoints Used" |
| How do I add a new feature? | AGENT_GUIDE | "Development Workflow" |
| Common issues and fixes? | AGENT_GUIDE | "Common Issues & Solutions" |

---

## Key File Locations

### Most Important Files
- `/Skyscraper/Services/ATProtoClient.swift` - API client (1,800 lines)
- `/Skyscraper/ViewModels/TimelineViewModel.swift` - Main feed (430 lines)
- `/Skyscraper/Models/ATProtoModels.swift` - Data models (900 lines)

### Service Layer
- `/Skyscraper/Services/` - All business logic lives here (10 files)

### UI Layer
- `/Skyscraper/Views/` - All SwiftUI views (31 files)

### State Management
- `/Skyscraper/ViewModels/` - MVVM ViewModels (7 files)

### Data
- `/Skyscraper/Models/` - Data structures (6 files)

---

## Documentation Maintenance

**Last Updated**: 2025-11-03
**Version**: 0.7
**Status**: Complete and current

These documents were generated by thorough exploration of the Skyscraper codebase including:
- 58 Swift source files
- Project configuration and build settings
- Service architecture and patterns
- ViewModel implementation patterns
- UI/View structure
- Data model hierarchies
- Third-party dependencies
- Testing structure

---

## Navigation Tips

- Use Cmd+F (Ctrl+F on Linux) to search within documents
- Markdown headers allow jumping to sections
- Code examples are formatted with syntax highlighting
- Tables are used for reference information
- Emoji markers (like 🔥, ✅, ❌) make scanning easier

---

## Contributing to Documentation

If you update the codebase:
1. Update relevant documentation sections
2. Keep QUICK_REFERENCE.md current with file paths
3. Add code examples to CODEBASE_OVERVIEW.md if adding patterns
4. Update AGENT_GUIDE.md if adding development processes

---

**End of Documentation Index**

For AI Agents: Start with AGENT_GUIDE.md, then QUICK_REFERENCE.md, then CODEBASE_OVERVIEW.md as needed.
