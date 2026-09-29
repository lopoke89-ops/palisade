# PALISADE — Locker collections and Milestones UI

**Execution status:** Implemented as a local, uncommitted v0.9.3.3 candidate. Focused checks and phone/desktop viewport inspection passed; see [validation](../LOCKER_UI_2026-09-29.md). The original scope follows. Publication and physical-device checks are still pending.

**Task:** Improve the Locker's cosmetic browsing without changing unlocks, case odds, rewards, account data, or gameplay. The verified published baseline is v0.9.3.2 at GitHub commit `39ec2b4`. Before editing, check the actual current commit, live version, and working tree; preserve the existing uncommitted release-status documentation. If v0.9.3.2 is still the latest release, use v0.9.3.3 for this patch. Do not silently fold it into v0.9.3.2.

## Desired player experience

The Milestones tab should be the **only** place milestone cosmetics appear. Keep its ladder headings, progress counts, rarity, locked/owned states, previews, and equip actions. Remove milestone items and the duplicate MILESTONES section from SKINS, HEADGEAR, TRACERS, KILL FX, and BACKGROUNDS. An item must not disappear from the catalog or lose an unlock just because its browsing location changes.

Within each ordinary category, keep free and other non-case cosmetics easy to find at the top. Group cosmetics from each case into a clearly labeled, independently collapsible collection using the existing `CASES` and `COS` metadata. This includes Supply, Afterglow, Halloween, and Flag collections where that category has items from them. Do not show an empty collection. Start case collections collapsed to shorten the initial page; opening one must reveal its items in their existing stable order, and opening a second must not close the first. Preserve each collection's open/closed state while switching Locker categories or equipping an item during the current visit. A fresh visit may reset the sections; do not add a new browser-storage key solely for this preference.

Each collection header should show its case name and a useful count such as owned/total for the selected category, plus a clear expand/collapse indicator. Use a real button with `aria-expanded` and `aria-controls`, visible keyboard focus, and an accessible label. Keep touch targets comfortable on a phone. The expanded item grid must retain the existing rarity, ownership, progress where relevant, preview, and equip feedback. Do not create canvases or queue thumbnail renders for collapsed items; expanding a collection should populate only that collection, without a conspicuous stall. Avoid rerendering unrelated collections when an item is equipped if possible, and preserve the user's scroll position and keyboard focus.

The case inventory and OPEN/BUY controls in the separate `#caseBoxes` panel are **not** the case collections being collapsed. Leave those controls visible and preserve their counts, disabled states, purchase/open flows, and account-backed behavior. Preserve the live character preview and the existing six category tabs. Check the tabs and collection headers at phone portrait, phone landscape, and desktop widths; the new layout must avoid horizontal overflow, cut-off labels, and excessive blank space.

## Implementation guidance

Inspect `dev/src/js/20-locker-ui.js` (`renderLocker`, `itemTile`, `lockCat`, and thumbnail scheduling), the Locker markup in `dev/src/page.html`, and the responsive rules in `dev/src/style.css`. The current `renderLocker()` inserts milestone items into ordinary category lists and renders every case section fully expanded; fix that shared grouping logic rather than hardcoding item IDs. Use `c.ladder` / `c.box`, `CASES`, `CASE_IDS`, and `LADDERS` as the source of truth so future cases and milestone ladders follow the same rules. Keep generated `index.html` and `sw.js` in sync through the normal build. Preserve stable element IDs, save formats, cloud equip calls, case-result routing, and the CSP build.

Decide how ordinary items are labeled if more non-case unlocks are added later. Keep the visual treatment consistent with PALISADE's current Locker, and use simple disclosure behavior without an animation that costs phone frames. Honor reduced-motion settings if an animation is used.

## Acceptance checks

1. Across all five ordinary categories, no item with `c.ladder` is rendered; all milestone cosmetics remain present and usable in MILESTONES, including locked progress and equipped state.
2. Every nonempty case collection in a category has one accessible header. It starts collapsed, can be toggled by mouse, touch, Enter, and Space, and multiple collections can stay open.
3. Switching categories or equipping an item does not unexpectedly close the user's expanded collections or jump the scroll/focus position. A case result's EQUIP action still takes the player to the appropriate category and makes the newly equipped item discoverable, including when its collection was collapsed.
4. Free/non-case items, case counts, OPEN/BUY actions, account-backed equip, and saved ownership remain correct. No reward, drop-rate, server, or account schema changes are needed.
5. Phone portrait/landscape and desktop screenshots show shorter initial lists, readable collection headers, no clipping or horizontal scroll, and a responsive expanded grid. Collapsed collections do not trigger thumbnail work.

Run only focused checks relevant to this UI change: Locker/cosmetic and milestone/Flag catalog tests, an account-equip smoke if the equip path changes, keyboard/accessibility interaction checks, and phone/desktop visual captures. Add or adjust one meaningful regression test for grouping and disclosure behavior; do not run weapon or full-suite tests unless a shared change or failure justifies them. Compare Locker rendering cost on a phone-sized viewport if the disclosure implementation changes thumbnail scheduling. Report the exact tests run, what remains unverified on a physical device, and before/after screenshots.

Update `dev/STATUS.md`, the current blueprint, and both READMEs with the actual outcome and release number. Keep the implementation local and reviewable; do not push, deploy, or change Supabase as part of writing or executing this prompt unless Big U separately authorizes publication.
