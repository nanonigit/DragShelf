# Duplicate shelf after changing placement

Date: 2026-09-29. Status: root cause identified; code fix verified for duplicate launch. A physical drag with the new installed build remains to be checked.

## Reproduction and evidence

The user changed the shelf from near-drag to left-bottom and saw one shelf at each position. At inspection, two DragShelf processes were running: the installed `/Applications/DragShelf.app` and the development `dist/DragShelf.app`. The stored preference was `leftBottom`, while the installed process still showed near-drag in its management popup. `ShelfController` creates only one panel per process and repositions that same panel when placement changes.

Timeline: v0.1.2 installed app and development bundle both running → placement changed in one process → two processes displayed independent panels at different positions → development process terminated → one installed process remained. The new startup guard was tested by launching the development bundle again; it exited and left only the installed process.

## Five Whys

1. Why were there two shelves? Two DragShelf processes each owned a panel.
2. Why were two processes running? The installed and development bundles were both launched.
3. Why did they remain active? The app had no cross-process duplicate guard.
4. Why were the panels in different places? Each process cached its placement on launch; changing one did not update the other.
5. Why could the development copy interfere with the installed copy? `dist/DragShelf.app` is a runnable bundle with the same identity and previously had no single-instance check.

## Repair and prevention

The immediate repair was stopping only the development process. The code now exits a later-launched duplicate and asks the existing instance to reopen management. A regression check launches `dist/DragShelf.app` while `/Applications/DragShelf.app` is running and verifies that only one process remains. Placement now offers all four corners and near-drag, with geometry and raw-value compatibility tests. Do not claim the physical drag case passes until repeated by hand on the installed build.
