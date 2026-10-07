# Language popup title mismatch

## Evidence and reproduction

Installed candidate, native AppKit UI: select 日本語 with History Limit set to 25. Accessibility reported 25 件 and the selection index remained 2, but the screenshot rendered 5 件. No history preference or file reference was changed. The first integration test also incorrectly searched for Settings labels in the window hierarchy after selecting Parked Items; NSTabView detaches inactive tab views.

## Timeline and 5 Whys

1. Core preference/catalog tests passed; integration selection-preservation tests passed after fixing the inactive-tab lookup.
2. Native switching exposed a visual mismatch missed by selection-only assertions.
3. Why the wrong visible count? The popup cell displayed a renamed first item's title.
4. Why was the selected count still correct? The selected NSMenuItem and displayed cell title are distinct AppKit state.
5. Why was the cell not refreshed? Titles were changed individually with no final synchronization.
6. Why did tests miss it? They asserted selected indices, not rendered cell titles.
7. Why retain individual menu items? To preserve selected values without rebuilding UI or firing settings actions.

## Repair and prevention

Centralize popup updates, retain the selected index, replace only the menu items, reselect and call `synchronizeTitleAndSelectedItem()`. Reselecting and synchronizing alone did not fix the native rendered title after changing language, despite passing cell-title assertions. Keep popup controls and all setting values intact. Continue native screenshot checks because accessibility and cell-title state alone do not prove visible text. Initial zero-sized tab geometry warning was separately prevented by giving the retained tab view a nonzero initial frame.

Further native checks showed that neither deferred menu updates nor rebuilding menu items reliably fixed the English count label. Replacing the popup control fixed the Japanese display, but the English label could still become stale. Final repair: use a language-independent 5/10/25/50/100 segmented selector for history; translate the row label, not the choices. This removes the problematic translated popup title and makes the selected limit visible without opening a menu. The retained control is checked for selection persistence in tests. Display/placement popup controls are refreshed with the previous selection configured before attachment. Native verification results are recorded in verification.md.
