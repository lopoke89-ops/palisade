# v0.9.7.1 work order: BETA FEEDBACK PASS

Status: **plan; written October 3 from Big U's beta notes.** **All decisions made by Big U on October 3** (F5, F8, F9, F10 and F11 changed from the proposals; the rest as proposed). Nothing is built yet.

Six fixes, all reported by players in the first day of City Black Out:

1. Black Out salvage
2. A breather before the final push
3. Round messages too quick to read
4. Phantom headwear
5. Ready up in the multiplayer lobby
6. A zoom (field of view) slider

All of it is client-side. **No server migration.** Protocol goes to **`yard-27`**, because two new network messages are added (ready states).

## Summary

| # | Fix | Root cause found in the code | Size |
|---|---|---|---|
| 1 | More salvage in City Black Out | The mode never pays the per-round salvage the other modes pay, and the armory only opens at Main Command during short gaps | Medium |
| 2 | Ready up, or more time, before the final push | The last gap is **15 s**, half the normal 30 s | Small |
| 3 | Round messages on screen longer and easier to see | Messages show for 3 s, and each new one instantly replaces the last | Medium |
| 4 | Phantom can wear headwear again | Blocked since v0.9.3.5 in `headwearAllowed` | Small |
| 5 | Ready up in the multiplayer lobby | No ready state exists; only the host's START | Medium |
| 6 | Zoom slider in Settings | The zoom is fixed by screen size (`resize()` in `02-view.js`) | Medium |

## 1. City Black Out salvage

**Reported:** "not enough salvage to upgrade."

**What the code does now:**
- In every other co-op mode, each break pays everyone **8 + raid number** salvage (`startBuild`, `10-phases-bosses.js`). Black Out has no build phases, so it **never pays it**. The only income is kill bounties (rifle 4, grenadier 7, etc.) and boss bounties.
- The armory only opens **at Main Command** and **only during a quiet gap** (`shopOpen`, `04-state-armory.js`). Gaps are 30 s, and the points are 16–22 tiles away, so a player defending a point often can't reach the armory before the next attack.
- Last 7 days of Black Out runs: about 86 kills and **386 salvage left unspent** on average at the end. That suggests the bigger problem is **not being able to spend**, not only not earning enough. Both get fixed.

**The change:**
- **Round pay.** When each POI attack ends, everyone gets **20 + 5 × attack number** salvage (attack 1: 25, attack 8: 60; 340 total over a run). A lost POI pays half.
- **Starting purse.** +40 salvage when the gathering starts, so the first upgrade is affordable before attack 1.
- **Final-push bonus.** +60 when the final push begins.
- **Bounties.** Kill bounties ×1.25 in Black Out only (stacks with the Gas Station's +25%).
- **Armory reach.** The armory also opens at **any held POI's structure** during a quiet gap, not just Main Command. Main Command stays the only place to patch the core.
- **Gap length.** The quiet gaps go from 30 s to **35 s**, giving time to walk, buy and get back.
- **Expected effect:** about **+550 to +650 salvage** per full run, against the ~390 from kills alone today. That's roughly 2.5× more.
- **No other mode changes.**

**Tests:** extend `blackout_run`:
- each attack's end pays the right amount (and half when lost);
- the starting purse and the push bonus;
- the bounty multiplier only in Black Out;
- `shopOpen` is true at a held POI during a gap and false during an attack or at a lost POI.

`solo` and `blitz_mode` must stay unchanged (their pay is checked).

## 2. A breather before the final push

**Reported:** the final round comes too fast; people want a ready button or more time.

**What the code does now:** after the eighth attack, the gap before the final push is `BO.gap * .5` = **15 s** (`boEnd`, `10f-blackout.js`). It's the shortest gap in the run, right before the hardest part.

**The change: a READY UP stage before the push.**
- After the last attack ends, the clock shows **"FINAL PUSH IN 1:30 · READY UP"**, and a **READY** button appears in the phase box. Keyboard: Enter; controller: the Start button.
- **Solo:** pressing READY starts the push now. Otherwise it starts when the 90 s run out.
- **Co-op:** the push starts when **everyone alive has readied up**, or when the 90 s run out. The phase box shows **"READY 2/4"**, and each player's row in the crew list gets a check mark.
- **Nobody can force it** (Big U, F5): not the host, and there's no START NOW. The push starts when everyone has readied up, or when the full 90 s run out.
- During this stage the armory is open everywhere a held POI is (see §1), and POIs repair at double speed.
- The +60 push bonus from §1 is paid when this stage begins, so it can be spent in it.
- **Network:** the guest sends `{t:'ready'}`; the host keeps a ready set and sends the count in the Black Out summary (`bo` snapshot field, two new trailing numbers). Old fields keep their order.

**Tests:**
- `blackout_run`: the ready stage lasts 90 s with nobody ready; solo READY starts the push at once; the push timeline (bosses every 30 s, the Destroyer at 3:00) still works from the moment it starts.
- `blackout_network`: the guest's READY reaches the host, the count shows on both phones, and the push starts only when both are ready.

## 3. Round messages that can be read

**Reported:** "the in-between round message isn't on screen long enough to read."

**What the code does now:**
- `toast()` shows a message for a fixed **3 s**, in mid-screen, with the detail line in 12 px grey text (`11-hud-chat.js`, `#toast` in `style.css`).
- Each new message **replaces the previous one instantly**. Black Out often fires two close together ("GAS STATION HELD" then "NEXT · HOSPITAL"; "FIRST TARGET" then "POI UNDER ATTACK"), so the first is gone before anyone reads it.

**The change:**
- **Message queue.** Messages wait their turn instead of overwriting. Each one stays at least its minimum time; a queue longer than 3 drops the oldest *minor* message, never a phase message.
- **Two kinds of message:**
  - **Phase messages** (raid start, raid broken, POI under attack, held, lost, next target, final push, the Destroyer, evacuation): **6 s**, bigger title, a coloured band across the screen (orange for a threat, green for held, red for lost), and the detail line in larger, brighter text.
  - **Minor messages** (case drops, Delgado, perks): **3.5 s**, as today but brighter.
- **Readable on phones.** The detail line goes from 12 px grey to 14 px (16 px on desktop) in the bone colour, with a dark backing panel behind the whole message so it reads over the bright city.
- **Can't be missed later.** The latest phase message also stays in small type under the phase box until the next one, so a player who looked away can still read it.
- **Tap to dismiss** (or press Escape) for anyone who has read it.
- **Settings:** a new **"Message time"** option: Normal / Long (×1.5) / Very long (×2).
- **This applies to every mode,** not just Black Out: the same problem exists between raids everywhere.

**Tests:**
- new `toast_queue`: two phase messages in a row both show for their full time, in order; a minor message waits behind a phase one; the queue cap; tap-to-dismiss; the settings multiplier.
- `hud_layout`: the message panel doesn't cover the phase box, the build kit or the joysticks at all three sizes.

## 4. Phantom headwear

**Reported:** players miss wearing headwear on the Phantom.

**What the code does now:** `headwearAllowed()` (`18-cosmetics.js`) refuses every hat for the Phantom (along with the Demon, the Reaper, the Mummy wraps and a few others). It was turned off in the v0.9.3.5 fixes. Players can still equip the hat, but it's greyed out in the Locker and their soldier is drawn in Class Issue.

**The change:**
- Take the Phantom out of the blocked list, so he can wear **any** headwear again.
- Check every hat on him in the fit sheet (`headgear_fit` / `headgear_sheet`), because his head is see-through and drawn at about 60% opacity:
  - **Hats drawn opaque over the ghost (proposal):** hats look like real objects sitting on a ghost. That is the look players remember.
  - Hats that clip badly get a per-hat offset, the same way the Sheet Ghost's Dunce Cone was fitted in v0.9.6.4.
- Nothing else about the other blocked skins changes (F7).

**Tests:** `headgear_fit` gains the Phantom with every hat (no clipping past the outline, the hat sits on the head), and `cosmetics` checks the Locker no longer greys hats out on the Phantom.

## 5. Ready up in the multiplayer lobby

**Reported:** players want a ready-up button in the Multiplayer lobby.

**What the code does now:** only the host has a button (`#lStart`, START), and it starts the game whenever they press it. Guests have no way to say they're ready.

**The change:**
- **Every player gets a READY button** in the lobby, next to their row; the host's own button is START.
- **Each player's row shows READY** (green check) or **NOT READY**. The lobby header shows **"3 / 4 READY"**.
- **The host's START:**
  - **lights up** when everyone is ready;
  - **stays locked until everyone is ready** (Big U, F8). The host must ready up too; START is their ready-and-go button, and it only works once every guest is ready;
  - **changing a setting** (mode, map, difficulty, modifiers) **clears everyone's ready**, so nobody is pulled into a game they didn't agree to.
- Someone joining resets to "not ready" for that player only.
- **Network:** the guest sends `{t:'ready',on:true|false}`; the host adds `ready` to each roster entry in the `lobby` message. Old guests that don't send it are treated as not ready (they can't be on the same protocol anyway: `yard-27` turns them away).

**Tests:** extend `lobby`:
- the guest's READY shows on the host;
- the ready count;
- START lights up when everyone is ready;
- changing the mode clears it;
- START refuses while anyone is not ready.

`multiplayer` stays green.

## 6. Zoom (field of view) slider

**Reported:** players want to zoom in or out on any map.

**What the code does now:** the tile size is set only by the screen size, `S = clamp(min(W, H·1.15)/560, .72, 1.35)`, in `resize()` (`02-view.js`). Players can't change it.

**The change:**
- **Desktop only** (Big U, F9): phones keep today's fixed view and don't get the slider.
- **Settings → ZOOM slider**, from **70% (wider view) to 140% (closer)**, default 100%. It multiplies the screen-size scale above.
- **Saved on this device** (like volume), so it applies to every map and mode. It is never sent to other players.
- **Also in-game:** the in-game settings sheet gets the same slider, and the mouse wheel zooms inside the same range. No pinch zoom, since phones don't get zoom (F10).
- **Rendering:** the caches already rebuild on resize. A zoom change rebuilds them once, after the slider stops moving (not on every step), so dragging stays smooth. City chunks and building sprites are keyed by tile size, so they rebuild on their own.
- **Guard rails:**
  - **Big maps:** desktops get the full range on the 64×64 city too; `blackout_perf` records the cost of 70%.
  - **PvP:** allowed, the same range for every desktop player (Big U, F11).
  - **Readability:** HUD text, bars and labels don't scale with zoom; only the world does.

**Tests:**
- new `zoom_setting`: the slider changes the tile size within the range; it's saved and restored after a reload; caches rebuild once per change; phones have no slider and their view doesn't change; the HUD doesn't move.
- `blackout_perf` gets a desktop 70% zoom-out run to record the cost.
- `ingame_settings` shows the slider.

## Release

- **Version:** v0.9.7.1, protocol `yard-27`.
- **Server:** none.
- **Order:**
  1. §4 (one line)
  2. §2 and §1 together (both touch the Black Out run)
  3. §3
  4. §5
  5. §6
  6. Then: full suite, screenshots at three sizes (the new messages, the ready stage, the lobby, the zoom slider at both ends), Big U's OK, merge.
- **Evidence:** `dev/evidence/v0.9.7.1/`, with the salvage totals of a scripted full Black Out run before and after.

## Decisions (all made by Big U, October 3)

| # | Question | Proposal |
|---|---|---|
| F1 | Salvage per attack | **Decided (as proposed):** 20 + 5 × attack number (25 → 60), half if the POI was lost |
| F2 | Other salvage boosts | **Decided (as proposed):** +40 at the start, +60 at the final push, kill bounties ×1.25 in Black Out |
| F3 | Armory at held POIs during gaps | **Decided (as proposed):** yes (Main Command stays the only place to patch the core) |
| F4 | Quiet gap length | **Decided (as proposed):** 35 s (from 30 s) |
| F5 | Before the final push | **Decided: a READY UP stage. The push starts when everyone has readied up, or after the full 90 s. Nobody can force it, not even the host** |
| F6 | Message times | **Decided (as proposed):** phase messages 6 s, minor 3.5 s, queued, plus a "Message time" setting |
| F7 | Phantom headwear | **Decided (as proposed):** any hat, drawn solid over the see-through ghost; the other blocked skins stay as they are |
| F8 | Lobby START when not everyone is ready | **Decided: everyone has to ready up.** START stays locked until all are ready; any settings change clears ready |
| F9 | Zoom range | **Decided: desktop only, 70%–140%.** Phones keep the fixed view |
| F10 | Pinch / mouse-wheel zoom in-game | **Decided by F9:** mouse wheel on desktop; no pinch |
| F11 | Zoom in PvP | **Decided: allowed**, same range for everyone |
| F12 | Apply the message changes to every mode | **Decided (as proposed):** yes |
