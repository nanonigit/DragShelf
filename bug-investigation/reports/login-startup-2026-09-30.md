# Login startup failure — 2026-09-30

## Symptom and environment

With **Launch at login** checked, DragShelf did not start after login. The affected installation was the ad-hoc-signed v0.1.4 app on macOS, installed at `/Applications/DragShelf.app`.

## Reproduction and evidence

1. The legacy `SMAppService` login item appeared registered and enabled.
2. `launchctl print gui/503/com.github.nanonigit.DragShelf.LoginItem` showed hundreds of attempts, `EX_CONFIG`, and `job state = spawn failed`.
3. After re-registering v0.1.5, `launchd` resolved the exact helper path but logged `OS_REASON_CODESIGNING | Launch Constraint Violation`; `amfid` identified the helper as ad-hoc signed.
4. A separate development copy in `dist/DragShelf.app` was also running during diagnosis; it was stopped before the installed app was tested.

This is a real startup failure, not merely the intentional absence of a management window during quiet login launch.

## Resolution and verification

The enabled legacy service was migrated to a per-user LaunchAgent invoking Apple's `/usr/bin/open` on `/Applications/DragShelf.app` with `--login-start`. The legacy service was unregistered. `launchctl bootstrap` then exited successfully, and the main app started from `/Applications` with `--login-start`; the agent reported `last exit code = 0`. An actual logout/login has not yet been observed.
