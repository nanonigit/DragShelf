# Verification record

## 2026-09-28 — Phase 1 implementation

- Xcode 27.0 / Swift 6.4 on macOS 27.0 (arm64).
- `swift test`: 5 detection state-machine tests passed, 0 failed.
- `./script/build_and_run.sh --verify`: built and launched `dist/DragShelf.app`; process existence confirmed.
- Native app screenshot showed the empty shelf panel with the expected title and drop prompt.
- Unified log showed the monitor starting. `CGPreflightListenEventAccess()` returned `false` on this Mac, so the app now uses an AppKit global monitor until Input Monitoring is granted.
- Computer-use automation sent Finder click/drag actions, but neither the passive event tap nor the AppKit global monitor observed those synthetic actions. Therefore those attempts are **not** evidence that a physical Finder drag succeeds or fails.

## Required physical checks before Phase 1 passes

1. Grant Input Monitoring from the DragShelf menu, if requested by macOS.
2. Drag a file from Finder while the shelf is hidden. Confirm the shelf appears before releasing the pointer.
3. Continue the *same* drag into the newly shown shelf. Confirm the item is listed and the source file remains at its original path.
4. Drag the parked item from the shelf to Finder or another app. Confirm the destination receives it.
5. Move a Finder window and select text; confirm no shelf appears for these non-file drags.
6. Repeat in a full-screen app and on each connected display that is available.

Record pass/fail and any app-specific deviations here after the physical checks. Do not mark Phase 1 complete from build/unit results alone.

## 2026-09-28 — launch-time Input Monitoring request

- User screenshot shows two parked desktop items (an MP3 and a PowerPoint file). This confirms parking in the running app, but does not by itself establish that the shelf appeared automatically at drag start.
- Added a single launch-time `CGPreflightListenEventAccess()` check and `CGRequestListenEventAccess()` call only when access is absent. The existing menu command and permission-change polling remain available.
- `swift test`: 5 passed, 0 failed. `swift build --product DragShelf`: succeeded. The rebuilt binary was placed in `dist/DragShelf.app` atomically without terminating the running process, so parked items remain in its memory. The running process still uses the previous binary until restarted.
- Manual next-launch check pending: with access absent, verify macOS displays its consent flow; after approval verify the menu reports the passive event tap. With access already granted, verify no new request is shown. A rejected request must leave manual shelf use available.

## 2026-09-28 — shelf UI and release candidate

- `swift test`: 8 tests passed, 0 failed (drag detection and shelf geometry, including the 160-point one-column layout).
- Release build of the main executable and login helper succeeded. `codesign --verify --deep --strict` passed for the staged bundle. ZIP integrity check passed; SHA-256: `88509c0e1cc4ad3188009ee2dafb5c2bae84c4798491aa8f42bd407806461a42`.
- `codesign -dvvv` reports `Signature=adhoc` and no TeamIdentifier. `spctl -a -vv` rejects the bundle. This is **not** a notarized, Gatekeeper-approved build.
- Earlier running build was checked visually: management appeared on launch; list/icon selection changed shelf content; an MP3 preview appeared. The new 160-point header, gear, transparency slider, and System Settings permission action are built but **not yet checked in a restarted app** because the currently parked item would be lost.
- Manual permission approval, outgoing drag, full-screen/Spaces, multiple displays, login-item registration, and Gatekeeper override remain unverified.
