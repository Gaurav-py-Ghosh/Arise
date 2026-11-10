# Arise: build plan and handoff

Arise is a personal Android app (Flutter + a small Kotlin layer). The user sets
targets, the app breaks them into daily quests, tracks real completion, reads
phone usage to detect deviation from the plan, and speaks through a "System"
voice backed by a free-tier Gemini model. Look and feel: an original
"System window" game interface with a developer/terminal flavour. Do not copy
art, names or text from any existing series.

Repo: `git@github.com:Gaurav-py-Ghosh/Arise.git` (SSH remote, branch `main`).
Project root: `/home/zelvis/Projects/Arise`.

## Decisions already made by the user (do not reopen)

- Flutter, Android only, minSdk 29. Local SQLite now; Supabase sync later.
- LLM: Gemini free tier, key pasted in Settings, stored with
  `flutter_secure_storage`, never committed. Default model
  `gemini-3.8-flash`, editable. Token use must stay minimal.
- All decisions (what to do first, deviation, penalties) are computed in Dart.
  The LLM only words results and answers free-form chat.
- Deviation = apps tagged distracting + a daily budget, plus planned-versus-
  actual minutes. Default tags come from a built-in catalog; user can edit.
- Background check about every 15 min (WorkManager, native, no Flutter engine).
  Alert = heads-up notification with full explanation; opt-in overlay pop-up.
- Completion = tick, plus optional focus timer recording real minutes.
- Gamification: XP, levels, ranks E to S, streaks, penalty quests at half XP,
  XP loss for a blown budget (never drops a level). Amounts in
  `lib/core/game_config.dart`.
- Vault (games, movies, books, music) doubles as rewards for a cleared day.
- Chat screen with quick-action chips.
- Commit in small steps, only when `flutter analyze` is clean and
  `flutter test` passes, and push to `main` after each commit. No attribution
  trailers in commit messages. Conventional-commit style subjects.

## What exists and is tested (61 tests passing, pushed)

| Path | Contents |
|---|---|
| `lib/core/game_config.dart` | every tunable number |
| `lib/domain/models.dart` | `Target`, `Quest`, `FunItem`, `AppUsage`, `Player`, day-key helpers (`dayKey`, `addDays`, `fmtDay`, `fmtMin`) |
| `lib/domain/leveling.dart` | `levelFor`, `rankFor`, `questXp`, `applyXpLoss` |
| `lib/domain/planner.dart` | `templatePlan`, `parsePlanSteps`, `schedulePlan` |
| `lib/domain/picker.dart` | `pickNext(quests, minutesLeft, today)` |
| `lib/domain/app_catalog.dart` | default app categories, `isDistracting` |
| `lib/domain/deviation.dart` | `evaluateDeviation` -> `DeviationReport` |
| `lib/domain/rollover.dart` | `computeRollover` (day-end judgement) |
| `lib/data/store.dart` | sqflite `Store` (targets, quests, fun, app rules, kv, llm cache) |
| `lib/system/llm.dart` | `Llm` interface, `GeminiLlm` |
| `lib/system/voice.dart` | persona, compact context, `parseMinutes`, offline templates |
| `lib/system/bridge.dart` | `SystemBridge` interface + `AndroidBridge` (MethodChannel `arise/system`) |
| `lib/app/controller.dart` | `AppController extends ChangeNotifier`: all app state and actions |
| `test/**` | unit tests; `test/support/fakes.dart` has `memoryStore`, `FakeBridge`, `FakeLlm` |

Read `lib/app/controller.dart` first. The UI must only call its public
members: `ready, player, level, settings, todayQuests, upcoming, targets,
targetProgress, fun, usage, rules, usageAccess, report, tokensToday,
focusQuestId, focusStartedMs, chat, thinking, events, takeEvent()` and
`init, refresh, suggestPlan, createTarget, deleteTarget, addQuest, moveQuest,
deleteQuest, completeQuest, reopenQuest, startFocus, stopFocus, addFun,
setFunStatus, deleteFun, setDistracting, saveSettings, ask`, plus the `llm`
field (set to a `GeminiLlm` when a key exists, `null` otherwise).

## Native Android layer (committed; compiles in debug and release)

Behaviour on a real device is still unverified; see the device checklist at
the end.

- `android/app/src/main/kotlin/dev/gaurav/arise/Usage.kt`: usage access check
  and per-app foreground time from `UsageStatsManager.queryEvents`.
- `Alerts.kt`: notification channels, alert notification (BigTextStyle, action
  button), focus-timer notification (ongoing chronometer, requests Android 16
  Live Update via the `android.requestPromotedOngoing` extra), overlay window.
- `WatchWorker.kt`: periodic worker; reads a JSON config saved by Dart
  (`saveWatchConfig`), computes today's distraction, alerts once when near the
  budget and again for every 15 extra minutes over it.
- `MainActivity.kt`: the `arise/system` channel. Methods: `hasUsageAccess`,
  `openUsageAccess`, `usage{start,end}`, `saveWatchConfig`,
  `requestNotifications`, `notificationsAllowed`, `canOverlay`,
  `openOverlaySettings`, `ignoresBattery`, `requestIgnoreBattery`,
  `testAlert`, `focusNotification{title,started}`, `consumeLaunchAlert`; it
  calls Dart's `alert` method when an alert notification is tapped while
  running.
- Resources: dark `styles.xml`, `launch_background.xml`, `ic_system.xml`,
  adaptive launcher icon. `AndroidManifest.xml`: permissions and launcher
  `<queries>`. `build.gradle.kts`: `minSdk = 29`, `androidx.work:work-runtime:2.10.5`.

## UI (committed)

`lib/ui/`: `theme.dart` (`Sys`), `scope.dart` (`AppScope`), `widgets.dart`,
`shell.dart`, one file per screen, `quest_sheet.dart`. `lib/main.dart` boots
the controller behind an `INITIALISING SYSTEM...` gate. Widget tests live in
`test/ui/ui_test.dart` (they use `memoryStore(isolate: false)`, because the
widget-test clock never delivers messages from sqflite's background isolate).

## Remaining work, in order

### 1. Verify and commit the native layer
Run `flutter build apk --debug`. Fix compile errors without changing behaviour.
Then `flutter analyze` and `flutter test`. Commit
`feat(android): usage stats, background watcher, System alerts and overlay`
and push.

### 2. UI (the main job)

No new dependencies. No state-management package: expose the controller with
an `InheritedNotifier<AppController>` (`AppScope.of(context)`).

**Smoothness rules (hard requirements):** no `BackdropFilter`, no blur, no
shaders, no per-frame animations except the focus timer text; lists use
`ListView.builder`/slivers; `const` wherever possible; glow only as a single
`BoxShadow` on a few header panels; build only the visible tab; nothing
heavier than an indexed SQLite query on the UI thread.

**Theme** (`lib/ui/theme.dart`, class `Sys`): bg `#05070D`, panel `#0A111E`,
panelHi `#101B2E`, line `#1C2B44`, accent `#3DA9FF`, accentHi `#9ADBFF`,
text `#D6E4F5`, dim `#6F819B`, danger `#FF4D5E`, gold `#FFC857`, ok `#3DFFB0`.
Font family `monospace` everywhere (no font packages). Panels and buttons use
`BeveledRectangleBorder` (cut corners, radius ~8, 1px border). Section labels
look like code comments (`// STATUS`), 11px, letter-spacing 2, dim. Inputs are
square-cornered with a 1px line border that turns accent on focus. Dark only.

**Shared widgets** (`lib/ui/widgets.dart`): `SysPanel` (cut-corner panel with
optional `// LABEL` header and optional glow), `SysButton` (outlined, uppercase,
accent or danger), `SysBar` (thin segmented progress bar, animated with
`TweenAnimationBuilder`, wrapped in `RepaintBoundary`), `SysTag` (tiny bordered
chip such as `HIGH`, `PENALTY`), `showSystemWindow(context, SystemEvent)`:
a centred dialog styled as a System window (`[ SYSTEM ]` header, title, body,
one `ACKNOWLEDGE` button, red accent when `danger`), entering with a short
scale+fade (about 180 ms).

**Shell** (`lib/ui/shell.dart`): bottom bar with five tabs: STATUS, QUESTS,
SYSTEM, USAGE, VAULT. Implements `WidgetsBindingObserver`: on resume call
`controller.refresh()`. After every controller notification, drain
`controller.takeEvent()` and show each as a System window, one at a time. On
start, show `bridge.consumeLaunchAlert()` if present, and register
`AndroidBridge.onAlert` to show alerts tapped while running (danger style).

**STATUS**: header `ARISE` with a `sys://player` subtitle and a settings icon.
Player panel: big rank letter in a cut-corner box, `LEVEL n`, XP bar with
`into / needed XP`, streak and best streak. Today panel: done versus planned
minutes bar, pending count, a state chip (`ON TRACK` ok / `WARNING` gold /
`DEVIATION` danger) and the report's reasons. Distraction panel: minutes versus
budget bar, top three offenders. `NEXT DIRECTIVE` panel: `pickNext` with the
day's remaining capacity, showing the quest and a `BEGIN` button that starts
the focus timer. If `usageAccess` is false, a panel explaining why and a
`GRANT ACCESS` button.

**QUESTS**: sections `// TODAY`, `// UPCOMING` (grouped by day with
`fmtDay(day, today: today)`), `// QUEST LINES` (targets with a progress bar
from `targetProgress`, long-press to delete with confirmation). Quest tile:
square tick box, title, `actual/estimate` minutes, priority and `PENALTY`
tags, XP value (`questXp`), and a play/stop button for the focus timer. The
running quest shows a live `mm:ss` (a small `StatefulWidget` with a 1 s
`Timer`; only that text rebuilds). Tap the box to complete; tap a completed
one to reopen. Long-press: move to tomorrow, delete. A `+` button opens a
bottom sheet with two modes:
- `NEW TARGET`: title field, priority chips, optional deadline (date picker).
  After 900 ms without typing and at least 4 characters, call
  `controller.suggestPlan(title, deadline:)` and show the steps scheduled by
  `schedulePlan` (use `store.plannedMinutes(today)` and
  `settings.capacityFor`) grouped by day, with a line saying whether the
  source was the System (LLM) or the offline template. Show the template
  instantly while the LLM call is in flight. Steps can be removed. `ACCEPT`
  calls `createTarget`.
- `QUICK QUEST`: title, minutes (15-minute steps), today or tomorrow.

**SYSTEM (chat)**: terminal-style log. Player lines `> text` in accent;
System lines prefixed `[SYSTEM]`; lines with `offline: true` get a dim
`// offline template` suffix. Chips above the input: `15m`, `30m`, `1h`, `2h`
(send "I have X. What should I tackle first?") and `STATUS REPORT`. Show a
blinking-free `...processing` line while `thinking`. Footer:
`tokens today: n` and `link: online|offline` (offline when `llm == null`).
Auto-scroll to the newest line.

**USAGE**: without access, the grant panel. With access: total screen time
today, distraction-versus-budget bar, minutes by category
(`report.byCategory`) as bars, then every app with minutes and a switch for
"distracting" (`isDistracting(...)` for the value, `setDistracting` on
change), noting when the value is the default.

**VAULT**: filter chips ALL / GAMES / MOVIES / BOOKS / MUSIC, add row (kind
selector + title), list with a status button cycling BACKLOG -> ACTIVE ->
DONE, long-press to delete. Done items dimmed.

**SETTINGS** (pushed route): weekday and weekend capacity and distraction
budget as steppers (15-minute steps), Gemini key field (obscured, saved to
secure storage, then set `controller.llm`), model name field, overlay toggle
(opens the overlay permission screen when not yet granted), buttons for
notification permission, battery-optimisation exemption, usage access, and
`TEST ALERT` (`bridge.testAlert()`). Show each permission's current state.

**main.dart**: `WidgetsFlutterBinding.ensureInitialized()`, lock portrait,
open `Store`, read the key, build `AppController`, `await init()`, run the
app. Show a plain dark screen with `INITIALISING SYSTEM...` until `ready`.

Tests: add widget tests with `FakeBridge` and `memoryStore` for at least:
status screen renders level and rank; ticking a quest shows the
`QUEST COMPLETE` window; chat chip produces a System line. Note that sqflite
ffi inside `testWidgets` needs `tester.runAsync` around database work.

Commit per screen or coherent group, each after analyze + tests pass, and push.

### 3. Final checks
- `flutter build apk --release` succeeds; report the APK size.
- Write a short `README.md`: what it is, how to get a Gemini key
  (Google AI Studio), the permissions and why, how to build and install.
- Remove this file's "not yet verified" section once it is true, commit, push.
- Do not attempt device testing: the user will provide Wi-Fi debugging access
  afterwards. Report anything that could only be verified on a device
  (usage events, overlay, Live Update chip, WorkManager timing, the exact
  Gemini model name and its free-tier status).
