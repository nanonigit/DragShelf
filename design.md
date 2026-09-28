# DragShelf design

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

## Placement, status, and startup

The menu offers **左下**, **右下**, and **ドラッグ位置の近く**, persisted in `UserDefaults`. Placement uses the pointer's current display's `visibleFrame`. The corner modes use a fixed inset. Near-drag mode prefers a position offset from the pointer and flips/clamps at display edges; a panel resize reuses the last pointer location. Geometry is pure and unit tested.

The status menu reports two independent facts in plain Japanese: whether Input Monitoring permission is granted, and whether drag monitoring is running with or without that permission. It does not label a working fallback as “許可待ち”. The permission action remains available only when not granted.

Launch at login is opt-in. A small nested login-item helper is registered through `SMAppService.loginItem(identifier:)`; it opens the main app with a `--login-start` argument so startup can remain background-only. A normal cold launch and a Finder/Dock reopen show management. The UI reflects `SMAppService.status` and surfaces registration/approval errors rather than silently claiming success. The helper and main app must be bundled and signed consistently; this is an integration gate, especially in the local SwiftPM development bundle.

An original square app icon is packaged as `icns` and referenced by `CFBundleIconFile`; the menu-bar symbol may stay a monochrome system symbol for legibility.

## Distribution

DragShelf is an independent public repository. A release script builds both Swift executables in release configuration, stages a versioned `.app`, signs its nested helper and main bundle consistently, checks the bundle, and creates a zip and SHA-256 checksum. Without a Developer ID identity this signature is ad hoc: the GitHub Release and tap must label that limitation plainly, and must not disable Gatekeeper automatically. The Homebrew tap references the immutable release asset URL and verified checksum. English and Japanese README sections explain installation and Input Monitoring.
The first binary is built on Apple Silicon and contains arm64 executables only; its archive name and tap dependency declare that architecture explicitly.
