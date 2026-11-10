# Arise

A personal Android app that turns targets into daily quests and keeps you on
them. You set a target, the app breaks it into quests that fit your daily
capacity, tracks what you actually finish (a tick, or a focus timer that logs
real minutes), and reads phone usage to tell when you drift from the plan.
It speaks through "the System", a game-style interface with a terminal
flavour.

- XP, levels and ranks E to S, streaks, penalty quests at half XP, and XP
  loss for a blown distraction budget (never below the current level).
- Deviation detection: apps tagged distracting (built-in catalog, editable
  per app) against a daily budget, plus planned versus done minutes.
- A background check about every 15 minutes raises a heads-up notification
  with the full explanation, and optionally a pop-up over other apps.
- A Vault of games, movies, books and music; clearing a full day unlocks one.
- A chat screen with quick actions ("I have 30 min") answered from local
  decisions.

Every decision (what to do first, deviation, penalties) is computed on the
device. The language model only words the results and answers free-form
chat, so the app works fully offline with template replies.

## Gemini key (optional)

1. Open [Google AI Studio](https://aistudio.google.com/) and sign in.
2. Choose **Get API key**, then **Create API key**. The free tier is enough.
3. In Arise, open **STATUS > settings (top right) > SYSTEM LINK**, paste the
   key and tap **SAVE KEY**.

The key is stored with `flutter_secure_storage` (Android keystore) and never
leaves the device except in requests to Google. The default model is
`gemini-3.5-flash-lite`; change it in the same panel if Google renames or retires
it. Only short facts are sent (today's plan, pending quests, distraction
minutes, your question), replies are capped, and repeat questions are served
from a local cache. The chat footer shows tokens used today.

## Permissions

| Permission | Why |
|---|---|
| Usage access (`PACKAGE_USAGE_STATS`) | Per-app foreground time, for deviation detection and the day-end judgement. Granted by hand in system settings; the app links there. |
| Notifications (`POST_NOTIFICATIONS`) | Deviation alerts and the ongoing focus-timer notification. |
| Promoted notifications (`POST_PROMOTED_NOTIFICATIONS`) | Lets the focus timer appear as a Live Update chip on Android 16+. |
| Display over other apps (`SYSTEM_ALERT_WINDOW`) | Optional System pop-up when you deviate. Off until you enable it in Settings. |
| Ignore battery optimisations | Keeps the 15-minute background check on schedule. |
| Internet | Gemini requests, only when a key is set. |
| Vibrate | Alert vibration pattern. |

All data (quests, XP, usage rules, chat cache) stays in a local SQLite
database.

## Build and install

Requirements: Flutter 3.47 or newer, JDK 21, Android SDK with platform 37.
Android 10 (API 29) or newer on the phone.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release                  # one APK for all ABIs
flutter build apk --release --split-per-abi  # smaller, one per ABI
```

Install over USB or wireless debugging:

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
# or, for a split build on a modern phone:
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Release builds are signed with the debug key, which is fine for sideloading
on your own phone. After installing, open the app and grant Usage access and
notifications from **Settings > ALERTS**.

## Layout

| Path | Contents |
|---|---|
| `lib/core/game_config.dart` | Every tunable number (XP, levels, ranks, defaults) |
| `lib/domain/` | Pure logic: levelling, planner, picker, deviation, day rollover |
| `lib/data/store.dart` | SQLite persistence |
| `lib/system/` | Gemini client, System voice and templates, Android bridge, key storage |
| `lib/app/controller.dart` | App state and actions |
| `lib/ui/` | Screens and the System-window widgets |
| `android/app/src/main/kotlin/` | Usage stats, background watcher, alerts, overlay |
