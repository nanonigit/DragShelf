# DragShelf requirements

## Goal

Provide a temporary drop shelf for dragging files between macOS windows, Spaces, and full-screen apps. The decisive behavior is showing a usable drop target while a drag started in another app is still in progress.

## Phase 1: feasibility gate

- Observe a drag begun in another app without changing its event stream or activating DragShelf.
- Show the shelf on the display containing the pointer after a supported drag begins, early enough to receive the same drag.
- Do not show it for ordinary window movement, selection, or a stale drag pasteboard.
- Accept Finder file URLs through standard AppKit drop handling. The source file must remain at its original path after parking.
- If automatic observation is unavailable, leave a manual shelf affordance available and explain the permission state.
- On normal app launch, check Input Monitoring access and ask macOS for it once when missing. Never request again from the polling timer, and never imply that the app can grant access itself.
- If the user selects the permission menu while access remains absent, open the relevant macOS System Settings pane; a repeated OS request alone may be silent.
- Record repeatable results for Finder, Safari, text selection, full screen, and multiple displays; do not claim unsupported cases as verified.

## Phase 2: usable file shelf

- Park multiple files and folders, display their names/icons, remove individual entries, and drag entries to another app.
- Show a useful content preview where macOS can generate one, with a file icon fallback. Let the user switch between compact list and larger icon views; preserve the choice across launches.
- Keep the shelf narrow (about half its initial 320-point width); do not waste horizontal space in icon view. Remove the shelf title and provide a gear control that opens management.
- Let the user adjust shelf transparency from management, preserve the setting, and retain enough opacity for legibility.
- Keep the shelf's gear and per-item remove control clearly visible over dark and light previews, including at reduced shelf opacity.
- Offer left-bottom, left-top, right-bottom, right-top, and near-drag shelf placement choices. Show exactly one shelf at the selected location, clamp it to the pointer's display, and preserve the choice across launches.
- Prevent a second DragShelf process, including a development bundle, from showing another shelf while one instance is already running.
- Hide the shelf immediately when the last parked item is removed with its remove control. An empty shelf revealed during an active drag must remain usable until that drag ends.
- Show the actual monitor mode in the menu rather than claiming the app is waiting for Input Monitoring when a fallback monitor is active.
- Provide explicit show and hide actions in the menu bar and a management view where parked items can be reviewed and removed.
- Opening the app from Applications or an app launcher shows the management window, including on an already-running app. Hiding the shelf must not remove access to this window or hide the menu-bar item.
- Login-time automatic launch must stay unobtrusive; it should start the shelf service without unexpectedly opening the management window.
- Offer an opt-in launch-at-login toggle backed by macOS login-item registration, and show the actual registration/approval state rather than assuming it succeeded.
- Give the app an original, legible macOS icon in the bundle and menu-bar affordance.
- Keep the panel nonactivating and accessible across Spaces. Hide it when empty and a drag ends; keep it visible when it contains items.
- Support a menu-bar Show Shelf action. Do not move or delete original files when parking.

## Phase 3: polish

- Keep the menu-bar menu short: open management, show/hide shelf, truthful drag/permission status, and quit. Move persistent choices (display mode, placement, transparency, login launch, and history size) into the management window. The permission status must still offer a clear path to System Settings when permission is absent.
- Let the user show or hide the menu-bar icon from Settings, retain the choice across launches, and keep a reliable way back through the Applications/Dock launcher or shelf gear. Hiding the icon must not stop drag monitoring or remove the shelf.
- Add a Settings choice for showing the app icon in the Dock. Preserve the choice across launches, apply it without interrupting parked items or monitoring, and report the actual applied state. Keep a tested route back to management when the Dock icon is hidden.
- Allow both Dock and menu-bar icons to be hidden, while retaining a verified management recovery path by reopening DragShelf from Applications. Explain this path beside the controls.
- Put the Settings tab to the left of Parked Items and select Settings on a fresh management-window launch.
- Persist parked file references locally so the shelf contents reappear after app restart. Do not copy file bytes or change the originals. Let the user choose the maximum retained item count in management; when exceeded, remove oldest references first, without deleting source files. Explain that moved/deleted files may no longer be available.

- Validate full-screen and Stage Manager behavior across supported macOS versions.
- Add promised files, images, text, and URLs after each type has an end-to-end import and export test.
- Refine placement, size, startup behavior, and accessibility.

## Scope and release gates

- Publish this app as its own public Git repository, not as part of the parent Wav2Vec2 repository.
- Provide English and Japanese README instructions, including permissions, current limitations, and tested behavior.
- Publish a versioned GitHub Release and a dedicated Homebrew tap only with an accurate explanation of code-signing and Gatekeeper limitations. Do not claim notarization without a Developer ID certificate and successful notarization.

- Phase 1 is an experiment. Passing a build or unit test alone does not prove cross-app drag detection; a real Finder-to-shelf drag is required.
- Prefer supported AppKit/Core Graphics APIs. Never use private drag-session APIs.
- The app should inspect pasteboard *types* for detection and read item content only after the user drops onto the shelf.
