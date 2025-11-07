# Push Notification Integration Notes

## High-Level Architecture

Skyscraper can use Apple Push Notification service (APNs) on device, while Bluesky’s `app.bsky.notification.registerPush` API tells Bluesky where to send events. A tiny push gateway (your backend) sits between Bluesky and APNs:

```
Bluesky events ──▶ your push gateway ──▶ APNs ──▶ iOS device
```

## iOS App Steps

1. **Enable capabilities**
   - In Xcode: turn on *Push Notifications* and *Background Modes → Remote notifications*.
   - In the Apple Developer portal: create/download the APNs `.p8` key your gateway will use.

2. **Request authorization & register with APNs**
   ```swift
   @main
   struct SkyscraperApp: App {
       @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
       …
   }

   final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
       func application(_ application: UIApplication,
                        didFinishLaunchingWithOptions launchOptions: …) -> Bool {
           UNUserNotificationCenter.current().delegate = self
           requestNotificationPermissions()
           return true
       }

       private func requestNotificationPermissions() {
           UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
               guard granted else { return }
               DispatchQueue.main.async {
                   UIApplication.shared.registerForRemoteNotifications()
               }
           }
       }
   }
   ```

3. **Capture the APNs token**
   ```swift
   func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
       let token = deviceToken.map { String(format: "%02x", $0) }.joined()
       PushManager.shared.register(token: token)
   }
   ```

4. **Register with Bluesky**
   ```swift
   final class PushManager {
       static let shared = PushManager()
       private init() { }

       func register(token: String) {
           Task {
               guard ATProtoClient.shared.session != nil else { return }
               let request = AppBskyNotificationRegisterPushRequest(
                   serviceDid: AppConfig.pushServiceDid,
                   token: token,
                   platform: "ios",
                   appPushSettings: .init(
                       mentions: true,
                       replies: true,
                       reposts: true,
                       likes: true
                   ),
                   locale: Locale.current.identifier
               )
               try await ATProtoClient.shared.registerPush(request: request)
           }
       }
   }
   ```

   - Endpoint: `POST https://bsky.social/xrpc/app.bsky.notification.registerPush`
   - Docs: <https://docs.bsky.app/docs/api/app-bsky-notification-register-push>
   - Sample payload:
     ```json
     {
       "serviceDid": "did:web:push.example.com",
       "token": "deadbeef…",
       "platform": "ios",
       "appPushSettings": {
         "$type": "app.bsky.notification.registerPush#appPushSettings",
         "notifyMentions": true,
         "notifyReplies": true,
         "notifyReposts": true,
         "notifyLikes": true
       },
       "locale": "en_US"
     }
     ```

5. **Handle notification taps**
   - Implement `userNotificationCenter(_:didReceive:)` to deep-link into post/detail.
   - When the user views notifications, call `app.bsky.notification.updateSeen` (<https://docs.bsky.app/docs/api/app-bsky-notification-update-seen>).

6. **Badges / unread counts**
   - Periodically call `app.bsky.notification.getUnreadCount` (<https://docs.bsky.app/docs/api/app-bsky-notification-get-unread-count>) to update the badge.

7. **Re-register when needed**
   - After login/account switch.
   - Whenever APNs hands us a new token.
   - After the user changes push preferences.

## Push Gateway (Backend)

Bluesky does not talk directly to APNs. Provide a service DID that resolves to your push gateway.

1. Issue a DID (e.g. `did:web:push.example.com`) whose document lists your HTTPS endpoint.
2. Implement the handler Bluesky posts to (e.g. `POST https://push.example.com/xrpc/app.bsky.notification.receive`).
3. Translate the Bluesky payload into an APNs request:
   - URL: `https://api.push.apple.com/3/device/<token>`
   - Headers: `apns-topic = <bundle id>`, `apns-push-type = alert`, `authorization = bearer <APNs JWT>`.
   - Body: APNs JSON with alert/badge/sound fields.
4. Use the same `.p8` key configured in step 1.

References:
- APNs docs: <https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns>

## Notification Preferences UI

Expose toggles so users can control which events trigger pushes.

1. **Fetch/update prefs**
   - Get unread/prefs:  
     - `GET https://bsky.social/xrpc/app.bsky.notification.listNotifications`  
     - `GET https://bsky.social/xrpc/app.bsky.notification.getUnreadCount`
   - Put preferences:  
     - `POST https://bsky.social/xrpc/app.bsky.notification.putPreferences`  
       Docs: <https://docs.bsky.app/docs/api/app-bsky-notification-put-preferences>

2. **SwiftUI screen**
   ```swift
   struct NotificationSettingsView: View {
       @StateObject private var viewModel = NotificationPreferencesViewModel()

       var body: some View {
           Form {
               Section("Push Notifications") {
                   Toggle("Mentions", isOn: $viewModel.settings.mentions)
                   Toggle("Replies", isOn: $viewModel.settings.replies)
                   Toggle("Reposts", isOn: $viewModel.settings.reposts)
                   Toggle("Likes", isOn: $viewModel.settings.likes)
               }
           }
           .navigationTitle("Notifications")
           .task { await viewModel.load() }
       }
   }
   ```

   The view model should:
   - Load current prefs on `.task`.
   - Debounce writes to `app.bsky.notification.putPreferences` when toggles change.
   - Call `PushManager.register(token:)` after saving so Bluesky has the latest `appPushSettings`.

3. Add this screen to the main Settings list under a “Notifications” row.

## Housekeeping

- On logout, consider unregistering by calling the register endpoint with an empty token (or your gateway can drop the token).
- Handle `UNUserNotificationCenter` delegate methods to show in-app banners if desired.
- Ensure the push gateway rejects unknown tokens (users who log out) to prevent stale notifications.
