# Verification record

## 2026-10-06 — English/Japanese and grouped Settings candidate

- Added an independent, persisted language preference. Fresh/missing/invalid values resolve to English even if macOS prefers Japanese. All app-owned management, menu, shelf, tooltip/accessibility, status, and alert strings use a typed bilingual catalog. Native macOS dialogs/system error descriptions still follow OS language.
- Requirements/design were recorded before implementation; the first language tests failed because the feature did not exist, then passed after implementation. Final `swift test`: 23 Core tests passed; 5 AppKit tests passed, with 1 existing native Quick Look lifecycle test skipped because unhosted XCTest cannot acquire key focus. No failed tests. Language UI tests cover repeated switching, selected tabs, display/placement indices, opacity, history limit, parked-reference persistence, and overflow at a smaller active Settings window.
- Grouped Settings in General, Shelf Appearance, History, and Drag Detection sections. Language and startup/icon choices are together; permission troubleshooting opens in a localized Help sheet. History limit uses direct 5/10/25/50/100 single-selection buttons.
- Native screenshots exposed a discrepancy that selection/accessibility assertions did not detect: the translated history popup could visibly show its first item although the selected value remained 25. Documented reproduction, attempted repairs, and the final language-independent history selector in `bug-investigation/reports/language-popup-2026-10-06.md` and its Japanese translation.
- `BUILD_CONFIGURATION=release bash script/build_and_run.sh --build-only` passed. Installed at `/Applications/DragShelf.app`; deep/strict ad-hoc signature verification passed. Staged and installed executable SHA-256 both equal `e15c086fe6967d97f1aac7a906dcb4f96856b57dc67d79ec888f485269f47230`. Previous installed bundle retained at `/tmp/DragShelf-language-backup.TGpqHj/DragShelf.app` for local rollback.
- Native UI verified English default on first updated launch, Japanese immediate switching, both layouts, Japanese Help sheet, and the highlighted 25 limit in both languages. Changed limit 25→50→25 successfully. Japanese selection survived a restart; final preference was set to English. Preserved the observed icon, startup, display, placement, and transparency choices.
- The app reports Input Monitoring not recognized and an active AppKit fallback. Permission changes remain user-controlled. This work does not claim to fix the prior signing/permission discrepancy, nor replace broader drag/full-screen/multiple-display validation.
- Bilingual README describes the feature as current source, not part of the existing v0.1.6 public download. No GitHub Release or Homebrew update was made in this pass.

日本語: 初期値は英語。設定を4グループに整理し、英語・日本語の切替、状態保持、再起動後の日本語復元、ヘルプ、保存件数25→50→25を実画面で確認した。保存件数は直接選択する形式に変更。テスト28件成功・失敗なし、既存のQuick Look実画面テスト1件は環境制約でスキップ。アプリケーション内のアプリを更新し、最終言語は英語。入力監視の既存問題と公開配布版の更新は別件で、未解決・未実施。

## 2026-10-06 — v0.1.6 Quick Look

- Added native `QLPreviewPanel` with click-to-focus Space handling, following the user's approval to use a click. Merely hovering does not take focus. No keyboard monitor or new TCC permission is added.
- `swift test`: 23 passed, 0 failed, 1 skipped. Four new AppKit tests cover list/icon targets, header/remove/outside/empty/missing exclusions, scroll/model changes, and modified/repeated keys. The optional native preview lifecycle test skips because this unhosted XCTest process cannot acquire AppKit key focus; this is not counted as a passed interaction test.
- Built and installed the final release bundle at `/Applications/DragShelf.app`. In both icon and list modes, clicking the test-file body and pressing Space showed a **Quick Look** window with title **sample.txt** and text **DragShelf integration test fixture.** Space again closed it; Escape also closed it in the final installed release. These are native UI checks, not a physical Finder drag test.
- The shelf was empty before testing. Temporarily added only the repository's sample.txt reference, then removed that reference while preserving any other entries, restored the prior icon display preference, and reopened management. Original files were not modified.
- Release build and nested `codesign --verify --deep --strict` passed. The app remains ad-hoc signed/unnotarized and `spctl` rejects it as expected. The rebuilt app reports Input Monitoring absent and uses the AppKit fallback; granting it again is a user action and is not required by Quick Look.
- The release ZIP passed `unzip -t`; SHA-256: `11f5a8fca053c0c2f6c53b9ea8d659c3a675509e25f713d7674f67b84a41918f`.
- Published [v0.1.6](https://github.com/nanonigit/DragShelf/releases/tag/v0.1.6) as a prerelease with ZIP/checksum and English/Japanese notes; the main branch was pushed. Updated `homebrew-DragShelf` to the same version/checksum, fast-forwarded the installed tap, and successfully fetched **Cask dragshelf (0.1.6)**.
- Still pending: a physical keyboard-focus-return check after moving from the shelf to another app, full-screen/multi-display preview, missing-file deletion while a native preview is open, and broader file-type coverage.

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

## 2026-09-30 — login startup repair candidate

- The v0.1.4 `SMAppService` job repeatedly failed with `EX_CONFIG`. Re-registering a v0.1.5 helper fixed path resolution but not execution: `launchd` logged `OS_REASON_CODESIGNING | Launch Constraint Violation`, and `amfid` identified the ad-hoc signature.
- Replaced login startup with a per-user LaunchAgent invoking `/usr/bin/open` on `/Applications/DragShelf.app --login-start`. Only users whose legacy item was enabled are migrated; the old failing service is unregistered. Corrected the helper's main-app bundle identifier as a separate defect.
- `swift test`: 19 passed, 0 failed, including agent write/path-refresh/remove tests. The release build and `codesign --verify --deep --strict` passed; the app remains ad-hoc signed and unnotarized.
- Installed the candidate at `/Applications/DragShelf.app`. The exact LaunchAgent plist passed `plutil -p`; `launchctl bootstrap gui/503` started the installed app with `--login-start`, and `launchctl print` reported `runs = 1` and `last exit code = 0`. The old login-item service was absent.
- An actual logout/login remains untested. This is a session bootstrap test, not proof of the next real login.
- The native management UI showed the login checkbox on and “有効（次回ログイン時に起動）”. The final arm64 ZIP passed `unzip -t`; SHA-256: `882ba676cb08211c6d79b74d3d8bd2a4ced4b0fa60a3b07f4a5d02ea965934ba`.
- In the installed management UI, turning login launch off removed the exact LaunchAgent plist and changed the checkbox/status to off. Turning it on recreated a valid plist and restored the on/status display; the setting was left on.
- Published [v0.1.5](https://github.com/nanonigit/DragShelf/releases/tag/v0.1.5) as a prerelease with ZIP and checksum. Updated [homebrew-DragShelf](https://github.com/nanonigit/homebrew-DragShelf) to v0.1.5; the local tap fast-forwarded, `brew audit --cask nanonigit/dragshelf/dragshelf` passed, and `brew fetch --cask nanonigit/dragshelf/dragshelf` retrieved the archive.
- Final installed state: `/Applications/DragShelf.app` v0.1.5 is running from the simulated login launch with `--login-start`; the Agent remains configured and its last exit code is 0. The app reports Input Monitoring not granted after this ad-hoc update; the AppKit fallback remains active.
