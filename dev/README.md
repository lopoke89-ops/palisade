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

## v0.9.1: playtest fixes

- **Lobby shell v2.** PLAY is now **SOLO**. One map panel (`#mapPanel`, `renderMapPanel`) sits in the right column
  of SOLO, MULTIPLAYER and the room, in every mode; PvP hides the size (always 16×16) and guests see the host's
  pick without being able to change it. The Locker (cases left, your figure on the shared stage, tabs and grid
  right; `#lockPrev` is gone), Settings (grouped cards; still opens from the pause menu over a running game) and
  Account (a profile header, the forms as cards) all live in the same shell (`STAGE_PAGES`, `CARD_PAGES`).
- **Stage renderer** (`16-characters.js`). A `WEAPON_TABLE` (butt, grip, fore-end, stock/receiver sizes, barrel
  radius per gun) builds every held gun, and a two-bone `reach()` puts the hands on the grip with the elbows bent
  down and out, so the gun is held clear of the chest. The muzzle measurement reads the same table (`muzzle.js`
  passes). The lobby figure turns in 2° steps on its own layer (`#partyMe`), repainted only when the pose changes
  (at most 30 fps); the idle bob is a stepped CSS transform. Up to six figures stand on the stage (you in front,
  the others about 60% size with name plates; phones: three in front, two behind).
- **One job-change routine** (`changeClass`): new gun, ammo, grenades and health; kills, deaths, score, salvage,
  slot, team, upgrades and cosmetics stay. Each player's network state has an `ab` slot for future class
  abilities (always 0 for now). Job buttons in the room (`#lJobs`, the `loadout` message); in Free-for-all the
  pause card and the respawn bar pick the job for your next life (`nextcls` → applied on respawn).
- **Structured rewards.** `lockerReward`, `pvpReward` and `claimReward` return `{cases, shards, unlocked (ids),
  toNext, prog, text}`; the after-action screen shows reward cards (cases, a shard counter, UNLOCKED cards with the
  Locker thumbnails, the bar to the next Supply Case) over ~1.5 s; a tap skips.
- **Friends** (server + a dropdown on the account badge). Requests (send, accept, decline, cancel), two-way
  friendships, a mailbox with a seen time, a red dot with the count, marked seen when viewed, checked every 15 s
  while the menu is up. Accounts only; no blocking or reporting, rate limits instead (10 per 10 minutes, 40 a
  day, 30 waiting, 200 friends, a day's wait after a decline). Saved players are now the "Recent" list.
- **Gameplay.** Enemy health per map (Yard 1.0, Riverbend 1.05, Quarry 1.1) and +10% on XL; damage unchanged.
  XL boss raids bring two different bosses (the map's scheduled one and the next in its pool) at 90% health
  each; 16×16 keeps one. Oil drums no longer stop bullets or sight lines (they still block walking and
  building); rock does.
- **PvP on every map** (`06c-pvp-maps.js`): a mirrored Base Battle layout and a designed Free-for-all arena per
  map (Yard: timber lanes and two ruined sheds; Riverbend: the river corner to corner with two bridges and a ford
  a side, banks flooding every 75 s / four islands round a pool; Quarry: a lit, mirrored pit with a ramp behind
  each stake / a stepped pit with ledges, pillars and a cracked floor round a spire). The host picks the map;
  it reaches guests in the lobby and at the start. `MAPS[..].modes` lists each map's modes.
- **Looks.** A round, ribbed Jack-o'-Lantern (smaller, lower, the face on the front); the Pumpkin Butcher's 2D
  head matches. The Grenadier holds a pump shotgun low and wears a chest belt of five green grenades plus a waist
  row (3D, 2D, thumbnails). "Glitch Mask" is now "Glitch Head" (id `hat:glitch` unchanged). Locker thumbnails are
  framed from the figure's measured bounds, painted at their displayed size × pixel ratio, backgrounds
  centre-cropped, names always below the art. Opening a case plays a 3 s intro (shake, blur, it breaks apart;
  tap to skip, shorter with reduced motion) while the server rolls.
- **Server: `supabase/v0.9.1-migration.sql` must be run when v0.9.1 is published** (not before). It adds
  `friend_requests`, `friendships`, `notifications` (read-only to their owners through RLS; all writes go through
  `friend_send`, `friend_answer`, `friend_cancel`, `friend_remove`, `notes_seen`, and `social_state` reads it all
  at once), renames Glitch Head, and replaces `claim_match_reward`: it now also returns `cases` per type,
  `unlocked_ids` and `to_next`, and allows two boss cases per XL boss raid when the claim says `size: 'xl'` and
  the run took at least 35 s a raid. Older clients keep working. Both parts were tested in rolled-back
  transactions on the test account.
- Protocol **yard-15** (room prefix `palisade-yard-15-`): the `ab` player field and the `nextcls` message.
- Tests: `friends.js` (mock server, two accounts), `rewards_screen.js`; `lobby.js`, `v090.js` and `v090_net.js`
  cover SOLO, the map panel in every mode, the dropdown, the full party, job changes in the room and in
  Free-for-all, PvP map sync, XL two bosses, health multipliers, drums and every PvP layout (symmetry, reachable
  spawns, no stuck tiles, no spawn in plain sight of another). Meters: `bench.js` (now also Settings, Account,
  the six-player stage, the Friends dropdown and the case intro), `mapbench.js` (XL boss raids, PvP layouts),
  `netxl.js` (six players online on XL: about 11–12 KB/s to each guest).

## v0.9.2: modifiers, the skill tree, class abilities, the rejoin fix

- **Modifiers** (`01b-mods-skills.js`: `MODS`, `cleanMods`, `hasMod`, `modBonus`; `10b-mods-play.js`: the hooks).
  Each modifier is data (id, name, text, modes, reward percent). ids travel over the network and into match
  records: never rename one, only add. The host picks them on SOLO (`#soloMods`) or in the room (`#lMods`, and
  `#lOneJob` for One Job); they're saved per mode in `cfg.mods`, sent in the `lobby` and `start` messages
  (`mods`, `job`), and every phone runs `newGame(roster, pvp, {gid, mods, job})`. Best scores: `bestKey` adds
  `|modKey(mods)` (no modifiers keeps the old key). Hooks: `extraBoss` (Boss Rush, Nightmare's surprise boss,
  queued as `boss:key:sb`), `modWaveMix` (Elite Raid, Firestorm), `stormRaid`/`stormTick`/`stormSlow`/`drawStorm`
  (Weather; `game.wx` rides the state packet), `suddenTick`, `frenzyTick`; the rest are single `hasMod()` checks
  where they act (`repairCore`, `newGame` for Dell, `bottleLand`, `updateWalls`, `hurtPlayer`, `pvpDown`,
  `updateEnemies`, `todStage`, `refit`, `throwNade`, `controlLocal`).
- **In-between bosses** set `e.sb`: they count in `game.sbN` (not `bossLog`) and the claim sends `shard_bosses`.
- **Skill tree** (`SKILLS`, `perkMods`, `skillStr`/`parseSkills`; page `#pg-skills`, `renderSkills`). One digit
  per node in `SKILLS` order (+`m` when Molotovs are switched off) is how a tree travels (`sk` in the roster).
  `kitUp(p)` works out a player's perks for the match (PvP: half, job nodes off) and `refit` folds them in. The
  host only uses a guest's tree after `checkSkills` has read the server's copy (`skills_of`) and taken the lower
  of the two for each node; without an account, no perks.
- **Abilities** (`useAbility`, `simAbility`, `localAbility`; guests send `{t:'ab',x,y}`). `p.ab` on the network:
  soldier = rockets left; sniper = stealth time ×10 while on, minus the recharge seconds. Player rockets are
  `rockets` with `pl:true` (they hit raiders); Molotov fire is `fires` with `pl:true` (raiders only, never walls).
  A stealthed sniper is skipped by `updateEnemies` and `nearestAlly`.
- **Rejoin fix and match records.** Every game has an id (`game.gid`, from the host). A guest's first state
  packet sets where they came in (`game.joinHeld/joinT/joinBoss/joinSB`); `lockerReward(held, win, kills, left)`
  claims only from there (`raid_from`/`raid_to`), with `game_id`, `joined_s`, `left_s`, `left`, `upgrades`
  (`upS:dellLevel`), `salvage`, `mods`, `map`, `shard_bosses`.
- **Server: `supabase/v0.9.2-migration.sql` must be run when v0.9.2 is published** (not before). New
  `match_results` columns (game_id, raid_from/to, joined_s/left_s, left_early, upgrades, salvage, mods, map,
  size, shard_bosses, skill_points); `lockers.sp/sp_prog/sp_total/skills`; `skill_buy`, `skill_respec`
  (40 shards), `skills_of`; and a new `claim_match_reward`: a claim for a game id already claimed starts where
  the last one ended (raids, bosses and the win), the modifier bonus is worked out on the server
  (`private.mod_bonus`), shard bosses need Boss Rush or Nightmare, a fitting count and 25 s a raid, and skill
  points are paid (1 per 5 raids, 1 per boss). Older clients keep working. Tested in rolled-back transactions.
- Phones: the lobby stage's sixth player stands to the side instead of behind you (`STAGE.phone`).
- Protocol **yard-16** (room prefix `palisade-yard-16-`): `gid`/`mods`/`job` in `start`, `mods`/`job` in
  `lobby`, `sk`/`uid` in `hello`, `sk` in `loadout`, the `ab` message, `sb`/`wx`/`sd` in the state packet,
  and a radius on each fire.
- Tests: `modifiers.js` (all 15, the mode lists, rewards, best scores, host → guest), `skilltree.js` (mock
  server: points, the page, reset, perks, rockets, stealth, Molotovs, PvP, the host's check), `rejoin.js`
  (leave and come back: two claims that don't overlap, a guest's rocket). `bench.js` adds the SKILLS page and a
  storm raid; `netxl.js` takes `MODS=weather,nightmare`.

## v0.9.2.1: controller support

- **`08b-pad.js`** holds all of it. `PAD_ACTIONS` is the one table of in-game actions on a controller
  (`[id, Settings name, default button]`, buttons in the browser's standard layout `PB`); a new action is one
  line there plus its line in `gamePad()`. The player's own buttons are saved in `palisade.pad.v1`
  (`{map:{action:button}}`; -1 = unbound; MENU can't be taken, it always pauses). Reload is in the table but
  unbound by default.
- **`padTick(now)`** runs at the top of `frame()`. With no controller ever seen it looks once a second, so phones
  pay nothing. `padMode` is true while the controller was the last thing used; any real key, click, touch or a
  mouse move over 6 px hands back (`padOff`). In play it fills `pad.mx/my/ax/ay/amag/fire`, which `controlLocal`
  reads like the touch sticks (with `assist()`); a trigger press bumps `mouse.pulls`, so semi-auto guns take one
  shot per pull, and `autoFire` is off for a controller. Guests send the same `i` message as before: **no
  protocol change, still yard-16**.
- **Menus:** `navScope()` picks the window on top (save, case, armory, pause, game over, friends list, lobby,
  respawn jobs); `navMove` goes to the nearest visible button that way, `navPress` uses a button's `_tap`
  (`tapBtn` now keeps it) or clicks, `navBack` sends Escape (never out of a room), `navPage` = bumpers through
  `.partyNav` pages, `navTab` = triggers through `#lockTabs`/`[role=tablist]`, right stick scrolls. The highlight is
  the `padF` class; `#padHint` is the bottom hint bar. Any new screen works as long as its controls are real
  buttons/inputs inside one of those windows.
- **Keyboard focus order:** Tab is kept inside an open window (not the lobby) by the same `navScope`/`navList`.
- **On screen:** `ctl(touch, keys, pad)` picks a tip's wording; `padKey(action)`/`glyph(button)` give the label
  (Xbox letters, or PlayStation symbols when the id says so); the `.kc` key labels, the `#keys` bar (`padBar`),
  the armory prompt, the stake keycap and the HOW TO PLAY box all follow. Settings has the CONTROLLER card
  (`#padSet`, `renderPadSet`, `padBindTick`: pick, then press; a used button swaps; MENU/HOME cancel; 6 s
  timeout). The pause screen has `#padCard` while a controller is connected.
- **Rumble:** `buzz()` also calls `padRumble()` (`vibrationActuator.playEffect('dual-rumble')`), same Vibration
  setting (`cfg.haptics`).
- Tests: `controller.js` (a fake controller through `navigator.getGamepads`: menus, pages, tabs, sliders,
  toggles, changing buttons, a raid, trigger pulls, grenade, build, armory, the pause card, unplugging, a phone,
  and what a guest sends), `taborder.js` (Tab through every lobby page at desktop and phone-landscape sizes,
  and it stays inside pause and the armory). `lobby.js` now expects 5 Settings cards. `shots_pad.js` takes
  controller screenshots (not pass/fail).
- No server change.
