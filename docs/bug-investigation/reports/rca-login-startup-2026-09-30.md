# Root cause analysis: login startup

## Timeline

- v0.1.4: The user enabled login launch, but the app did not appear after login.
- 2026-09-30: The registered job showed repeated `EX_CONFIG` spawn failures.
- Re-registration: LaunchServices found the helper, but `launchd` rejected it with `OS_REASON_CODESIGNING | Launch Constraint Violation`.
- Replacement: A user LaunchAgent invoking `/usr/bin/open` started the installed app with `--login-start` and exited 0.

## Five whys

1. Why did DragShelf not start? The login job could not launch its helper.
2. Why not? macOS rejected the helper at process launch.
3. Why? The helper was ad-hoc signed, which did not satisfy the managed job's launch constraint on this Mac.
4. Why did the release use that job? The app used `SMAppService.loginItem` despite having no Developer ID signing identity.
5. Why did this reach the user? Verification checked registration and bundle signing, but not a real launchd execution. Keeping `CFBundleVersion` at `1` across updates also made stale registration harder to detect.

## Contributing factors

- Signing: no Developer ID identity; `codesign --verify` succeeded but was insufficient for Service Management launch constraints.
- Registration: macOS displayed the job as enabled even when launchd could not execute it.
- Development copies: an old `dist` process could be mistaken for the installed app.
- Helper code: its main-app identifier did not match the actual bundle identifier. This was a separate defect, not the signing rejection.

## Preventive gate

For ad-hoc releases, keep the LaunchAgent fallback and test `launchctl bootstrap` plus the resulting app process and exit code. A user-confirmed logout/login remains required before claiming full login acceptance.
