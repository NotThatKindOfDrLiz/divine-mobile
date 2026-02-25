# Push Notification Integration Task

## Goal
Add Firebase Cloud Messaging (FCM) push notifications to divine-mobile. The server-side push service already exists at `divine-push-service` and uses a NIP-XX protocol for token registration.

## Architecture

### How it works:
1. App gets FCM token from Firebase Messaging
2. App sends a NIP-44 encrypted Nostr event (kind 3079) to relay.divine.video containing the FCM token
3. The push service monitors the relay, decrypts tokens, stores them in Redis
4. When relevant events happen (likes, replies, follows, mentions, reposts), push service sends FCM notification
5. App receives push and shows notification

### NIP-XX Protocol (kinds 3079/3080/3083):

**Registration (kind 3079):**
```json
{
  "kind": 3079,
  "pubkey": "<user-pubkey>",
  "tags": [
    ["p", "<push-service-pubkey>"],
    ["app", "divine"],
    ["expiration", "<unix-seconds-90-days-from-now>"]
  ],
  "content": nip44_encrypt({"token": "<fcm-token>"}),
  "sig": "<signature>"
}
```

**Deregistration (kind 3080):** Same structure as 3079.

**Preferences (kind 3083):** Update which event kinds trigger notifications.

## What needs to be done:

### 1. Add firebase_messaging dependency
- Add `firebase_messaging: ^15.x` to `mobile/pubspec.yaml`
- The project already has `firebase_core`, `firebase_crashlytics`, `firebase_analytics`

### 2. Create PushNotificationService
Location: `mobile/lib/services/push_notification_service.dart`

- Initialize Firebase Messaging
- Request notification permissions (iOS/Android)
- Get FCM token
- Listen for token refresh
- Handle foreground/background/terminated notification taps
- Create kind 3079 registration events with NIP-44 encryption
- Send registration event to relay.divine.video
- Send deregistration (kind 3080) on logout
- Refresh registration before expiration (auto-refresh at 60 days)

### 3. Create Riverpod Provider
Location: `mobile/lib/providers/push_notification_provider.dart`

- Wrap the service in a Riverpod provider
- Auto-initialize after login
- Re-register on token refresh
- Expose push permission status

### 4. Integrate with existing code
- Initialize in app startup (after Firebase.initializeApp)
- Register after user login/authentication
- Deregister on logout
- Connect notification taps to navigation (open relevant screen)
- Use the existing notification_settings_screen.dart preferences

### 5. Handle notification display
- Use existing flutter_local_notifications for foreground notifications
- Configure notification channels for Android
- Handle notification tap → navigate to relevant content

## Key details:
- Bundle ID: `co.openvine.app`
- App ID for NIP-XX: `divine`
- Relay: `wss://relay.divine.video`
- The push service pubkey will be configurable (environment-based)
- Use existing NIP-44 encryption from the codebase (check for existing nostr crypto utilities)
- Use existing Nostr client/relay connection code

## Existing code to reference:
- `mobile/lib/services/nip98_auth_service.dart` - NIP-98 auth (similar pattern for NIP-44)
- `mobile/lib/services/notification_service.dart` - Existing local notifications
- `mobile/lib/providers/relay_notifications_provider.dart` - Existing notification provider
- `mobile/lib/providers/nostr_client_provider.dart` - Nostr client access
- `mobile/lib/screens/notification_settings_screen.dart` - Settings UI

## Constraints:
- Follow existing code patterns (Riverpod, service classes)
- Add ABOUTME comments to new files (existing convention)
- Run `dart format` on all changed files
- Run `dart analyze` - zero warnings
- Don't break existing tests
