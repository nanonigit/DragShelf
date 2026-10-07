# Language popup repair

- Reproduced a rendered history-limit title mismatch during native language switching, despite correct selected-item and accessibility state.
- Retitling, synchronizing, and deferred menu updates were insufficient in native checks.
- Replaced the history dropdown with a language-independent segmented selector. Configure translated display/placement popup controls before attachment; defer language updates until after the selection action.
- Final validation: 28 tests passed, 1 existing Quick Look test skipped; release build and ad-hoc signature verification passed. Native English/Japanese screenshots confirmed the selected 25 segment, 25→50→25 worked, Help opened, and restart retained the language. See verification.md.
- Prevention: keep native screenshot checks alongside semantic UI assertions; test both translation directions, state preservation, and the active small-window scroll layout.
