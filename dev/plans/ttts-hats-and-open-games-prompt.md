# PALISADE — Tung Tung Tung Sahur headgear + Open Games visibility work order

**Status: prompt prepared September 30, 2026.** This is a development work order, not authorization to publish or make live-service changes. Before editing, recheck the current GitHub `main`, working tree/recent commits, live footer, `dev/STATUS.md`, protocol, and any newer plan that supersedes this one. Do not rely on version numbers, commit SHAs, or deployment claims embedded in this document if the repository has moved on.

## Objective

Address two independent client-side issues:

1. Allow exactly eight existing headwear items to be worn by Tung Tung Tung Sahur (skin id `sahur`) and make their placement visually correct.
2. Diagnose and, if proven necessary, fix the v0.9.5-era **OPEN GAMES** list being invisible/empty after the menu overhaul.

Keep the two tracks independently reviewable and reversible. Do not use either issue as a reason to refactor unrelated systems.

## Repository and standing rules

Repository: `lopoke89-ops/palisade`

Before editing:

- Read `dev/STATUS.md` and this work order.
- Recheck `main`, the live version/footer, protocol string, and recent commits.
- Inspect the current source before assuming any function, selector, ID, or layout still exists.
- Preserve newer work. If the current implementation differs materially from the assumptions below, adapt the work order to the actual code and document the difference before editing.
- Source is under `dev/src/`.
- Build through the repository's normal build script (currently `python dev/build.py`, unless the current README/STATUS says otherwise).
- Never hand-edit generated `index.html`, `sw.js`, or other generated output.
- Do not change Supabase data, migrations, reward RPCs, economy, player balances, or live configuration.
- Do not bump the network protocol unless a genuine packet-layout/meaning change is demonstrated. This work should normally require **no protocol change**.
- Do not push, merge, publish, or deploy. Leave commit/push to Big U.
- Keep changes small and easy to revert.
- If a requested behavior already works, do not rewrite it; add only the missing compatibility/layout/fit work.
- If evidence contradicts the requested diagnosis, fix the actual proven cause rather than forcing the requested implementation.

## Read first

At minimum inspect:

- `dev/STATUS.md`
- `dev/COSMETICS_V0935_CHECKPOINT.md`
- `dev/src/js/18-cosmetics.js`
- `dev/src/js/16-characters.js`
- `dev/src/js/19-accounts.js`
- `dev/src/js/19b-social-lobby.js`
- `dev/src/page.html`
- `dev/src/style.css`
- `dev/test/cosmetics_expansion.js`
- `dev/test/headgear_fit.js`
- `dev/test/lobby.js`
- `dev/test/multiplayer.js`
- `dev/test/menu_audit.js`

Also inspect any newer files/tests that replaced these paths.

---

# Track A — Eight hats on Tung Tung Tung Sahur

## Goal

These existing headwear IDs must be selectable, saved, previewed, networked, and rendered correctly on skin `sahur` in:

- Locker
- lobby stage
- solo gameplay
- co-op gameplay
- PvP gameplay
- mid-match snapshots / remote-player rendering
- downed presentation where the existing headgear pipeline renders it

Allowed Sahur hats — **exactly these eight**:

| Display name | ID |
|---|---|
| Crown | `crown` |
| Top Hat | `tophat` |
| Cyber Visor | `visor` |
| Neon Headband | `headband` |
| Police Cap | `pcap` |
| Halo | `halo` |
| Witch Hat | `witch` |
| Devil Horns | `devilhorns` |

Do not create duplicate hat IDs or new cosmetic catalog entries.

## Compatibility rules

Audit the actual current `headwearAllowed()` implementation and every caller that can suppress/equip/render headwear.

Change only the Sahur compatibility rule so that:

- the eight IDs above are allowed on Sahur;
- every other non-class hat remains blocked on Sahur;
- blocked hats remain owned and must not be silently deleted;
- a blocked saved hat must remain saved and become usable again when the player switches to a compatible skin;
- preserve the existing **Class Issue / EQUIPPED** behavior when a saved hat is temporarily suppressed;
- preserve existing special-head restrictions for Demon, Sheet Ghost, Reaper, Phantom, wraps, sack, hockey, clownface, ghillie, facewrap, and any other skin with built-in headwear;
- preserve Sheet Ghost's existing Halo-only rule;
- do not globally loosen headwear compatibility.

Do not assume the current list of special skins is unchanged: inspect the current catalog and compatibility code first.

## Sahur fit pass

Sahur is a continuous wooden silhouette rather than a normal human head. Existing human-oriented hat anchors therefore cannot simply be enabled without checking their geometry.

For each of the eight hats:

1. Place it on the log crown/brow so it reads as physically worn rather than floating above or sinking into the log.
2. Keep Sahur's painted face readable unless the item intentionally occupies the eye/brow region.
3. The Cyber Visor may cross/tint the eye area, but must not turn the face into an opaque black slab.
4. The Witch Hat brim must remain visually in front where appropriate and must not be defeated by face overdraw. Reuse the existing brim-depth/slice approach already established for the Boonie/Witch fix rather than inventing a parallel renderer.
5. Halo must sit clearly above the log, with intentional separation similar to the validated Sheet Ghost + Halo presentation.
6. Devil Horns must use the normal headwear item `o.horns` / `devilhorns` path. Do **not** give Sahur the Demon body's built-in horns, wings, tail, claws, or aura.
7. Preserve the existing weapon, muzzle, collision, movement, downed-pose, and cached Canvas-frame architecture.
8. Do not add a new per-frame animation layer solely for these hats.
9. Ensure Locker thumbnails and other preview tiles frame the entire hat without cropping it.

### Transform rule

If a hat needs a Sahur-specific offset, scale, rotation, or depth adjustment, make it conditional to Sahur.

Do **not** globally move/restyle the hat for ordinary skins just to make it fit Sahur.

Keep the number of special-case transforms minimal and document why each is needed.

## Visual validation

Check all eight hats at:

- 8 aim angles
- all existing relevant walk phases
- idle
- downed pose where supported
- gameplay scale
- Locker/preview scale
- at least one remote/network-rendered presentation

Look specifically for:

- floating
- sinking/clipping
- face obstruction
- brim depth errors
- side-angle drift
- thumbnail cropping
- inconsistent scale
- incorrect depth ordering
- accidental use of Demon-specific geometry

## Track A tests/evidence

Run or extend the focused tests relevant to the actual changed paths, including where applicable:

- `cosmetics_expansion`
- `headgear_fit`
- `wardrobe3d`
- `locker_fit`
- `presentation_posefit`
- `cosmetic_network`
- `cosmetics`

Update the compatibility matrix so all eight Sahur combinations are explicitly tested while representative blocked hats remain blocked.

Create a contact sheet/evidence set showing Sahur with all eight hats plus the Class Issue/default presentation at both game and Locker sizes. Store it under the current development evidence convention (normally `dev/evidence/<version-or-date>/`).

No protocol bump or migration should be necessary unless inspection proves a network field must change.

---

# Track B — OPEN GAMES / lobby list visibility

## Symptom

After the menu overhaul, **MULTIPLAYER → OPEN GAMES** may appear to contain no rooms even when hosts are publishing rooms.

The existing DOM/listing system must be investigated before any new UI is created.

## Expected architecture to verify

Do not assume these exact selectors/functions still exist; verify them first.

Historically the flow has been:

- MULTIPLAYER page contains the Open Games list (historically `#lobList`).
- `refreshLobbies()` reads the public lobby rows.
- Hosts publish periodically after opening a room.
- Lobby rows are filtered by the current protocol.
- A signed-in/account/cloud state affects publishing/browsing.
- Join controls are disabled when the local client cannot join or the room is full.

The current code is authoritative. Trace the actual current call chain from entering MULTIPLAYER through lobby browse/refresh and from HOST through lobby publishing.

## Investigate in this order

### 1. DOM/layout/clip

This is the first suspect after a menu-shell change.

At these exact viewport sizes:

- 1440×900
- 1280×720
- 390×844
- 844×390

Measure/inspect:

- the Open Games heading/container;
- the actual list element;
- computed width and height;
- visibility/display state;
- overflow and clipping ancestors;
- scroll containers;
- position relative to the phone bottom tab bar;
- whether the list exists and contains rows but is outside the visible region;
- whether a flex/grid child is collapsing to approximately zero height.

If the rows exist in the DOM but are clipped or below a non-scrolling region, fix the existing shell/layout.

Prefer a minimal layout correction such as:

- making the appropriate existing column scrollable;
- giving the multiplayer list container a real minimum/flexible height;
- accounting for the phone tab bar/safe area;
- correcting an overflow rule introduced by the menu overhaul.

Do **not** invent a second lobby list.

### 2. Browse initialization

Verify that entering MULTIPLAYER through every current navigation path still invokes the lobby browse/refresh initialization.

Check both:

- direct navigation to MULTIPLAYER;
- the current PLAY/MULTIPLAYER routing logic when already hosting or joined to a room.

Do not mistake the intended redirect into an active room for an Open Games failure.

### 3. Account/cloud state

Reproduce the relevant states separately:

- signed-in account with cloud available;
- guest/no account;
- account/cloud temporarily down;
- preview/offline mode if the current code supports it.

Determine whether the current UI correctly distinguishes:

- loading/connecting;
- unavailable cloud service;
- authenticated browsing;
- genuinely zero rooms.

Do not allow guests to publish fake public lobby rows merely to make the list non-empty.

### 4. Host publish path

Using the current implementation, verify that creating a host room with the public-list option enabled actually publishes a row.

Check:

- the current public-list preference;
- publish timing/retry behavior;
- current protocol value;
- host/session identity;
- row creation/update frequency;
- whether the row expires/disappears correctly.

If protocol filtering exists, use the **current** protocol from the live/current client rather than hard-coding an old value from this prompt.

### 5. Join state

If rooms render but their JOIN controls appear dead/disabled, treat that as a separate issue.

Verify:

- full-room behavior;
- already-hosting/already-joined behavior;
- current network mode;
- join button state;
- whether the room metadata is valid.

Do not loosen join restrictions just to make buttons clickable.

## Track B tests/evidence

Extend `menu_audit.js` or add a focused lobby visibility test that proves, at minimum:

- the Open Games container has non-zero visible dimensions at all four required viewports;
- it is not covered by the phone tab bar;
- entering MULTIPLAYER invokes the browse/refresh path;
- a mocked valid room can render as a visible row;
- a genuinely empty result produces the intended empty state;
- connecting/cloud-unavailable states remain truthful;
- existing join-disable rules remain intact.

If server listing behavior itself must be tested, use the repository's existing mock/PGlite/test setup rather than changing production server behavior.

Save representative screenshots or measurements under the current evidence convention.

---

# Explicit non-goals

Do not change:

- PeerJS room-code format
- network protocol semantics unless proven necessary
- Supabase reward RPCs
- case odds or case contents
- player balances
- skill-tree rules
- lobby privacy/listing meaning
- unrelated skins or headgear
- Demon cosmetics
- Sheet Ghost compatibility except preserving its existing Halo rule
- new game modes
- reward retry/rejoin systems
- identity/import systems
- tracer systems
- Halloween catalog rebuild
- generated build files by hand
- live migrations

---

# Definition of done

## Sahur

- All eight specified hats can be equipped on Sahur.
- They save and restore normally.
- They render correctly in Locker, lobby, gameplay, remote-player presentation, and supported downed views.
- Face readability, brim depth, halo separation, and horn identity are correct.
- Other skins' hat placement is unchanged except for unrelated fixes independently justified by tests.
- Non-approved hats remain blocked on Sahur.
- Existing special-skin restrictions remain intact.
- Focused cosmetic/fit/network tests pass.
- Evidence includes a clear Sahur eight-hat contact sheet.

## Open Games

- The existing Open Games list is visibly reachable on desktop and phone portrait/landscape.
- A valid current-protocol room can appear when actually published.
- A genuinely empty list displays a truthful empty state rather than looking broken.
- Connecting/cloud/account states remain distinguishable.
- No duplicate lobby UI was introduced.
- Existing join restrictions remain intact.
- Focused menu/lobby tests pass at all four viewport sizes.
- Evidence records the diagnosed root cause and the minimal fix.

## Final handoff

Before stopping:

1. Rebuild from source.
2. Run the focused tests for every changed path.
3. Review the diff for unrelated changes.
4. Update the relevant development status/evidence notes with what was actually changed and tested.
5. Do not push or publish.
6. Leave commit/push to Big U.

If either track cannot be completed safely without broader architectural changes, stop at the smallest useful diagnosis and document the blocker instead of expanding scope.
