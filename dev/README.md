# PALISADE: developer folder

Everything needed to rebuild, test and restore the game. The playable site is the repo's top
level (built from here); this folder is the source.

```
dev/
  src/                  the game's source, in pieces (edit these, never the built index.html)
    page.html           the page: menus, HUD and overlay markup
    style.css           all the styles
    js/01-...22-*.js    the game script, in order (js/ORDER.txt says what each file holds)
  assemble.py           joins src/ back into one file (build.py uses it)
  build.py              builds the site into the repo root
  audio/                music, AAC (.m4a) and Opus (.ogg)
  vendor/               PeerJS 1.5.5 and the two fonts (bundled so builds work offline)
  test/                 browser tests + run_all.sh
  supabase/schema.sql   restore script for the server (tables, rules, functions, case data)
```

## Source layout

The game is one script split across `src/js/`, joined in file-name order. It all runs in one shared scope,
so a file can use anything defined in an earlier one (and functions from any file). Keep the order: a
`const` used at start-up must come from an earlier file. New files slot in by number (e.g. `13b-...js`).
`python3 dev/assemble.py out.html` writes the joined source if you want to read it in one piece.

## Build

Needs Python 3 and Pillow (`pip install pillow`, for the icons).

```
python dev/build.py
```

It writes index.html, sw.js, the icons, manifest, fonts, PeerJS and music into the repo root and
gives the offline cache a new version name, so players pick the update up on their next load.

## Test

Needs Node 18+ and Python 3.

```
cd dev/test
npm install
npx playwright install chromium
./run_all.sh
```

Profiling: `NOMIN=1 python3 dev/build.py` keeps debug.html unminified (readable function names), and
`node stress.js` measures the heavy cases (Endless raid 20, a 6-player boss raid, 6 players in Endless
raid 20, and memory over a 30-minute Endless run); `PROFILE=1` adds the busiest functions.
`bench.js` is the quick frame-time check; `PORT=8083 PAGE=index.html node bench.js old` measures another copy.

It serves the built site on localhost:8080, starts a PeerJS server on :9000, runs every test and
prints PASS or FAIL for each; logs and screenshots go to `dev/test/out/`. The account and reward
tests fake Supabase, so they don't touch real players.

## Publish

1. Build, then test.
2. Open GitHub Desktop: the changed files show up. Write a summary (for example "v0.8.6: ...").
3. **Commit to main**, then **Push origin**. GitHub Pages is live about a minute later.

## Rules that keep saves and online play safe

- Never rename the `palisade.*` browser storage keys; that wipes players' local saves.
- Change `PROTO` (src/js/21-online.js, with `ROOM_PREFIX`) whenever the network messages change, so old and new
  copies refuse to join each other instead of breaking.
- Versions: patch bumps (v0.8.5, v0.8.6...) unless a change is major. The version appears in the
  main menu footer.
- The Supabase key in the game is the public "publishable" key. The secret key never goes in
  this repo.

## Server (Supabase project puvjfhwxigxjpsvdwrwf)

`supabase/schema.sql` rebuilds the server side in an empty project (SQL editor, run once). It
does not include player data, the blocked-words list, or Auth settings: anonymous sign-ins must
be on, and email needs custom SMTP.

## Music

Two tracks, each as AAC (.m4a) and Opus (.ogg) in `audio/`: `between_raids` (co-op/Endless build
phases) and `locker` (the Locker page). To replace one, encode both formats from a WAV under the
same name and update its loop length (in samples) in `MUSIC` inside src/js/03-audio.js. A new
track = a new entry in `MUSIC`, its name in `MUSIC_FILES` in build.py, and a case in `musicWant()`.

```
ffmpeg -i track.wav -c:a aac -b:a 160k -movflags +faststart between_raids.m4a
ffmpeg -i track.wav -c:a libopus -b:a 128k between_raids.ogg
ffprobe -v error -select_streams a -count_packets -show_entries stream=duration_ts track.wav   # loop length
```

## Debug copy

The build also writes `debug.html` (not committed): the same game with the test hooks
(`?debug=1` exposes `window.__pal`) and the profiler. The tests use it; players get index.html,
which has neither. Minifying needs terser (`npm install` in dev/test installs it).

## Multiplayer identity and saved players (v0.8.13)

The lobby uses the authenticated profile username and the existing locker. Saved players are a
one-way account list, stored as up to 50 profile UUIDs in the signed-in user's
`user_metadata.palisade_saved_players_v1`. The client updates only this metadata field through
`/auth/v1/user`; no social database tables or locker migrations are required. Profiles are read
through the existing authenticated profile policy. Room labels and Join actions use fresh,
publicly listed lobbies for the current protocol; no listed room is not an offline indicator.

Each metadata edit re-reads the current user before saving. Account identity and request sequence
checks discard stale results after account switches. The social regression covers saving, reload,
failed writes, metadata preservation and account isolation with a mock backend.

Protocol yard-13 adds a lobby-only `loadout` message so returning from the locker updates the
party roster and next match. Old and new clients use separate room prefixes and must reload to
play together. `multiplayer.js` verifies host/guest loadout propagation before match start.

## v0.9.0: maps, new bosses and raiders, the lobby

- **Maps** (`src/js/06b-maps.js`). Each map is data plus a `lay()` that places the stake, piles, ruins,
  terrain, raider entry tiles and boss spawns. Terrain is one byte a tile: ground, water (half speed, no
  building), bridge, low bank (floods on Riverbend from raid 3), cracked (a blast of power 1.2 or more,
  such as a satchel, turns it into a pit), pit (can't walk or build), rock and oil drums (solid, stop bullets).
  Maps: the Yard, Riverbend, Ashfall Quarry (always night). Boss order per map is `MAPS[..].bosses`.
- **XL** is 24×24 (`N` is no longer a constant). The 16×16 layout sits near the south-west corner and XL
  adds piles and ruins in the new ground; raids are about 40% bigger. PvP stays 16×16 on the Yard.
- **Bosses**: the Ferryman (Riverbend) and the Foreman (the Quarry) sit beside the Demolisher, Butcher
  and Stormcaller in `BOSSES`. In October the host's clock turns the Butcher into the Pumpkin Butcher (same fight).
- **Raiders**: shieldbearer, field medic, spotter, firebrand. The before/after wave table is printed by `v090.js`.
- **Cases from bosses**: the Butcher and the Ferryman drop a Halloween Case (two from the October Butcher);
  the others an Afterglow Case. The client sends `boss_keys`; the server caps them by raids held.
  **`supabase/v0.9.0-migration.sql` must be run when v0.9.0 is published** (not before): it adds the
  Halloween Case, the `bg` cosmetic category and its items, the free backgrounds for every locker, and the new
  `claim_match_reward`. Older clients still work (no `boss_keys`: bosses pay Afterglow Cases as before).
- **Lobby**: one shell (the v0.8.13 party stage) for PLAY, MULTIPLAYER and CLASSES, with the nav bar on every
  menu page. PLAY has the map picker and size. Backgrounds (`18b-backgrounds.js`) are Locker items
  (cat `bg`, never sent to other players) drawn on `#lobbyBg` behind every menu page (the old live-yard menu scene is gone).
- Protocol **yard-14**: start/lobby messages carry map, size and the October flag; snapshots carry terrain
  changes (`tr`), the flood (`fo`), bosses that fell (`bl`) and a kind per thrown object (lobs have 8 numbers).
- Tests: `lobby.js` (menus, online map sync), `v090.js` (maps, bosses, raiders, rewards, wave table),
  `v090_net.js` (host/guest).
