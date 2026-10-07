# Fix log: login startup

1. Corrected the nested helper's main-app bundle identifier and added failure logging.
2. Added `LoginLaunchAgent`, which writes and removes only DragShelf's per-user LaunchAgent plist. The job runs `/usr/bin/open -a /Applications/DragShelf.app --args --login-start` at login.
3. On installed-app launch, migrated an enabled legacy `SMAppService` item to the new agent and unregistered the failing service. Disabled users remain opted out. Management now reports the new configuration and any migration error.
4. Increased both bundled `CFBundleVersion` values to `5` and made packaging reject app/helper version mismatches.
5. Added unit tests for agent creation, path refresh, and removal. All 19 tests passed.
6. Installed the build at `/Applications/DragShelf.app`. `launchctl bootstrap gui/503` started the app with `--login-start`, and the new job reported `last exit code = 0`; the old service was absent.

Limit: This simulates the user-session startup path; an actual logout/login has not yet been performed.
