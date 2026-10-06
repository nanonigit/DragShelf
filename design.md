# DragShelf design

## Quick Look

Lazyweb's desktop file-preview search returned adjacent web file browsers, not a macOS hover/Space precedent. Preserve the existing shelf and use Apple's native [QLPreviewPanel](https://developer.apple.com/documentation/quicklookui/qlpreviewpanel) instead of inventing a viewer. The user approved clicking to obtain focus. A key-capable nonactivating shelf panel takes local keyboard focus only when an available file is clicked, not merely hovered; no global keyboard monitor or additional permission is introduced. An always-active tracking area records the hovered point, and each Space press resolves the current item using current geometry and scroll offset; never retain an array index across model changes. Release shelf focus on exit, over controls, during a drag, or when hidden. Highlight the targeted row and expose a Space tooltip.

`ShelfDropView` owns the preview URL and participates in the documented Quick Look responder-chain control lifecycle, also serving as the shelf's window delegate. It installs and removes the data source/delegate only in begin/end control callbacks. Show the preview window before reloading its data so AppKit has acquired a controller. Preview data is a single file URL; unmodified Space toggles the same file or switches to another hovered item. Escape closes, repeats do nothing, and removal/hiding closes an owned preview. Preview focus is not stolen merely because the cursor moves from the shelf into the preview. AppKit tests cover hover hit testing, modifiers/repeats, scrolling and mutation. The optional native-window lifecycle test skips when the unhosted XCTest runner cannot acquire key focus; installed-app checks cover that path instead.

## Core distinction

`NSDraggingDestination` only reports a drag once it reaches DragShelf's registered window/view. It cannot announce a drag that has just begun in Finder. Automatic reveal therefore uses two independent public signals:

1. A passive, session-level Core Graphics event tap observes mouse down, drag, and up. It never alters, posts, or suppresses events.
2. The named drag pasteboard's `changeCount` and types indicate that a fresh, supported drag payload exists. A mouse drag without new supported payload does not reveal the panel.

`DragDetectionEngine` combines these signals as a pure state machine. `GlobalDragMonitor` delivers input observations, and `DragPasteboardProbe` samples pasteboard metadata. A short timer resamples while the button is held because source apps may populate the pasteboard after the first mouse-dragged event. The callback returns immediately; UI and pasteboard work run on the main actor.

This is an inference, not a system-provided `dragDidStart` event. Its reliability and the permission required for the passive tap must be measured on the target macOS release. If the tap cannot run, the app retains the menu-bar Show Shelf entry point; an edge tab is a later enhancement.

## Input Monitoring permission

After the menu-bar item and monitor are initialized, the app checks `CGPreflightListenEventAccess()` once at launch. If access is missing, it calls `CGRequestListenEventAccess()` once to let macOS present its consent flow. The menu command opens System Settings on demand; the two-second timer only detects permission changes and restarts the passive monitor. A denial does not block manual shelf use. The app does not change TCC settings or approve its own request.

The permission menu's manual path opens System Settings → Privacy & Security → Input Monitoring. `CGRequestListenEventAccess()` may not present a second prompt after the first request, so simply calling it again is not useful feedback. The menu labels the action as opening settings, and the timer updates the reported state after a user grants access.

## Components

- `DragDetectionEngine` (core): idle/pressed/dragging state, pasteboard generation baseline, one reveal per drag, reset on mouse up. Unit tested.
- `GlobalDragMonitor` (AppKit/Core Graphics): passive event tap. Fallback to AppKit's global mouse-event monitor if the tap is unavailable; report the active mode in the menu.
- `DragPasteboardProbe` (AppKit): reads only `changeCount` and advertised types. It never clears or writes the drag pasteboard.
- `ShelfController` (AppKit): owns a nonactivating `NSPanel` and its position on the pointer's screen. Uses all-Spaces/full-screen auxiliary behavior and verifies these in real scenarios.
- `ShelfDropView` (AppKit): registers `.fileURL`, performs an actual drop via `NSDraggingDestination`, requests copy semantics, and hands URLs to the shelf model.
- `ShelfModel`: retains file URL references while the app runs. Parking never relocates source files. Persistence/bookmarks are deferred until restart behavior is designed.

## Event sequence

```text
mouse down -> remember pasteboard generation
mouse dragged -> sample generation and types
fresh supported drag -> reveal nonactivating panel on pointer display
drag enters panel -> AppKit validates file URL
drop -> park URL(s) -> keep panel visible
mouse up without drop -> hide empty panel after a short grace period
```

## Risks and validation

| Risk | Required evidence |
| --- | --- |
| Passive monitor not permitted or not receiving drag-session events | Record event and pasteboard transitions in Finder, Safari, and full-screen tests. Keep manual entry points. |
| False reveal during window movement or text selection | Fresh supported payload is required; exercise negative tests. |
| Panel appears but cannot become the destination mid-drag | Physically drag Finder file into newly revealed panel before release. |
| Panel steals focus or changes Space | Confirm Finder remains active and the cursor stays in its Space. |
| File URL access after drop | Test source remains in place and outgoing Finder/app drop works. |

## UI evidence

The supplied Yoink references establish the small edge shelf, temporary parking, and later drag-out workflow. Lazyweb's desktop corpus did not return a directly comparable macOS utility shelf, so it does not justify specific visual details. The first panel stays deliberately simple until the interaction is verified.

## Phase 2 shelf and management UI

The user's reference screenshot shows a content thumbnail above a shortened filename. A [Lazyweb UI report](https://www.lazyweb.com/report/lazyweb/0ebfd570-2c97-40cf-81ea-25d92f469d45/?source=create) was generated for this change, but the available preview does not establish a macOS-native shelf pattern. The user's screenshot and native macOS behavior remain the concrete design constraints.

The shelf keeps its nonactivating drop surface. A compact header offers **リスト** and **アイコン** view choices. List mode shows a small preview and one-line filename; icon mode shows a larger thumbnail and shortened filename in a two-column grid. The choice persists in `UserDefaults`. Quick Look Thumbnailing loads previews asynchronously and caches them for the current shelf session; until ready or when unavailable, the system file icon is shown. Neither preview generation nor rendering moves or modifies files. Overflow scrolls inside the panel, with the header fixed.

After seeing the first running build, the user requested approximately half the 320-point shelf width. The revised shelf is 160 points wide: icon mode is one column, list mode remains compact, and the header has only a gear (management) plus view controls. The panel title is removed. Management exposes a transparency slider (0–60% transparent), stored in `UserDefaults` and applied to the shelf panel alpha; the limit keeps the drop target readable.

The shelf panel stays separate from a regular management window. The management window shows all parked files with per-item removal. The app has a Dock/Application icon and a menu-bar icon: a user launch or reopen from Applications/launcher opens management, while the menu bar explicitly offers **棚を表示**, **棚を隠す**, and **管理画面を開く**. Hiding the shelf is temporary; the next supported external drag may reveal it again. Removing the last item hides the shelf immediately; an empty shelf shown for an active drag remains available until that drag ends.

The shelf's gear and each item's remove action use a dark, opaque-enough control backing with a white SF Symbol. This avoids inheriting a dark template tint on the dark shelf or on a dark file preview. Keep the existing hit regions at least as large as the drawn controls, with no change to drop/drag behavior. Verify contrast in the installed app at normal and reduced shelf opacity.

## Placement, status, and startup

Settings offers **左下**, **左上**, **右下**, **右上**, and **ファイルの近く**, persisted in `UserDefaults`. Placement uses the pointer's current display's `visibleFrame`. The four corner modes use a fixed inset. Near-drag mode prefers a position offset from the pointer and flips/clamps at display edges; a panel resize reuses the last pointer location. Geometry is pure and unit tested. Changing placement repositions the existing panel; it never creates another one.
Lazyweb's desktop settings search returned adjacent preference screens, but no native macOS shelf-placement precedent; the exact five choices and their order follow the user's request and the existing AppKit popup.

The status menu reports two independent facts in plain Japanese: whether Input Monitoring permission is granted, and whether drag monitoring is running with or without that permission. It does not label a working fallback as “許可待ち”. The permission action remains available only when not granted.

Launch at login is opt-in. The original implementation registered a nested login-item helper through `SMAppService.loginItem(identifier:)`; it opened the main app with `--login-start` so startup stayed background-only. A normal cold launch and a Finder/Dock reopen show management. The original UI reflected `SMAppService.status`, but this did not detect launchd's code-signing refusal for the ad-hoc helper; the replacement and migration are described below.
The helper's running-app guard uses the main bundle's actual identifier. Both app and helper increment `CFBundleVersion` on release. On this machine, refreshing the ad-hoc-signed `SMAppService` login item updated its registered version but launchd rejected the helper with `OS_REASON_CODESIGNING | Launch Constraint Violation`. Thus the checkbox's `.enabled` status was not proof of launchability. Until a Developer ID signature is available, v0.1.5 uses a per-user `~/Library/LaunchAgents/com.github.nanonigit.DragShelf.startAtLogin.plist` with `RunAtLoad` and Apple's `/usr/bin/open` to start the installed `/Applications/DragShelf.app` with `--login-start`. The app migrates only an enabled legacy login item, unregisters that broken service, and leaves disabled users opted out. The agent stores an exact app path to avoid picking a development copy; app startup refreshes the path if needed. Management shows whether the agent configuration exists, not the legacy `SMAppService` status. A manual `launchctl bootstrap` test proves the job can start the app; a real logout/login remains the final user acceptance check.

An original square app icon is packaged as `icns` and referenced by `CFBundleIconFile`; the menu-bar symbol may stay a monochrome system symbol for legibility.

## Distribution

DragShelf is an independent public repository. A release script builds both Swift executables in release configuration, stages a versioned `.app`, signs its nested helper and main bundle consistently, checks the bundle, and creates a zip and SHA-256 checksum. Without a Developer ID identity this signature is ad hoc: the GitHub Release and tap must label that limitation plainly, and must not disable Gatekeeper automatically. The Homebrew tap references the immutable release asset URL and verified checksum. English and Japanese README sections explain installation and Input Monitoring.
The first binary is built on Apple Silicon and contains arm64 executables only; its archive name and tap dependency declare that architecture explicitly.

## Persistent shelf references

The shelf stores references, not file contents. `ShelfHistoryStore` writes an ordered list of file bookmark data plus fallback paths to app-local `UserDefaults`. On launch it resolves bookmarks to their current URLs, keeps unresolved paths visible as missing items, and re-saves stale bookmarks on the next mutation. The app is currently unsandboxed, so standard bookmarks are sufficient; a sandboxed distribution would need security-scoped access. A count limit is chosen from 5, 10, 25, 50, or 100 (default 25). Adding beyond the limit drops oldest references before saving, never deletes originals; reducing the limit trims immediately. Removal and the limit choice persist across restarts. A missing source is marked in management and cannot start an outgoing drag until the file is restored.

## Consolidated management UI

The [Lazyweb menu analysis](https://www.lazyweb.com/report/lazyweb/4b6e33dd-26c5-4501-8af5-0b2a2c296f32/?source=create) found that quick actions and persistent preferences compete in the existing menu. Its free preview proposes a drag-state menu, but does not establish a native macOS pattern or justify replacing the actual drop panel. The user's screenshot and request drive a smaller, predictable change: the status menu keeps only **管理画面を開く**, one show/hide shelf action, a concise parked count, and **終了**. Its settings and permission controls move to management.

Management uses two native tabs: **一時置き** for the file list/removal, and **設定** for grouped rows. The settings tab contains display mode, placement, transparency, history item limit with oldest-first explanation, login launch with actual registration status, and Input Monitoring status with a clear System Settings button and active drag-detection mode. The list and settings share one window and remain accessible after the shelf is hidden. The shelf's own list/icon switch and gear remain as direct shortcuts.
Settings also contains a persisted **メニューバーにアイコンを表示** checkbox. The status item remains allocated; `NSStatusItem.isVisible` controls only its visibility. This avoids stopping the monitor or discarding the menu. The checkbox reflects the effective status-item visibility. When the menu-bar icon is hidden, the Dock/Applications launcher opens management; when the Dock icon is hidden, the menu-bar action opens management. The shelf gear remains another path.
The requested tab order is **設定** on the left, **一時置き** on the right; the settings tab is selected when the management window is created. Returning to an already-open management window preserves the tab the user last selected. Lazyweb's desktop settings search surfaced adjacent sidebar patterns, not an exact native macOS two-tab precedent, so the user's screenshot and direct preference determine this small ordering change.
Dock visibility belongs alongside menu-bar visibility in the existing **表示** group. AppKit's `NSApplication.setActivationPolicy(.regular/.accessory)` switches whether the running app appears in the Dock; `LSUIElement` remains unchanged, so the installed bundle stays launchable from Applications. Save the preference only when AppKit accepts the policy switch, and show the effective policy in the checkbox. The shelf and file history must continue unchanged. A menu-bar action can always reopen management while the Dock icon is hidden; a fresh launch must apply the saved preference before presenting management. Lazyweb search found adjacent desktop settings toggles but no exact macOS Dock-presence control, so native AppKit behavior and the user's requested setting determine the implementation.
The user later requested that both icons may be hidden. Store each visibility choice independently and show an explicit note that reopening DragShelf from Applications brings back management. Verify this both while the accessory app is running and after a fresh launch. Do not silently restore the Dock icon when both preferences are false.

## One running shelf

The duplicate shelf report was traced to two live processes: `/Applications/DragShelf.app` and the development `dist/DragShelf.app`. Each process owns exactly one `ShelfController` panel and independently retains its last selected placement, explaining why one remained near the pointer while the other moved left-bottom. Stop the development copy for immediate recovery. At startup, check for another running DragShelf bundle identifier before constructing the shelf; a subsequent launch reopens the existing app and exits without making another panel. Test by explicitly launching the staged development bundle while the installed app is running. This is a development-copy protection, not a substitute for a physical drag test.
[Apple DTS](https://developer.apple.com/forums/thread/719862) notes that `SMAppService.Status.notFound` can mean a login item has never been registered, so that state must not disable the login toggle. The initial label is “未登録”; enabling it attempts registration and reports any error.

## Language design / 言語切替の設計

1. Core owns `AppLanguage` (`en`, `ja`) and an exhaustive, typed `AppText` catalog. Only the app-language preference is written; do not modify `AppleLanguages` or file history.
2. Settings uses an always-recognizable `Language / 言語` row and native popup with `English` / `日本語` self-names. Lazyweb settings reference search informed keeping the control explicit and inside Settings rather than the menu bar.
3. Main-actor UI refresh is explicit: management callback → controller saves language → management labels/popups refresh in place → shelf redraws → app delegate refreshes menu and current system status. No window/model/monitor recreation.
4. Static labels register their typed text keys; the window, tab selection, and model are retained. Display/placement popups are replaced with configured controls that restore their previous selection before attachment. Retitling live popup items leaves stale rendered titles on the tested AppKit version. History uses a language-independent, single-selection 5/10/25/50/100 segmented control, making the current limit directly visible. Counts use translated format templates rather than interpolated lookup keys.
5. Increase management vertical room for the language row and wrapping English notes. Verify English/Japanese, repeated switching, persistence, and unchanged unrelated preferences/items.

6. Group settings in bordered native AppKit sections: General (language, icon choices, login startup), Shelf Appearance (mode, position, transparency), History, and Drag Detection (current mode, access state, settings action, Help). The scroll view keeps all groups reachable in a small window. Permission troubleshooting opens as a localized sheet instead of occupying the main form.
7. Defer the language callback to the next main-queue turn so other popup menus are not mutated during language-menu tracking. Verify actual rendered count titles after menu dismissal, not only selected indices.

日本語: 共通の型付き文言一覧を使用し、変更時は既存UIの文言だけを更新する。設定・ファイル履歴・ドラッグ検知を作り直さない。OS提供のダイアログは翻訳対象外。
