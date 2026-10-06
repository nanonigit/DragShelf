# DragShelf implementation tasks

## Quick Look

- [x] Add native Quick Look responder lifecycle and click-to-focus keyboard handling without a global keyboard monitor (click accepted by the user).
- [x] Test both layouts, control/empty/missing exclusions, scroll/mutation and repeat/modifier filtering. Native lifecycle needs an app-hosted runner or installed-app verification.
- [x] Build/install `/Applications/DragShelf.app` and verify click Space in list/icon views, Space-close and Escape-close on the final release build.
- [ ] Physically verify keyboard focus returns to another app when leaving the shelf, plus full-screen and multi-display preview behavior.
- [ ] Update English/Japanese usage notes and publish source, release, and Homebrew cask.

## Phase 1

- [x] Record requirements and design before implementation.
- [x] Build a pure detection state machine and behavioral unit tests.
- [x] Build a passive event monitor and drag-pasteboard metadata probe.
- [x] Create a nonactivating shelf panel registered as a drop destination.
- [x] Build and launch a real `.app` bundle.
- [x] Request Input Monitoring through macOS once at launch if not yet granted; retain menu retry and monitor refresh.
- [x] Verify the build and unit tests and stage the updated app without quitting the running shelf.
- [ ] Observe the macOS consent prompt and approval on a subsequent app launch; confirm monitor transitions to the event tap.
- [ ] Manually verify Finder drag start, reveal, same-drag drop, and no source move.
- [ ] Exercise negative and permission-denied cases; record observations in `verification.md`.

## Phase 2

- [x] Park and render multiple file/folder entries in the initial list.
- [x] Add asynchronous Quick Look thumbnails with a safe icon fallback.
- [x] Add persistent list/icon views, scrolling, and layout hit-testing tests.
- [x] Narrow the shelf to 160 points, change icon view to one column, remove the title, add a gear to open management, and add a persisted transparency slider.
- [x] Add persistent left-bottom/right-bottom/near-drag placement with geometry tests.
- [x] Hide the panel on last-item removal; preserve an empty in-progress drop target.
- [x] Replace ambiguous menu status with permission and active-detection facts; add show/hide and management actions.
- [ ] Make the permission menu open System Settings when ungranted, and verify the click produces visible feedback. (Code built; direct click still needs manual confirmation.)
- [x] Open a management window from normal app launch and reopen, with per-item removal.
- [x] Add opt-in login launch through a nested helper, bundle signing, and truthful status/error UI.
- [x] Install a generated app icon and verify it in the packaged app.
- [ ] Drag a parked file to Finder and an accepting app.
- [ ] Verify Spaces, full screen, and multiple displays.

## Distribution

- [x] Initialize a dedicated Git repository and publish it publicly on GitHub.
- [x] Write and verify a bilingual English/Japanese README and release limitations.
- [x] Build and inspect a versioned release archive, checksum, and signing/Gatekeeper status.
- [x] Publish a GitHub Release with honest installation caveats.
- [x] Publish a dedicated Homebrew tap and validate its cask locally.

## Management consolidation and history

- [x] Persist file references across restarts with bookmark/path recovery and tests.
- [x] Add a selectable 5/10/25/50/100 item limit; trim oldest references without touching source files and test both addition and limit changes.
- [x] Consolidate persistent preferences and permission/login controls in management; leave only immediate actions and concise status in the menu bar.
- [x] Add a persisted menu-bar icon visibility toggle in Settings and verify that normal app reopening restores access to Settings when the icon is hidden.
- [x] Put Settings first and select it on initial management opening; verify both tab order and selection in the installed app.
- [x] Offer five shelf placements (all four corners plus near-drag), with geometry and persistence tests.
- [x] Enforce one running DragShelf instance across installed and development bundles; verify that launching the second copy creates no second shelf.
- [x] Allow both Dock and menu-bar icons to be hidden and verify cold-launch recovery from Applications.
- [ ] Independently verify reopening management from Applications while the iconless app is already running and its management window is closed.
- [x] Add and persist a Dock icon visibility checkbox in Settings, handle AppKit policy-switch failures, and test the management recovery path while hidden.
- [x] Tested the former v0.1.2 last-visible-icon guard; superseded by the user's later request to permit both icons hidden.
- [x] Mark missing source files and prevent dragging a missing URL out.
- [ ] Rebuild `/Applications/DragShelf.app` and verify the management settings and restored items before publishing release/tap. (Build/install and UI checked; real-file restoration still needs a physical drag.)

## Phase 3

- [x] Replace the ad-hoc-signed login helper with a per-user LaunchAgent and migrate enabled legacy registrations. Verify `launchctl bootstrap` starts `/Applications/DragShelf.app --login-start` with exit code 0.
- [ ] Confirm automatic startup after a real logout and login on the user's Mac.
- [x] Increase gear and remove-control contrast on the shelf, enlarge the remove target, and install the build.
- [ ] Visually verify both controls with parked files in icon and list modes at reduced shelf opacity.
- [ ] Add promised files, images, text, and URLs one at a time with integration checks.
- [ ] Add preferences, accessibility, and launch behavior.
- [ ] Perform a clean-build and real interaction pass before release.
