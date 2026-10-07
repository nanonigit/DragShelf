# Login startup lessons learned

- Treat `SMAppService.Status.enabled` as registration state, not proof that launchd executed a helper.
- Validate the actual installed bundle, not a `dist` development copy, when testing login startup.
- An ad-hoc signature can pass `codesign --verify` yet fail a launch constraint. Check the launchd job, unified log, and process arguments.
- Preserve the user's opt-in preference during migrations; never create a login agent for a disabled setting.
- Keep release build numbers in sync and increment them, but do not treat a version bump as a substitute for runtime validation.
- Before marking login startup verified, load the job in a clean user session and confirm process launch and exit code. Request a real logout/login check for final acceptance.
