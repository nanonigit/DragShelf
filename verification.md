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

## 2026-09-28 — v0.1.0 publication checks

- User approved restarting the app; the previous in-memory shelf items were discarded as expected. A normal launch displayed the management window with an empty-item message and a transparency slider (visible via the macOS accessibility tree). Changing and persisting its value still needs a hands-on check.
- The status-item permission click and the narrow shelf/gear were not directly observable through the available computer-use surface and remain manual UI checks. Do not infer success solely from compilation.
- `swift test`: 8 passed, 0 failed. The final release archive is Apple Silicon (arm64) only: `lipo -info` reports arm64 for both executables.
- `bash script/package_release.sh 0.1.0`: release build and nested code-signature verification passed; ZIP integrity passed. Final `DragShelf-0.1.0-macos-arm64.zip` SHA-256: `05f572ca4884cafd46ba0af91661a37255c6c14ea83d4cdef04ac1f2d2e4f166`.
- `spctl -a -vv` still rejects the ad-hoc-signed bundle. User approved release with this experimental unsigned-distribution warning; Gatekeeper is not bypassed by the installer.
- Copied the verified bundle to `/Applications/DragShelf.app` and launched it from that path. The running process path and bundle version (`0.1.0`) were checked; the development `dist` process was stopped.

## 2026-09-28 — settings, history, and menu-bar visibility candidate

- `swift test`: 12 passed, 0 failed, including bookmark/path restoration and oldest-first history eviction. These are unit tests; a real Finder file was not parked for a restart trial.
- Built the v0.1.0 release bundle and installed it at `/Applications/DragShelf.app`; `codesign --verify --deep --strict` passed there. Its ad-hoc signature still fails Gatekeeper assessment.
- The native management UI showed **一時置き** and **設定** tabs, selectable 25-item limit, launch status, and actual input-monitoring state. At this point Input Monitoring still reported "アプリ側では未許可" and AppKit fallback, despite the user's System Settings switch being ON; the later re-registration check is recorded below.
- The **メニューバーアイコン** checkbox was switched off (accessibility value 0); the persisted preference became `showMenuBarIcon = 0`. Opening `/Applications/DragShelf.app` again brought management forward with the checkbox still off. Switching it on returned the checkbox to value 1. This verifies a recovery path from the hidden icon.
- Current ZIP SHA-256: `8fa20f0c23a14e0688f681cd19b38f43c210077fdbe0b338390a5bb1836a34de`. Release publication and Homebrew installation remain to be verified separately.
- After the user removed and re-added the Input Monitoring grant for the final `/Applications/DragShelf.app` build, the native settings UI showed **アプリ側で許可済み** and **動作中（入力監視を使用）**. This confirms the current installed build can use the passive event tap. It does not prove that future ad-hoc-signed updates will retain permission.

## 2026-09-28 — v0.1.1 management tab order

- `swift test`: 12 passed, 0 failed. Release bundle build and signature verification passed; Gatekeeper still rejects this ad-hoc-signed build.
- Installed v0.1.1 at `/Applications/DragShelf.app` and launched it. Native accessibility inspection showed **設定** as the first tab and selected (`Value: 1`), with **一時置き** second (`Value: 0`). Selecting the right tab showed the empty shelf list, then Settings was selected again.
- Input Monitoring reverted to **アプリ側では未許可** after rebuilding/signing v0.1.1, as warned for ad-hoc signing. The AppKit fallback was running. Only the user can re-grant that macOS permission; this does not affect the tab-order check.
- ZIP SHA-256: `e77c0ea0892ff9ebe32facf7a74941df6167f9d89b0f257bc3dd509665775cb6`. A real-file restart test, full-screen and multi-display checks remain open.
- Published [v0.1.1](https://github.com/nanonigit/DragShelf/releases/tag/v0.1.1) with the ZIP and SHA-256 sidecar. The dedicated tap was renamed to [homebrew-DragShelf](https://github.com/nanonigit/homebrew-DragShelf); `brew tap nanonigit/dragshelf`, `brew audit --cask nanonigit/dragshelf/dragshelf`, and `brew fetch --cask nanonigit/dragshelf/dragshelf` succeeded.
- An isolated Homebrew install to `/Users/naoki/Documents/Wav2Vec2/DragShelf-homebrew-test-apps` succeeded with v0.1.1 and valid ad-hoc signature. The test-only copy was uninstalled from that directory. `/Applications/DragShelf.app` remained installed and running at v0.1.1 throughout this Homebrew check.

## 2026-09-28 — v0.1.2 Dock visibility

- `swift test`: 16 passed, 0 failed. Four new tests cover default visibility, refusal to hide the last icon, preference restoration, and normalization of corrupted both-hidden preferences.
- Release build and `codesign --verify --deep --strict` passed. The archive passed `unzip -t`, and the main executable is arm64. `spctl` rejects the ad-hoc-signed bundle as expected; it is not notarized.
- Installed `/Applications/DragShelf.app` v0.1.2. The native management UI showed the Dock checkbox disabled while the menu-bar icon was hidden. After showing the menu-bar icon, hiding Dock updated the checkbox to off and disabled the menu-bar checkbox. The management window remained usable in this state.
- Quit and reopened the installed app while Dock was hidden. Settings opened again with Dock off, menu-bar on, and the last-icon guard intact. Restored the user's prior Dock-on/menu-bar-off settings after the check.
- This verifies the native preference and recovery UI. A macOS Dock screenshot and physical file drag were not collected in this pass. A future ad-hoc update may require re-granting Input Monitoring.
- Final ZIP SHA-256: `9155153f8de798269b12cb4ef20a2fc25ba271ffb78b0fa2884dd632b18616ff`. Published [v0.1.2](https://github.com/nanonigit/DragShelf/releases/tag/v0.1.2) with ZIP and checksum; the release is marked prerelease and carries signing/permission caveats.
- Updated [homebrew-DragShelf](https://github.com/nanonigit/homebrew-DragShelf) to v0.1.2. The installed tap fast-forwarded, `brew audit --cask nanonigit/dragshelf/dragshelf` passed, and `brew fetch --cask nanonigit/dragshelf/dragshelf` resolved v0.1.2.
- `/Applications/DragShelf.app` remains running at v0.1.2 with a valid ad-hoc code signature. After the UI test, persisted settings were restored to Dock visible and menu-bar icon hidden.

## 2026-09-29 — v0.1.3 placement and duplicate-shelf candidate

- The duplicate-shelf report was traced to two simultaneous processes: `/Applications/DragShelf.app` (PID 29868) and `dist/DragShelf.app` (PID 75423). The development process was stopped; a subsequent process check showed only the installed app. The installed app's in-memory popup still showed near-drag while `UserDefaults` stored left-bottom, consistent with two independent app instances caching placement.
- Added five placement choices and geometry tests for all four corners; the previous three raw values remain compatible. `swift test`: 17 passed, 0 failed. Native v0.1.3 settings UI exposed all five choices and selecting left-top persisted `leftTop`; the user's left-bottom choice was restored afterward.
- Added a startup duplicate-instance guard. Explicitly launching `dist/DragShelf.app` while `/Applications/DragShelf.app` was running caused the development process to exit; only the installed process remained after startup. This was checked with both debug and release staged bundles. A physical drag was not repeated automatically.
- Installed v0.1.3 at `/Applications/DragShelf.app` with valid ad-hoc signature. In management, both Dock and menu-bar checkboxes could be off simultaneously, and a cold launch with both off opened Settings. The distinct already-running, closed-window reopen path remains an independent manual check.
- Release ZIP passed `unzip -t` and `codesign --verify --deep --strict`; it is arm64 and still rejected by Gatekeeper because it is not notarized. The update changed the ad-hoc signature, and management reported Input Monitoring not granted with the AppKit fallback active. The user must re-grant Input Monitoring if desired.
- Final ZIP SHA-256: `91402eaeefa51524cbc73265b37941b4023bc1e1209118b6ebdc47f9440985ce`. Published [v0.1.3](https://github.com/nanonigit/DragShelf/releases/tag/v0.1.3) with the ZIP and checksum; it is marked prerelease and explains signing/permission limits.
- Updated [homebrew-DragShelf](https://github.com/nanonigit/homebrew-DragShelf) to v0.1.3. The local tap fast-forwarded, `brew audit --cask nanonigit/dragshelf/dragshelf` passed, and `brew fetch --cask nanonigit/dragshelf/dragshelf` resolved v0.1.3.
- Final installed state: one `/Applications/DragShelf.app` v0.1.3 process, `shelfPlacement = leftBottom`, Dock icon hidden, menu-bar icon visible. Source and tap checkouts were clean before this verification note was appended.

## 2026-09-29 — v0.1.4 shelf control contrast

- The user's icon-mode screenshot showed a dark gear on the dark header and a dark X on a dark circular backing. Both are hard to identify at a glance.
- Replaced their inherited symbol rendering with explicitly white SF Symbols on dark, outlined control backgrounds. The remove control grows from 19 to 23 points while retaining its existing expanded click region.
- `swift test`: 17 passed, 0 failed. A standalone AppKit bitmap render of the configured `gearshape.fill` produced 123 white symbol pixels, checking that the palette is applied rather than rendering a dark template.
- The v0.1.4 release build and nested app signature verified. Installed the final build at `/Applications/DragShelf.app` and launched it; the management window opened. The shelf had no parked items at that time, so X-on-file visual verification in list/icon mode remains pending. Do not describe this as a completed physical drag test.
- Management reported Input Monitoring not granted after this ad-hoc-signed update, with the AppKit fallback active. Re-granting permission requires the user to use macOS System Settings.
- Final ZIP SHA-256: `6712ad31bf42f1a00a62b2981f6c9c120a663aaad3ab1027c813065676a122d9`. `unzip -t` passed and the main executable is arm64. Published [v0.1.4](https://github.com/nanonigit/DragShelf/releases/tag/v0.1.4) as a prerelease with ZIP and checksum.
- Updated [homebrew-DragShelf](https://github.com/nanonigit/homebrew-DragShelf) to v0.1.4. The installed tap fast-forwarded; `brew audit --cask nanonigit/dragshelf/dragshelf` and `brew fetch --cask nanonigit/dragshelf/dragshelf` passed.
- After replacing the bundle, terminated the pre-update process and started the installed copy again. One `/Applications/DragShelf.app` process is running (PID 92562); management shows the AppKit fallback and the saved menu-bar/Dock settings.
