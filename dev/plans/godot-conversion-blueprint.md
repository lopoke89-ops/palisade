# PALISADE → GODOT CONVERSION BLUEPRINT

Prepared October 7, 2026 against v0.10.4. **Revised October 13, 2026 against v0.10.9** (`4c26769`). This is a planning document only: it does not authorize implementation.

The conversion should preserve the current game's rules, content, presentation, account identity and player history. A feature counts as complete only when its implementation passes its parity contract. Appearing on screen, compiling or producing an executable does not establish parity.

The October 13 revision:

- moves the baseline to v0.10.9;
- adds the player-hosted casino relay (v0.10.5–v0.10.6), SLIM's persistent wallet and heads-up Hold'em, the casino result sounds, and the layout changes from v0.10.7–v0.10.9;
- records the casino security fix and the defects that are still open;
- certifies the served bytes, which were unknown on October 7.

Items that were inspected only on the owner's PC on October 7 are marked **(PC, Oct 7)**. They were not re-verified, because the PC is not reachable from the repository.

Throughout this blueprint:

- **Verified:** established by source inspection or a read-only service response during the revision.
- **Recorded evidence:** an existing report, capture or test result. It was not rerun.
- **Unknown:** evidence is missing or insufficient.
- **Recommendation:** a proposed implementation or acceptance decision that still needs approval.

---

## 0. Action needed now (found during the October 13 revision)

| Item | Finding | Recommended action |
|---|---|---|
| **`tables-staging` Edge Function** | Version 2 ran pre-v0.10.7 code (`op in M` dispatch) against the production database, so the casino state leak was still reachable through it. **Neutralised Oct 13:** version 3 is an inert stub (HTTP 410, no database access, no service key, gateway JWT on). | Delete it in the dashboard when convenient; no longer urgent. |
| Deploys made outside the repo process | `tables` was redeployed from the owner's PC as v10 (Oct 6), v14 (Oct 9) and v16 (Oct 10), each time with CRLF line endings. v16's content equals the repo after line-ending normalization, so none of these redeploys changed code. | Record every function deploy in STATUS. During conversion, treat any undocumented version as a drift alarm. |
| Migration history drift | The relay migration file is `20261008213153_casino_relay_lobby_codes.sql`, but the live history records `20261009032510 casino_relay_lobby_codes`. | Align the history version with the file, or record the mapping, before any CLI `db push`. |

---

## 1. Authoritative baseline

**The baseline consists of several independently versioned parts.** A browser version label alone cannot identify the complete deployed product.

| Baseline component | Finding and evidence (Oct 13 unless marked) | How it will be used |
|---|---|---|
| Main | Verified: remote `main` = `4c2676972c34b22e2da6f73d4a4fe59488642b83` (v0.10.9, Oct 11). | Primary source oracle. |
| Served bytes | **Verified**: the served `index.html`, `sw.js` and `manifest.webmanifest` are byte-identical to `main` (hashes below). | Closes the October 7 "served bytes unknown" gate for these three files. Fonts and music still need a hash pass in Phase 0. |
| Browser source | Verified: **59** JavaScript modules totalling 1,068,655 bytes, plus HTML and CSS. Production `index.html` is 937,743 bytes. | All 59 modules must be mapped. `21a-casino-relay.js` is new since Oct 7. |
| Browser protocol | Verified: `PROTO='yard-29'`; PeerJS room prefix `palisade-yard-27-`. | Preserve both values for combat interoperability. |
| Casino relay | Verified: Render Free web service from `dev/render/relay.js`, wire `casino-relay-1`, `ws@8.22.0`, Node `>=22.17 <23`, `maxRooms` 10 by default (6 humans each), `maxPayload` 64 KiB, 2-minute resume grace. The client endpoint comes from `dev/render/client.json`. Identity is verified per connection against Supabase `/auth/v1/user`. The allowed origins are the exact Pages origin(s). | New baseline component; see PAL-079. |
| Casino backend | Verified: `tables` **v16**. Its four files equal the repo after CRLF→LF. History since Oct 7: v13 SLIM wallet; v14 a CRLF redeploy; v15 the state-leak fix plus heads-up Hold'em; v16 a CRLF redeploy. | Current backend oracle. |
| Database | Verified: migrations through `20261009041955 casino_slim_wallet` (plus the relay lobby-code migration, recorded under a different version). 83 accounts; database 20 MB. | Preserve the live contracts. Migration history alone does not certify every function body or Auth setting. |
| Cosmetic catalog | Verified live, unchanged since Oct 7: **374** entries (120 skins, 52 hats, 76 tracers, 48 kill effects, 78 backgrounds) and **7** case types. | Expected reconciliation totals. |
| Existing Godot project | (PC, Oct 7) Godot 4.5, GL Compatibility, a Windows x86_64 export preset, ENet, three playable classes and a five-raid Yard simulation. | Reference for reuse only; it certifies no parity with the current game. |
| Old migration package | (PC, Oct 7) Targets commit `07eb5e54…` and protocol `yard-21`; a 60-system ledger, all `not_started`. | Historical design reference only. |

Production file SHA-256 values at `4c26769` (served copies match):

| File | SHA-256 |
|---|---|
| `index.html` | `a292ed7a0f3d3b93d59c7dcdf306466fb0f04bbbb7953667c4d94d31683ea7f5` |
| `sw.js` | `b9480baa027e88d59385f4f8c6dca8d1b33be34d0eb80d0908f7e5303d0483ef` |
| `manifest.webmanifest` | `844a7bad48afe32d6bd07f0dec41603b75aff827bc02b41cd40c19b7f4105a95` |

**Releases since the October 7 draft:**

| Release | Change | Conversion impact |
|---|---|---|
| v0.10.5 (Oct 8) | Player-hosted casino lobbies of up to 6 people through a WSS relay on Render Free. 6-character `R…` codes, and the creator hosts the floor. | New transport (PAL-079). Room-code and lobby-register contract changes (PAL-059). |
| v0.10.5 (Oct 9) | SLIM's persistent wallet, funded by settled non-poker house results. Backfill of 5,475 shards. | Changes SLIM's buy-in and economy (PAL-067, PAL-080). |
| v0.10.6 (Oct 9) | Relay token refresh and a 2-minute reconnect window. Distinct messages for host sign-in expiry and server restart. | Relay lifecycle contract (PAL-079). |
| v0.10.7 (Oct 10) | Casino state-leak fix (requests dispatch only to the server's own names). SLIM sits in with one or two players. Centred baccarat and craps chips. | Security regression fixture; Hold'em seating contract; chip layout. |
| v0.10.8 (Oct 11) | Result sounds for every casino game, scaled by net against bet. Craps dice throw and roulette ball sounds. | Audio contract (PAL-050, PAL-073). |
| v0.10.9 (Oct 11) | Desktop casino sheet at `max(360px,40vw)`. | Layout contract (PAL-031, PAL-065). |

**Unfinished local work (PC, Oct 7; not re-verified):**
- `sahur-open-games` is dirty and 66 commits behind.
- `test-efficiency` is dirty and 72 commits behind.
- `winter-release-0960` is clean at `07eb5e54`.
- The Godot project, historical phone folders, executables and backups also exist.

None of these are the oracle. Preserve them; review individual changes later.

**Target policy.** Recommendation: **freeze v0.10.9 (`4c26769`) plus `tables` v16 as the initial conversion target**, re-confirmed in Phase 0. Every later browser release becomes a reviewed change request carrying:
- its commit and affected PAL IDs;
- any asset, schema, protocol or server changes;
- its acceptance fixtures;
- an adoption decision.

Keep two explicit versions: the frozen parity target, and the latest supported browser release. Move the target only at a declared milestone. Security and integrity fixes reach both clients together.

---

## 2. Source inventory

| Ref | Source of truth (repo paths) |
|---|---|
| S0 | `dev/src/`, `dev/assemble.py`, `dev/build.py`. Assembly uses **sorted filenames**; `ORDER.txt` is documentation, not the manifest. 59 modules. |
| S1 | `01-setup.js` (tuning, classes), `01b-mods-skills.js`, `04-state-armory.js` |
| S2 | `02-view.js` (projection, body targeting, DPI, resize, zoom) |
| S3 | `06-world.js`, `06b-maps.js`, `06c-pvp-maps.js`, `06d-elevation.js`, `06e-city.js` |
| S4 | `09-actions.js`, `12-players.js`, `14-raiders.js` |
| S5 | `10-phases-bosses.js`, `10b-mods-play.js`, `10c-blitz.js`, `10d-winter-campaign.js`, `10e-boss-moves.js`, `10f-blackout.js`, `10g-destroyer.js` |
| S6 | `13-dell.js`, `13b-commands-recovery.js` |
| S7 | `07-effects.js`, `15-render.js`, `16-characters.js`, `17-scenery.js` |
| S8 | `16b`–`16e`, `18a`–`18f`, `20a`, `20b-winter-effects`, `20c` (presentation and catalog modules) |
| S9 | `page.html`, `style.css`, `11-hud-chat.js`, `22-loop-menus.js`, `16f-blackout-hud.js`, `16h-nameplates.js`, `19c-home.js`, `19e-index.js` |
| S10 | `08-input.js`, `08b-pad.js` |
| S11 | `03-audio.js`, `dev/audio/music-manifest.json`, `dev/audio/README.md` |
| S12 | `19-accounts.js` |
| S13 | `19b-social-lobby.js`, `19d-friend-invites.js` |
| S14 | `05-net-record.js`, `21-online.js` |
| S15 | `18-cosmetics.js`, `20-locker-ui.js`, `20b-case-openings.js` |
| S16 | `06f-casino.js`, `21b-tables.js`, `21c-casino-games.js` |
| S17 | `dev/supabase/functions/tables/{index.ts,handler.js,engine.js,games.js}` (= live v16) |
| S18 | `dev/supabase/schema.sql`, `dev/supabase/migrations/`, `dev/supabase/compensation/`, live metadata |
| S19 | `dev/test/` (`suite.txt`: 117 active entries, including 6 `casino_relay_*`), `dev/evidence/` |
| **S20** | **New:** `dev/render/relay.js`, `dev/render/client.json`, `dev/render/test/`, `render.yaml`, `21a-casino-relay.js` |

---

## 3. What "1:1" means: acceptance profiles

These gates are proposed, not approved. Calibrate them against authorized baseline captures before approval.

| Profile | Acceptance and tolerance |
|---|---|
| **X: Exact contract** | Same IDs, integers, ownership, prices, rewards, outcomes, eligibility, state transitions, protocol fields and persisted meaning. No tolerance for lost or duplicated value. |
| **R: Numerical rules** | Golden fixtures match. Floating-point intermediates within ≤1e-9 absolute or relative; every branch, hit, death, payout and discrete outcome exact. |
| **T: Timing and motion** | Matched input and delta traces give the same event order. Presentation allowance of one update (16.7 ms at 60 Hz, 33.3 ms at 30 Hz). This never excuses a different outcome. Network position quantization stays at 0.01 tile. |
| **V: Visual** | Same framing, silhouettes, layering, colours, animation phases and layout. Controls and text within 1 logical px. Per region: SSIM ≥0.995 and mean channel error ≤2/255, with narrow antialiasing masks. Human review is mandatory. |
| **A: Audio** | Same routes, tracks, ordering, envelopes and resume behaviour. Loop endpoints exact to the sample count. Event onset within 20 ms, gain within 0.5 dB. No new loop gaps or clipping. |
| **N: Network** | Same admission, commands, sequencing, correction, state and recovery. Zero divergence in authority, rewards or ownership. Any added latency needs a separately approved, measured allowance. |
| **P: Persistence** | All supported records round-trip, interrupted work resumes safely, and unknown IDs survive. Atomic commits and account ownership are exact. |
| **L: Lifecycle and performance** | No crash, stuck input, unreachable action, growing queue, unrecoverable session or unbounded growth. |

Verification methods:
- **rules:** fixture comparison.
- **input:** timestamped replay.
- **visual:** screenshots and frame sequences plus human review.
- **audio:** captures and listening.
- **network:** multi-client tests and fault injection.
- **save:** import, recovery and conflict fixtures.
- **economy:** transactional staging tests and reconciliation.
- **device:** hardware and lifecycle testing.

---

## 4. Parity matrix

The stable IDs below must be retained. Implementations add child IDs for individual catalog items, encounters, menus and protocol messages. No row is verified in Godot. Rows changed or added on October 13 are marked **(Δ)**.

| ID / system | Source | Observable behaviour | Godot approach | Cat. | Acceptance | Tol. | Risk / unknowns | Verify |
|---|---|---|---|---|---|---|---|---|
| PAL-001 Assembly/init | S0 | Same content and startup dependencies | Explicit bootstrap; imported rule and catalog resources | Beh | All **59** modules mapped (Δ); same init results | X | ORDER.txt is incomplete | Coverage; rules |
| PAL-002 Classes/tuning | S1 | 4 jobs, 3 difficulties, materials, formulas | Versioned RuleCatalog | Num | All definitions and derived stats match | X/R | Prototype values differ | Rules |
| PAL-003 Match state | S1,S4,S14 | Phase, roster, timers, match id | MatchState + authority-owned sim | Beh/Net | Same transitions and owners | X/T | Global coupling | Rules; net |
| PAL-004 Co-op 5/10/Endless | S5 | Prep, raids, scaling, night, results | Mode controller | Beh/Num | Same waves, spawns, ends, rewards | X/T | Long-run scaling | Rules; input |
| PAL-005 Base Battle/FFA | S1,S3–S5 | Teams, truce, cores, respawn, score | PvP controllers | Beh/Num | 700-HP base, 45-s truce, FFA goal/time | X/T | Ties; class change | Rules; net |
| PAL-006 Blitzkrieg Rush | S5 | 15 stages, boss cadence, personal extraction | Blitz controller | Beh/Num | Same timer, boss cap, hold, variants | X/T | Personal vs crew state | Input; net |
| PAL-007 Operation Whiteout | S5 | 4 chapters, evacuations, continuity, Gauntlet | Campaign controller with epochs | Beh/Per | 15-s evac, penalties, Gauntlet | X/T/P | Old plan predates finale | Rules; net; save |
| PAL-008 City Black Out | S3,S5,S9 | Gather, 8 POIs, ready, final push | Blackout controller | Beh/Net | Order, perks, pay, timeouts, Destroyer | X/T/N | Intermittent net test | Rules; net |
| PAL-009 Co-op maps | S3 | Yard, Riverbend, Quarry, Frostpeak; std/XL | Exact generators | Vis/Num | Same terrain, resources, spawns | X/V | Hash/iteration order | Map fixtures |
| PAL-010 PvP maps | S3 | Mirrored arenas | Separate layouts | Beh/Vis | Same 16×16 geometry and support | X/V | Mode/map eligibility | Rules; visual |
| PAL-011 Height/connectors | S2,S3 | 3 tiers, ramps/stairs, aiming | Scalar height grid; analytic picking | Num/Vis | Links, rails, range, LOS | R/V | Native physics/Y-sort | Rules; input |
| PAL-012 Terrain mutation | S3–S5 | Water, flood, bridges, pits, drums, frost, fire | TerrainState + events | Beh/Vis | Same slow, damage, destroy, repair | X/R/V | Cache invalidation | Rules; net |
| PAL-013 Movement/collision/path | S3,S4 | Speed, axis slide, doors, flow paths | Port custom grid/circle | Num/Beh | Same legal paths and collisions | R/T | Order-dependent corners | Input; rules |
| PAL-014 Aim/targeting | S2,S4,S10 | Body→feet aim, assist, screen-relative | Shared aiming service | Beh/Num | Same targets and assist | R/T | Elevated occlusion | Input; visual |
| PAL-015 Building/destruction | S1,S3,S4 | Walls/doors, costs, repair, refusals | BuildService | Num/Beh | Placement, HP, cooldown, salvage | X/R | Own-wall farming | Rules; net |
| PAL-016 Gathering | S1,S3,S4,S6 | Unlocks, yields, refills, caps | ResourceService | Num/Beh | Stocks, timings, caps | X/T | Perk interactions | Rules; input |
| PAL-017 Soldier | S1,S4 | Bursts 3/5/7/9/9 | Weapon state machine | Num/Aud | Bursts complete; upgrades | X/T/A | Buffered burst loss | Input; audio |
| PAL-018 Sniper | S1,S4 | Bolt, pierce | Weapon state machine | Num/Beh | Damage, range, speed, buffering | X/T | Held vs pull | Input; rules |
| PAL-019 Grenadier | S1,S4 | 7 pellets, 6-shell tube, pump | Shotgun state machine | Num/Aud | Spread, falloff, reload interrupt | R/T/A | Generic gun differs | Input; audio |
| PAL-020 Quartermaster | S1,S4 | SMG, packs, repair, revive, sprint | Class + support actions | Num/Beh | Capacities and benefits | X/T | Confusion with Delgado | Rules; input |
| PAL-021 Armory/core/Delgado upgrades | S1,S15 | 8 levels, prices, core repair | Purchase commands | Num/Net | Costs, gates, failure feedback | X | Double purchase | Rules; net |
| PAL-022 Special ammo | S1,S4,S5 | AP/fire/blast/shock, ranks, slots | Ammo resources | Num/Vis | Costs, proc limits, combos | X/R/T | Stacking | Rules; net |
| PAL-023 Skills | S1,S12,S18 | 19 nodes, SP, respec | Server-backed skill resources | Num/Per | Tree, costs, encoding, validation | X/P | Positional encoding | Rules; economy |
| PAL-024 Modifiers | S1,S5,S18 | 20 modifiers, reward bounds | Shared definitions + server copy | Num/Beh | Combinations, −15%/+75% bounds | X/R | Duplicated constants | Rules; economy |
| PAL-025 Abilities/sprint | S1,S4,S5 | Rockets, stealth, Molotovs, sprint | Ability state machines | Num/Vis | Stocks, timing, tells | X/T/V | Phase resets | Input; net |
| PAL-026 Raiders | S4,S5,S9 | 7 archetypes | Existing AI | Beh/Num | Spawn, target, heal, 20-hit shield | X/R/T | AI order, randomness | Rules; replays |
| PAL-027 Bosses | S5,S7–S9 | Standard, Pumpkin, Blitz, winter, Destroyer | Boss resources + attack states | Num/Vis | Every attack, weakness, enrage | X/T/V | Tell/geometry agreement | Replays; visual |
| PAL-028 Delgado | S6 | Follow/Defend, gather, repair, revive | AI over the same rules | Beh/Num | Priorities, safe placement | X/T | Heuristics | Input; net |
| PAL-029 Damage/down/revive | S3–S6 | HP, stun, protection, revive | Shared health rules | Num/Beh | Attribution, windows | X/T | Mode distinctions | Rules; input |
| PAL-030 Dead End/results | S5,S6,S9,S15 | Recovery, overlay timing, rewards | End-state controller | Beh/Per | Recovery, outcome, transition | X/T/P | Projectiles settling | Input; net |
| PAL-031 Camera/zoom/resize **(Δ)** | S2,S7,S16 | Follow, spectate, shake, framing; the casino sheet offsets the camera (desktop sheet `max(360px,40vw)` since v0.10.9; phone bottom sheet ≤700 px) | Source-equivalent camera | Vis/Beh | 70–140% zoom, debounce, snapping, sheet offset | V/T | Camera2D smoothing differs | Input; visual |
| PAL-032 Depth/occlusion | S7 | Correct overlap | Stable explicit draw queue | Vis | Same depth key and ties | V | Y-sort insufficient | Visual |
| PAL-033 Lighting/weather | S3,S5,S7 | Day/dusk/night, glows, storm | Canvas layers; masks/shaders | Vis | Tint, pools, order | V | Blend/colour space | Visual |
| PAL-034 Characters | S7,S8 | Kit, facing, walk, recoil, bosses | Port procedural painter | Vis | Poses, proportions, phases | V/T | Baking loses detail | Catalog; sequences |
| PAL-035 Tracers/auras/kill fx | S7,S8 | Trails, sounds, particles | Shared effect library | Vis/Aud | Every effect ID | V/A | Cosmetic randomness | Visual; audio |
| PAL-036 Backgrounds | S8 | Layers, animation, reduced motion | Cached layers | Vis/Beh | IDs, palettes, motion | V/T | Static captures | Sequences |
| PAL-037 Catalog/acquisition | S8,S15,S18 | 374 items, rarities, ladders | Catalog resources keeping IDs | Per/Num | All 374 reconciled | X/P | Client/server drift | Catalog diff |
| PAL-038 Main/setup/lobby menus | S9,S13 | Choices, 6-person stage, states | Control scenes + theme | Vis/Beh | Options, defaults, transitions | X/V | HTML→Control layout | UI replay |
| PAL-039 Index/help | S9,S1,S5 | Classes, enemies, bosses | Data-fed UI | Beh/Vis | Agrees with rules | X/V | Stale text | Rules; review |
| PAL-040 HUD/nameplates/Blackout HUD | S9 | Health above heads, arrows, POIs | CanvasLayer anchors | Vis/Beh | Info, thresholds, layering | X/V/T | Obsolete HUD | Visual; input |
| PAL-041 Settings/defaults | S1,S9–S11 | Volume, music, shake, haptics, FPS, tips, kit, toasts, zoom | Config service | Beh/Per | Defaults, live effect, persistence | X/P | Export omits some | Save; UI |
| PAL-042 Keyboard/mouse | S10,S4 | Actions, held input, pulls, blur | Intent adapter | Beh | Consumption and buffering | X/T | InputMap echoes | Input |
| PAL-043 Touch | S10,S4 | Dual sticks, buttons, assist | Touch Control layer | Beh/Vis | Thresholds, hit areas, cancel | X/T/V | Safe areas, multi-pointer | Device replay |
| PAL-044 Controller | S10 | Remap, glyphs, dead zones, nav, rumble | Controller adapter + focus graph | Beh/Per | Defaults, swaps, mouse-free nav | X/T/P | Casino sheets lack a pad pass | Device; UI |
| PAL-045 Overlays/focus/scroll | S9,S10,S15,S16 | Back precedence, isolation, wrap | Overlay stack | Beh/Vis | No gameplay leakage | X/V | Font metrics | UI; visual |
| PAL-046 Chat/feedback | S9,S14 | Chat, feed, toasts, errors | Notification service | Beh/Net | Recipients, limits, queue | X/T | Flood handling | Net; UI |
| PAL-047 Locker UI | S8,S15 | Filters, previews, equip | Locker scene | Vis/Per | Actions and equip meaning | X/V/P | Unknown IDs | Save; visual |
| PAL-048 Cases | S15,S18 | 7 cases, ×1/×5, intro, skip, dupes, resume | Durable CaseService | Num/Per/Vis | One grant per operation | X/P/V | Uncertain reply | Economy; save |
| PAL-049 Music | S11 | 7 routed tracks + 11-track casino shuffle | Two players + router | Aud/Beh | Tokens, shuffle, loops, resume | X/A | Codec, decoded memory | Audio |
| PAL-050 Sound effects **(Δ)** | S11,S14 | Procedural weapons/UI/explosions, muffling, voice limits; casino `cas_*` cues, including the craps dice throw and roulette ball whir/drop (v0.10.8) | Source-equivalent synthesis | Aud/Beh | Event choice, attenuation, throttling | A/T | DSP/noise differences | Audio; net |
| PAL-051 Startup/offline | S0,S9,S12 | Readiness, lazy media, install | Boot + platform cache | Beh/Per | Offline boundaries | X/P/L | No SW on desktop | Device |
| PAL-052 Pause/focus/suspend | S9–S12,S14 | Solo pauses; online continues | Lifecycle coordinator | Beh/Aud | Pause authority; resume | X/T/A/L | OS suspend ≠ tab hide | Device; net |
| PAL-053 Errors/recovery **(Δ)** | S12–S16,S20 | Room/version/auth/rate errors; relay "server restarted" vs "host sign-in expired" | Structured errors | Beh | Correct state and message for every failure | X/L | Swallowed errors | Fault injection |
| PAL-054 Local saves/bests | S9,S15 | Locker, bests, backup/import | Versioned atomic files | Per | Round-trip; unknown IDs survive | P/X | Incomplete backup | Save |
| PAL-055 Auth/profile | S12,S18 | Anonymous + saved accounts, recovery | Existing Supabase Auth | Per/Sec | Same UUID, no replacement account | X/P | Anonymous handoff | Staging Auth |
| PAL-056 Cloud inventory | S12,S15,S18 | Locker, revisions, skills | Existing RPCs | Per/Num | Revision/conflict semantics | X/P | Concurrent clients | Economy |
| PAL-057 Reward claims | S12,S15,S18 | Rewards, drafts, recovery | Account-partitioned outbox | Per/Num | No lost or duplicated claim | X/P | 8-entry retention | Economy; faults |
| PAL-058 Friends/notifications | S13,S18 | Requests, recent, mailbox | Social RPC service | Per/Beh | Relationships, polling | X/P/T | Identity changes | Staging |
| PAL-059 Discovery/invitations **(Δ)** | S12–S14,S18,S20 | Public/private rooms, invites (5-min expiry); combat codes `^[A-Z0-9]{4}$`, casino relay codes `^R[A-Z2-9]{5}$` with `length='casino'` | Directory/invite adapter | Net/Per | Visibility, expiry, incarnation, both code forms | X/N | Host-UUID key collision | Net; staging |
| PAL-060 Host/join/readiness | S13,S14 | Codes, 6-player limit, teams, locks, kicks | Session controller | Net/Beh | Admission, start rules | X/N | Native reachability | Net |
| PAL-061 Snapshot/event protocol | S14 | 15 Hz state, 30 Hz input, events, walls | Versioned codec | Net/Num | Fields, sequencing, quantization | X/N | Ordering; city interest | Codec; net |
| PAL-062 Host validation | S1,S4,S14 | Bad actions rejected | Same validators | Net/Sec | Legal envelope; no NaN/overflow | X/N | Not trusted-server security | Adversarial |
| PAL-063 Rejoin/late join | S14,S5 | Mode-specific restore | Resume ledger with epochs | Net/Per | No duplicated recovery | X/N/P | No host migration | Net |
| PAL-064 Trust boundaries **(Δ)** | S12,S14,S17,S18,S20 | Accounts and economy stay valid despite untrusted clients and host | Separate match/Auth/economy/relay adapters | Net/Per/Sec | No service credentials in the client; server-owned value; server dispatch only to own names | X/P/N | Claims are partly client-reported | Security review |
| PAL-065 Casino floor/seating **(Δ)** | S16,S14,S20 | Dealers, 5 tables, 16 slots, Plinko, peeking, sheets. Player-hosted lobbies run the floor through the relay; Supabase still deals | Casino world + server seats | Vis/Net | Stations, seat codes, sheet camera, relay floor sync | X/V/N | Floor seat ≠ economic seat | Visual; net |
| PAL-066 Blackjack | S16–S18 | 4-deck, insurance, split/double, review, side prizes | Server engine; Godot presentation | Num/Beh | House rules, payouts, side awards | X/T/V | Odd-stake rounding | Engine; UI |
| PAL-067 Texas Hold'em **(Δ)** | S16–S18 | Blinds, side pots, rake, showdown. SLIM sits in with **1 or 2** humans (heads-up since v0.10.7), bringing his **whole wallet** if it covers the 2-shard big blind, and stands up when a third person joins. The host can start alone | Server engine | Num/Net | Actions, pots, rake, card privacy, SLIM seating | X/T/N | Folded-card disclosure | Engine; net |
| PAL-068 Roulette | S16–S18 | American 0/00, all bets, 6-s spin, 6-s review | Server outcome; custom board | Num/Vis | Hit zones, payouts, timing | X/T/V | Board geometry | Exhaustive bets |
| PAL-069 Baccarat **(Δ)** | S16–S18 | 8-deck shoe, Banker in 20s, road; centred chip row (v0.10.7) | Server engine + verifier | Num/Per | Banker 19:20, tie, burn/cut | X/P/T | Undealt secrecy | Engine; economy |
| PAL-070 Craps **(Δ)** | S16–S18 | Full bet set, shooter, working toggles; centred chip row (v0.10.7) | Server state machine | Num/Per | Every transition and payout | X/P/T | Lobby-triggered sweep | Exhaustive; faults |
| PAL-071 Slots | S16–S18 | 16 cabinets, real strips, timed stops | Server result; reel presentation | Num/Vis | All 8,000 combos; station isolation | X/V/T | Busy glow | Exhaustive; UI |
| PAL-072 Plinko | S16–S18 | 12 bounces, 13 pockets | Animate the exact server path | Num/Vis | All 4,096 paths; motion never freezes | X/V/T | Poll replaces view | Exhaustive; sequence |
| PAL-073 Reviews/receipts **(Δ)** | S16–S18,S11 | WIN/LOSS/PUSH/PARTIAL, bet/back/net, LAST RESULT. **Result sound once per round, scaled by net/bet**: loss rake, sad trombone at ≥200◆ loss, push clack, win ding, bells+coins, fanfare for big wins (v0.10.8) | Shared receipt UI + audio | Per/Beh/Aud | Review minimums, rejoin completeness, sound mapping | X/P/T/A | Session-only receipt cache | UI; audio |
| PAL-074 Fairness verification | S16–S18 | Seeds, commitments, CHECK, card proofs | Port verifier; server generates | Num/Sec | Hash bytes, shuffle, proofs, disclosure | X | Not a full security audit | Vectors; adversarial |
| PAL-075 Casino transactions/books | S17,S18 | Wallet, stack, felt consistent | Existing atomic RPCs + receipts | Num/Per | One effect per op; balanced ledger; one seat per account | X/P | Pending ID not durable | Economy; faults |
| PAL-076 Performance | S7,S11,S14,S19 | Pacing, loading, long sessions | Bounded caches, streaming | Beh/Aud | Device budgets | L | No phone data | Device; soak |
| PAL-077 Accessibility/localization | S9–S11,S16 | Readable UI, remap, motion, mouse-free | Semantic controls, text resources | Beh/Vis | Keep existing support | X/V/L | Casino navigation gaps | Review |
| PAL-078 Build/release/support | S0,S18,S19 | Install/update, version, diagnostics | Reproducible exports | Per/Beh | Signed, traceable, rollback tested | X/P/L | Unsigned prototype | Rehearsal |
| **PAL-079 Casino relay transport (new)** | S20 | Player-hosted casino lobbies of ≤6 humans; WSS `casino-relay-1`; Supabase token checked on hello and kept current by heartbeats; opaque resume value restores the same peer within **2 minutes**; host leaving closes the lobby; relay restart needs a new lobby; Free tier sleeps when idle (~1-min cold start) | Godot `WebSocketPeer` client implementing the same wire; relay server unchanged | Net/Beh | Same admission, floor messages, backpressure (64 KiB buffered = close; volatile drop at 16 KiB), resume, token refresh and closure messages | X/N/T | **Origin allow-list is browser-only**: native clients need a decided identity/origin policy; single instance; Free limits | Wire fixtures vs `dev/render/test`; mixed browser/Godot lobby; restart/sleep faults |
| **PAL-080 SLIM wallet & house funding (new)** | S17,S18 | SLIM plays from a persistent wallet funded by the signed house result of settled non-poker rounds; a wallet reserved for one table; a negative balance carries forward | Server-side only; client shows SLIM's stack | Num/Per | Funding receipts unique per hand; reservation released on stand-up | X/P | Frozen wallet if a table is abandoned (sweep is lobby-triggered) | Economy; faults |

### Small behaviour contracts (first-class fixtures)

- **Default settings:** volume 0.8, music 0.7, shake 1, haptics on, FPS display off, FPS mode Auto, tips on, build kit on, message time 1, zoom 1.
- **Default setup:** Soldier, Normal, 5 raids, co-op, Yard, standard size.
- **Frame rate:** desktop Auto is capped at 60. Mobile Auto drops to 30 when average frame work exceeds 12 ms over 4 s, or when the battery is ≤30% and not charging. The loop clamps dt to 50 ms.
- **Collision:** radius 0.27, sub-stepped, X axis resolved before Y.
- **Weapons:** a 0.6-s trigger buffer, explicit pull consumption, bursts always complete, pump and bolt events, dry-fire feedback.
- **Controller:** dead zones 0.20 (move) and 0.25 (aim). Reload and Delgado orders are unbound by default.
- **Display:** resize debounce 100 ms, zoom-cache rebuild 140 ms, scale snapped to 5% steps, DPR capped at 2.
- **Nameplates:** drawn after lighting. Enemy PvP health is not shown.
- **Cases:** results commit before the reel animation. Skip or close never re-rolls.
- **Casino seating:** HIDE keeps your seat; STAND UP leaves economically. Craps can keep locked bets after leaving.
- **Focus loss:** solo play pauses when the window is hidden; online play does not. Blur clears keys; touchcancel frees the sticks.
- **Plinko (Δ):** the ball is drawn from the latest view (`TB.v`), so a poll never freezes it. This is a regression fixture.
- **Casino chips (Δ):** baccarat, craps and roulette chip selectors share one centred row (`rchips2`); no bare `.rchip{position:absolute}`.
- **Result sounds (Δ):** play once per round as the receipt appears. Loss of 200◆ or more plays the sad trombone; big wins (4×+ net or 500◆+) play the fanfare.
- **Relay (Δ):** reconnect grace is taken from the server's `graceMs` (1–120 s, default 120 s), and the client refuses a duplicate connection while one is open.

### Defect register (separate from parity)

Preserve intended behaviour and harmless quirks. Confirmed security, corruption or transaction defects need an explicit decision; do not reproduce them in Godot.

| ID | Defect | Status (Oct 13) |
|---|---|---|
| DEF-01 | Casino state leak via inherited request names (`constructor`) | **Fixed** in `tables` v15/v16 (`Object.hasOwn` dispatch). `tables-staging` neutralised Oct 13 (v3 inert stub). Regression fixture for Godot and server. |
| DEF-02 | `import_local_save` accepts any cosmetic ID (≤200), stats ≤100000 (milestone unlocks), 1000 shards and ~350 cases once per account, guests included | **Accepted by owner (Oct 13); not fixed.** Godot must not widen it: keep it one-time and server-gated. |
| DEF-03 | Hold'em side bet: a 1-shard stake pays 10 Hybrid or 15 Flag cases (~3% hit rate), with positive expected value; case issuance is not in `casino_books` | **Accepted by owner (Oct 13).** Preserve as is in Godot (parity). |
| DEF-04 | Stale-table sweep and daily books run only on `op:'lobby'`. Abandoned tables hold shards and seats, and can freeze SLIM's wallet | **Open.** Add a scheduled sweep. |
| DEF-05 | Reward claims are bounded but client-asserted (duration, raids held, bosses, kills) | **Open, accepted risk.** Document it; no Godot change. |
| DEF-06 | Casino pending op ID held in memory (lost on restart) | Open; proposed hardening (D09). |
| DEF-07 | Reward queue: 8-entry retention; account-switch loss | Open; proposed hardening (D09). |
| DEF-08 | `blackout_network` intermittent (`near:false`, ~1 in 3–6 runs); predates v0.10.3 | Open; root-cause before setting network acceptance. |
| DEF-09 | Plinko ball froze mid-drop | Fixed v0.10.3; regression fixture only. |

---

## 5. Proposed Godot architecture

Build in a new, isolated Godot project once implementation is authorized. Preserve the old prototype and its `user://` data.

| Component | Scenes / resources | Ownership and lifecycle |
|---|---|---|
| Application | AppRoot, Boot, screen router | Config, account session, service adapters, transition cancellation |
| Front end | Home, setup, lobby, Index, Locker, Skills, Account, Friends, Settings | Control scenes with a shared theme and explicit focus graphs. Never mutate match state. |
| Match | Match scene: WorldView, input, HUD, overlays | Owns one MatchSession. Closing a screen ≠ ending the network session. |
| Simulation | MatchState, WorldState, PlayerState, ModeState, Combat/AI/Build services | Typed data. Host or solo is the authority; guests hold a replica plus local movement. |
| Definitions | Class, material, weapon, ammo, skill, modifier, map, boss and catalog Resources | Immutable, versioned, keeping the source IDs |
| Presentation | Terrain/scenery layers, stable depth queue, CharacterPainter, effects, light layer, camera | Reads state and events. Never grants value or decides hits. |
| Input | Keyboard/mouse, touch and controller adapters | Timestamped intents. The overlay or focus owner gates gameplay. |
| Networking | SessionController, codec, validation, transport interface | Separates the combat transport (PeerJS/WebRTC) **and the casino relay transport (WSS)** from game messages. Owns sequence and epoch handling. |
| Account services | Auth, Profile, Inventory, Skills, Rewards, Social, Directory, Invitations | Existing HTTPS/RPC contracts, scoped by account and request generation |
| Casino | CasinoSession, **RelayClient** (Δ), TableView, sheets, ReceiptView, ResultSounds (Δ), FairnessVerifier | The server owns deals, outcomes, money, seats and deadlines. The client owns presentation and durable request recovery. |
| Persistence | DeviceConfig, local inventory, legacy import, per-account outboxes, transaction journal | Atomic versioned writes; separate development and production storage |
| Audio | Master/SFX/Music buses, MusicRouter, synthesis | Audio-clock scheduling; two music players for crossfades |
| Platform | Lifecycle, secure credentials, files, haptics, links, install/update | Kept out of the game rules |
| Diagnostics | Structured events, performance counters, replay metadata | Redacts secrets and private cards/seeds |

Autoloads only for services that outlive screens or matches.

**Engine and platform choices**

| Decision | Recommended start | Alternative / trade-off |
|---|---|---|
| Engine | Pin Godot 4.7.2 stable (re-verify the current stable release in Phase 0), with matching templates and hashes | An older branch only if a required extension needs it. The prototype's 4.5 is no reason to stay on it. |
| Language | Typed GDScript; casino server JS unchanged | C#: better tooling, but no Godot 4 web export and numeric translation is still needed |
| Renderer | Compatibility; 2D custom drawing; explicit light/composite layers | Forward+/Mobile only with measured need and full appearance re-check |
| First release | Windows x86_64; keyboard/mouse/controller; browser stays supported | Mobile, macOS/Linux and web each add significant scope |
| Physics | Port the custom movement/collision/pathing | Native CharacterBody only if corner, door, elevation and timing fixtures match |
| Art | Port the procedural geometry and rigs; cache invariant layers | Baking risks losing pose, resolution, lighting and effects |
| Combat multiplayer | Prototype PeerJS/WebRTC interoperability early if cross-play is required | Native transport with separate rooms is simpler, but loses cross-play (explicit exception) |
| **Casino multiplayer (Δ)** | **Implement the existing WSS relay wire in Godot.** Native `WebSocketPeer` needs no extension, which makes this the **lowest-risk cross-client surface** | A separate relay instance for native clients (only if the origin policy cannot be resolved) |

**Projection and collision: a literal port first.**
- `screen_x = (x−y)·TW2 + cam_x`; `screen_y = (x+y)·TH2 + cam_y − height·height_px`.
- Inverse picking intersects terrace and connector planes and keeps the source-equivalent front-most hit.
- Keep body-under-cursor targeting.
- Use a stable depth key with insertion-order ties. Keep back/front scenery layers, wall fades and post-lighting nameplates.
- Native Y-sort cannot replace the full ordering contract.

**Timing.**
1. Replay identical dt and input traces through both simulations.
2. Then evaluate a fixed 60 Hz simulation at 30/60/120/144 Hz display rates. Adopt it only if fire cadence, collision, AI, damage over time, extraction, regeneration and input latency stay acceptable.
3. Never let suspended time catch up in a burst.
4. Keep wall-clock, simulation, audio and presentation time separate.

**Numerics.**
- JavaScript's `Math.imul`, `>>>`, negative `%`, truncation and `Math.round` need compatibility helpers and golden vectors.
- Keep authoritative coordinates in scalar doubles; Godot's Vector2 is single precision.
- The browser uses `Math.random`: record and replay random streams for comparisons, and separate the gameplay, cosmetic, audio and shuffle streams.
- Casino RNG stays on the server, and the verifier reproduces it exactly.

**The old Godot project (PC, Oct 7)** is a source of techniques, not truth. Its material costs, classes, capacities, 20 Hz snapshots and numeric protocol `3` all differ from the browser. It writes `user://prefs.cfg`, so use separate storage.

---

## 6. Multiplayer, accounts and economy

| Boundary | Current responsibilities | Conversion contract |
|---|---|---|
| Local player → combat host | Guest moves locally; sends position, aim, trigger and actions at 30 Hz | Keep responsive local movement and correction; treat all input as untrusted |
| Combat host → guests | Host runs enemies, projectiles, damage, building, modes and Delgado; 15 Hz state on unordered channel 1000; reliable events at 5 Hz; walls in full every 10 s plus diffs | Host remains the authority; a listen host gives no anti-cheat |
| **Casino player ↔ relay (Δ)** | WSS hello carries the Supabase token, role, code, incarnation and resume value; the relay verifies against Auth; heartbeats keep the token current; the host runs the floor | Same wire; the relay never holds service keys; native origin policy decided |
| Client → Supabase Auth | Sign-in, anonymous accounts, refresh, upgrade, recovery | Same project and UUIDs |
| Client → account RPCs | Locker, equip, skills, claims, cases, social | Server validates identity, revision and grants |
| Client → casino Edge Function | Wagers, actions, seats, state, history, CHECK; polled once a second | Server decides outcomes and disclosure; requests dispatch only to the server's own names |
| Edge Function → database | Atomic state, ledger, op receipts, seats, SLIM wallet | Service credentials stay server-side |
| Client → signaling/TURN/directory | 0.peerjs.com signaling; TURN credentials from a Cloudflare Worker (site-specific check); `lobbies` directory | Native access must be explicitly supported; never embed relay secrets |

**Timeouts:** match silence 12 s; lobby silence 25 s; join 15 s; relay resume 120 s.

**Godot WebRTC:** native WebRTC needs the webrtc-native extension, which does not certify PeerJS signaling, serialization or channel compatibility. A protocol prototype is required. The TURN Worker's hostname check excludes native clients until it is changed (a later authorized phase).

**Cross-client coexistence**

| Surface | Option | Proof / consequence |
|---|---|---|
| Combat | Compatible cross-play | PeerJS wire parity, identical rules and content, mixed-host tests, TURN/NAT tests |
| Combat | Separate populations | Transport-aware directory and room keys; explicit approval to lose cross-play |
| **Casino (Δ)** | **Shared relay lobbies** | Same `casino-relay-1` wire, identical floor messages, mixed browser/Godot lobby tests; native origin policy decided |
| Casino economy | Shared by both clients | One seat per account and op-id rules already enforced server-side |

Separate rooms must not overwrite each other. The lobby and room-session rows are keyed by host UUID, so add a transport-aware key with targeted cleanup and incarnation checks.

**Every value-changing operation must survive an uncertain answer.** This applies to case openings, casino actions and reward claims:

1. Create the op ID and immutable request before sending.
2. Persist the owner UUID, payload, op ID and status atomically.
3. Send through one mutation coordinator.
4. On timeout, disconnect, suspension or restart, retry the same op.
5. Fetch the authoritative state or receipt.
6. Present the result only once it is authoritative.
7. Acknowledge only after the result is safely persisted.
8. Partition everything by account.

Casino op records bind the user and op ID to a canonical request hash (excluding the seed). Retries must keep the original seed. Reward receipts bind payloads more weakly, so review each purchase RPC separately.

**Security posture (Oct 13).**
- RLS is on for all public game tables. `casino_start`/`casino_step`/`casino_open`/`casino_commit` cannot be executed by `anon` or `authenticated`.
- `tables` has gateway JWT verification off, but validates callers itself and refuses anonymous players. **Since v15 it dispatches only to its own request names.**
- `tables-staging` still runs the vulnerable dispatch (§0).
- Supabase advisors report leaked-password protection off, and SECURITY DEFINER RPCs callable by `authenticated`; the latter is by design and needs per-function review.
- `backup_20261006` copies policies but grants nothing to client roles; it is not exposed.
- Before release, review:
  - grants, exposed schemas, definer search paths and identity spoofing;
  - refresh races, chat and name limits;
  - malformed packets and floods;
  - save tampering and rate limits;
  - **relay abuse limits (rooms, payload, connection rate).**
- The Supabase default-exposure change for new tables (Oct 30, 2026) means any new directory table needs deliberate grants and RLS.

---

## 7. Save and data compatibility

| Storage | Contents / owner | Plan |
|---|---|---|
| `palisade.cfg.v1` | Device settings | Versioned device config; all fields |
| `palisade.pad.v1` | Controller bindings | Settings transfer (not in the save export) |
| `palisade.best.v3` | Records by mode/difficulty/map/size/modifiers | Exact key and tie-break |
| `palisade.locker.v1` / `.bak` / `.corrupt` | Local or cached locker; recovery copies | Import local; the cloud cache never overrides the server; keep recovery copies |
| `palisade.auth.v1` / `.auth.guest` | Session; parked guest | Secure credential storage; same-identity handoff; never in save files |
| `palisade.claims.v1` | Pending reward queue | Per-account durable outbox |
| `palisade.runDraft.v1` | Interrupted-run draft | Recover with the original match info |
| `palisade.case-opening.v1.<owner>` | Pending opening | Keep owner, case, quantity and op ID; recover from the server |
| locker `lastOpening` | Local opening receipt | Include it so an interruption never re-rolls |
| session `palisade.roomSession` | Per-tab reconnect/ban ID | Scoped native session ID |
| `pal_seed` | Casino seed preference | Transfer |
| session `pal_rcpt` | LAST RESULT cache | Keep; server history is authoritative |
| Relay resume value (Δ) | In-memory only (`RLY.resume`), never stored | No migration; reconnect within 120 s or rejoin |
| `PALISADE-SAVE-1` | Base64 JSON v1 + CRC32 | Read-compatible importer |
| Service-worker caches | Shell + lazy music | Browser only; native uses package/cache hashing |
| Prototype `user://prefs.cfg` | Old Godot settings | Never overwrite |

The save export omits:
- pad bindings, claims, drafts and pending openings;
- Auth;
- casino preferences and receipts;
- skills/SP, zoom and message time.

It is not a full migration.

Cloud records keep their identities:
- Auth/profile UUIDs.
- Locker fields (`owned`, `eq`, cases, bag, shards, progress, stats, skills, `rev`, `imported`, play budget).
- Match receipts.
- Case and catalog IDs.
- Social IDs.
- Directory and invitations: host UUID, code (combat 4 characters / casino `R`+5), proto, incarnation.
- Casino: table/hand IDs, room/game/station, `ver`, rule version, op IDs and hashes, seats, ledger, books, **SLIM wallet and funding receipts (Δ)**.

Use strings for bigints at JSON boundaries.

Migration procedure:
- Saved accounts simply sign in.
- Anonymous accounts need a same-UUID handoff or upgrade.
- Local imports validate, show a preview, keep the raw copy, write a temporary file, verify it, then atomically commit a marker. Re-running never doubles anything.
- On a stale revision, refetch and re-evaluate; never use last-write-wins on balances.
- Don't share refresh tokens between clients, because of rotation races.
- **DEF-02 must be fixed before any Godot "import local save" path ships.** Otherwise the importer extends the exploit.

Backups: the free plan has no automatic backups (the manual `backup_20261006` snapshot is the only one). A backup is accepted only after an isolated restore rehearsal plus ledger validation.

---

## 8. Asset and presentation pipeline

| Category | Sources | Preservation |
|---|---|---|
| Terrain, walls, scenery, city, casino | S3,S7,S16 painters | Port geometry, palettes, strokes, opacity and order; cache invariant layers and invalidate on change |
| Characters, weapons, bosses | S7 | Facing, clocks, muzzle/recoil/pump points, hats, silhouettes; no static replacement |
| Cosmetic effects | S8,S15 | One implementation for world, stage, thumbnails and cases |
| Backgrounds | S8 | Static layers separate from animation; reduced-motion path |
| UI, cards, dice, reels, wheel, Plinko | S0,S9,S16 | Coordinates, hit regions, fonts, symbols, timing, server-result animation; **centred chip rows (Δ)**; **casino sheet width rules (Δ)** |
| Fonts | 5 WOFF2: Big Shoulders Stencil 600/800/900, IBM Plex Mono 400/600 | Import the originals; tune metrics against browser captures |
| Music | 18 tracks × AAC+Opus, 36 files, **160,512,859 bytes** | Keep decoded content and cues; choose a supported Godot codec from the masters |
| Procedural SFX | S11 (≈95 cues + **casino result cues (Δ)**) | Reproduce oscillator/noise/filter/envelope behaviour and limits; validate captures |
| Lighting/compositing | Canvas code | Document blend modes, colour space and alpha; shaders only where needed |
| Icons/package | Builder, manifest | Reuse identity |
| Evidence | S19 | Test only; excluded from packages |
| Masters/archives | Audio masters, casino masters, old projects | Preserve; confirm provenance and rights |

Texture defaults:
- lossless storage;
- no lossy VRAM compression and no UI mipmaps;
- filtering chosen per source (linear is the starting candidate);
- tests for edges, premultiplication, gradients and atlas padding;
- no new tonemapping.

Godot imports WOFF2. Its native audio import is WAV, Ogg **Vorbis** and MP3, but the browser's `.ogg` files are **Opus** and its `.m4a` files are AAC, so plan to re-encode from the masters and validate loop endpoints.

Soundtrack contract:
- **Routed tracks:** `main_menu`, `between_raids`, `raid_attitude`/`cool`/`express`, `final_blitz`, `results` (cue at 164 s, pre-trimmed).
- **Casino:** `casino_1`–`11` in a shuffle bag with no immediate repeat and a 5-s equal-power crossfade.
- **Resume:** hide or mute resumes the same route and offset.
- **Memory:** the decoded menu track is ~168 MiB, and the largest casino overlap ~290 MiB, which argues for streaming with exact endpoints.

**Licensing is unresolved.** The external music, the owner-supplied casino music, the fonts, character references and catalog names all need a rights review before any new-platform distribution.

---

## 9. Production risks and targets

**Recorded evidence:**
- **Casino:** software-rendered Chromium at the 60 FPS cap, 8.3–10.2 MB JS heap, ~60 requests/min seated and ~72/min at machines.
- **Six-player host state:** ~140–160 KB/s.
- **Blackout city:** avg/p95 28.7/82.7 ms on desktop and 34.9/104.6 ms on the phone viewport (a stress signal only).
- **Root audio:** 160.5 MB.
- **Relay (Δ):** live six-browser verification passed on Oct 8–9, including cold start. See `dev/evidence/casino-relay-2026-10-08/` and `2026-10-09-casino-connection/`.

| Area | Proposed target (calibrate later) |
|---|---|
| Desktop pacing | 60 FPS; p95 ≤12 ms, p99 ≤16.7 ms |
| Mobile/low-power | Stable 30 FPS fallback, no thermal drift |
| Input latency | ≤ browser + 1 frame |
| Memory | <512 MiB resident; <128 MiB textures/caches; <32 MiB streamed audio |
| Long sessions | 8 h desktop soak; 2 h mobile thermal; repeated match/account/scene cycles |
| Loading | Warm menu ≤2 s; cold ≤5 s; match entry ≤3 s |
| Package | Core ≤75 MiB without music; a single music codec |
| Network | Keep 30 Hz input / 15 Hz state; traffic no worse than the browser |
| Casino requests | Keep the 1 Hz poll; no retry storms |
| **Relay (Δ)** | Free tier: ≤10 rooms; cold start ~1 min. Godot clients must not add idle traffic or keep-alive bots |

Also cover:
- **Devices and display:** resize, DPI, ultrawide, safe areas, touch/keyboard/controller switching, controller unplug.
- **Lifecycle:** sleep/resume, audio and network changes, low disk, memory pressure, OS termination.
- **Accessibility:** keep existing support. The new gaps found in casino sheets and boards are separate improvements.
- **Localization:** message keys; pseudo-localization and 30–50% text expansion.
- **Crash reports:** build/content/protocol versions, redacted.
- **Builds:** pinned toolchain and dependencies (including the edge function's broad `supabase-js@2` import and relay `ws@8.22.0` on Node 22); manifests, signatures and notices; debug hooks excluded.
- **Ownership:** a named owner per system.
- **Platform policy:** simulated gambling (casino with play currency), randomized rewards, chat, account deletion and privacy all need store and rating review. There is no real-money purchase or cash-out today.

---

## 10. Parity verification program

Control for every comparison:
- source and backend versions;
- viewport, DPI and zoom;
- fonts, renderer and settings;
- device, start state, input/dt trace and RNG stream;
- players, difficulty, modifiers and cosmetics;
- network conditions and sample rate.

Casino goldens use isolated server fixtures, never production wagers.

| Family | Method | Pass |
|---|---|---|
| Rules | Pure-function fixtures | Exact |
| Movement/combat | Timestamped traces at 30/60/120/144 Hz | Same order, paths, outcomes |
| Maps | Generated grids and mutations | Exact geometry |
| Visual | Every map/time, class, boss, cosmetic and UI | V + human approval |
| Audio | Loops, routes, crossfades, SFX, **casino result cues** | A |
| UI/input | Every screen, state, scroll, focus, cancel, remap | No unreachable action |
| Multiplayer | 2/6 clients, host/guest, late join, kicks, chapters | Same state and outcome |
| **Relay (Δ)** | `dev/render/test` wire fixtures; mixed browser/Godot casino lobby; resume within 120 s; token refresh; relay restart; Free cold start | Same admission, sync, closure messages |
| Faulted network | Latency, loss, reorder, stalls, host loss | No desync or duplicate value |
| Saves/accounts | Imports, anonymous upgrade, corruption, stale revisions, switching | No loss or leak |
| Economy | Interrupt at every stage; duplicate and changed payloads | One effect; receipt recoverable; books balance |
| Casino math/fairness | Engine vectors, all slot/Plinko outcomes, craps transitions, proofs; **DEF-01 regression (inherited op names refused)** | Exact |
| Lifecycle/soak | Focus, sleep, device changes, long runs | L |
| Feel | Experienced players on matched scenarios | Accepted |

Start from `suite.txt`: 117 active entries, extras included explicitly, and 6 relay tests. Label each test's boundary (mock vs staging vs production).

Latest recorded evidence:
- v0.10.7: server suites, `tables_ui`, `casino_games_ui`, `casino_relay_tables` and `csp` passed.
- v0.10.8/v0.10.9: `casino_games_ui`, `tables_ui`, `casino_map`, `casino_music` and `reel_music` passed.
- There is no recent full-suite pass. DEF-08 remains.

Per-PAL record: source version, implementation, test version, environment, result, evidence, reviewer and exceptions. Statuses: `not_started`, `in_progress`, `implemented_unverified`, `blocked`, `verified`.

**Release blockers:**
- lost or duplicated value;
- wrong casino outcome or disclosure;
- account replacement or cross-account access;
- destructive save conversion;
- reproducible desync;
- missing content;
- crash or stuck input;
- unbounded resource use;
- unapproved departures from the baseline;
- **any re-introduction of DEF-01 or an extension of DEF-02**.

---

## 11. Roadmap

| Phase | Deliverables | Exit criteria | Risk / rollback |
|---|---|---|---|
| 0 Baseline certification | Hash fonts and music as served; backend contract snapshot (`tables` v16, schema, relay revision); **fix or decide DEF-01 staging, DEF-02, DEF-03, DEF-04**; defect/exception register; scope decisions | Target recorded; every PAL ID has an owner | Wrong oracle → return to the frozen v0.10.9 |
| 1 Fidelity slice | Yard movement/build/combat, Soldier burst, wall/door, a raider, Delgado, HUD/pause/settings, one music route + SFX | Matched traces pass; camera/collision/numerics accepted | Renderer/timing rework; disposable prototype |
| 1B Boundary probes | Frostpeak ramp/occlusion; 64×64 city; casino review/fairness; staging Auth + uncertain transaction; **casino relay client (WSS wire, resume, refresh)**; combat cross-play probe if required | Each hard boundary has evidence and a chosen approach | Transport/codec/platform failure → revisit architecture |
| 2 Simulation/content | All classes, building, armory/ammo/skills/mods, AI/bosses, maps | Complete rule coverage | Global-state extraction |
| 3 Modes | Co-op/PvP, Blitz, Whiteout/Gauntlet, Blackout/Destroyer, recovery/results | Every mode completes with matched outcomes | Epochs/interest filtering |
| 4 Presentation/UI/audio | All art, catalog, backgrounds, screens, input, 18 tracks, SFX, all casino sheets + result sounds | All content IDs mapped; V/A/UI pass | Art/fonts/audio rework |
| 5 Services/persistence | Auth, RPCs, social/directory, claims/cases, save import, casino requests/history/verifier, relay lobbies, durable recovery | Staging fault matrix clean; ledger reconciles | Anonymous handoff, room collision |
| 6 Qualification | Full parity, hardware/thermal/soak, security/a11y/l10n review, signed packages | All required PAL IDs verified | Hidden device gaps; browser stays the fallback |
| 7 Staged release | Internal → alpha → beta → wide | Clean observation windows; rollback rehearsed | Halt and revert the client |

**Critical path:** baseline → numerics, collision and rendering → transport (relay first, then PeerJS) and account recovery → modes and economy → hardware and human parity → release.

**Effort** (low confidence until Phase 1; Windows only, full content, retained backend):

| Work | Estimate |
|---|---|
| Engineering | 45–80 person-weeks (+1–3 for the relay client) |
| QA and automation | 15–25 |
| Art, audio and content verification | 8–14 |
| UX, a11y, security and release specialists | 4–8 |

That is about 7–11 months for three engineers, dedicated QA and part-time specialists.

Keep a browser-to-Godot change queue. No browser fix counts as ported until the affected PAL contracts and tests are updated. **Since the Oct 7 draft, five releases (v0.10.5–v0.10.9) already form the first queue entries**, absorbed into this revision.

---

## 12. Release, coexistence and rollback

Keep the browser available through beta and early desktop release, on the same backend, accounts, catalog, inventory and casino history.

| Stage | Admission | Rollback |
|---|---|---|
| Internal | Staging fixtures, no production economy | Replace freely |
| Closed alpha | Cohort, controlled backend access | Revert client; keep pending work and receipts |
| Limited beta | Small production cohort after economy and Auth certification | Stop new mutations; existing bets still resolve |
| Wider rollout | After clean stability and integrity evidence | Return to a known-good client |
| General | Approved parity register, platform clearance, support staffed | Tested client rollback |

**Halt conditions:** any value loss or duplication, account ownership fault, wrong fairness or payout, reproducible desync, blocking save failure, or crash/performance rate above threshold.

**Rollback rules:**
- Never restore an old database over valid new transactions; prefer a client rollback and forward-compatible server fixes.
- Drain open tables before any incompatible backend change.
- Keep receipts, ledger and retired rule versions.
- **The relay is stateless across restarts (lobbies close), so a relay rollback only interrupts open casino lobbies; the casino economy is unaffected.**

**Support:** same-account sign-in, anonymous handoff, damaged imports, pending claims and openings, bets still resolving, **relay reconnect/expiry messages**, compatibility errors. Never make ad-hoc grants without a reviewed compensating transaction.

---

## 13. Risk register

| Rank / ID | Risk | Impact / likelihood | Mitigation (owner) |
|---|---|---|---|
| 1 / R01 | Lost or duplicated value after uncertain responses | Critical / High | Durable ops, fault tests, reconciliation (economy) |
| 2 / R02 | Anonymous player becomes a new account | Critical / Medium | Same-UUID handoff (Auth) |
| 3 / **R18 (Δ)** | **Stale or out-of-process backend deploys reintroduce fixed defects** (`tables-staging`; v10/v14/v16 PC redeploys) | Critical / **High** | Delete staging; deploy log; contract fingerprints checked in CI (backend/release) |
| 4 / **R19 (Δ)** | **Economy exploits still open (DEF-02, DEF-03) carried into, or widened by, Godot import paths** | Critical / Medium | Fix before Phase 5; import gated by the server (economy) |
| 5 / R03 | Combat cross-client protocol mismatch | High / High | Early probe; explicit boundary (network) |
| 6 / R04 | Collision or timing changes the feel | High / High | Literal port, traces (simulation) |
| 7 / R05 | Procedural art loses identity | High / High | Render slice, full coverage (tech art) |
| 8 / R06 | Campaign/Blackout desync | High / High | Epoch fixtures; root-cause DEF-08 (network/modes) |
| 9 / R07 | Browser/Godot drift | High / **Very high** (5 releases in 4 days) | Frozen target + change queue (producer) |
| 10 / **R20 (Δ)** | **Relay origin policy blocks native clients, or Free-tier limits (sleep, 10 rooms, single instance) degrade the casino** | High / Medium | Decide the native identity/origin policy; capacity plan (network/ops) |
| 11 / R08 | Room cleanup collisions between clients | High / Medium | Transport-aware keys (backend) |
| 12 / R09 | Partial save treated as complete | High / High | Full inventory + preview (persistence) |
| 13 / R10 | Music rights, codec or memory | High / Med–High | Rights review, codec probe, streaming (audio/legal) |
| 14 / R11 | Mobile/low-end failures | High / High | Physical devices (perf/QA) |
| 15 / R12 | Hidden data exposed via verifier, history or server echo | Critical / Medium | Exact disclosure contracts; DEF-01 fixture (security) |
| 16 / R13 | UI/controller/a11y regressions | High / Med–High | Focus/navigation review (UX) |
| 17 / R14 | Old evidence mistaken for certification | High / High | Version metadata, suite manifest (QA) |
| 18 / R15 | Backup or downgrade loses records | Critical / Medium | Restore rehearsal (release) |
| 19 / R16 | Platform policy constraints (simulated gambling) | High / Medium | Early store/rating/legal review |
| 20 / R17 | Privilege and dependency drift | High / Medium | Fingerprints, pinning (backend/release) |

---

## 14. Decision log

| ID | Recommendation | Alternative / open point |
|---|---|---|
| D01 Baseline | **Decided Oct 13:** v0.10.9 `4c26769` + `tables` v16 + relay `casino-relay-1` | Later releases go through the change queue |
| D02 Platforms | **Decided Oct 13:** Windows first, targeting **Steam and/or the Epic Games Store**; the browser stays | Minimum hardware still open. Store review covers simulated gambling, loot boxes, chat and age rating. Steamworks/EOS services (overlay, achievements, cloud saves) stay behind platform adapters (D13). |
| D03 Toolchain | Current Godot 4.x stable, typed GDScript, Compatibility | Extension constraints |
| D04 Simulation | Custom collision and source timing first | Fixed 60 Hz / native physics only with evidence |
| D05 Art | Procedural port, selective caching | Baking only with pose/effect proof |
| D06 Combat cross-play | **Decided Oct 13: browser ↔ standalone cross-play required.** Online model not yet chosen; the owner leans towards keeping the current browser-style player-hosted P2P (PeerJS/WebRTC). That is also the only model that gives cross-play without new servers, so it is the working assumption. | Godot needs webrtc-native plus a PeerJS-compatible signaling/framing layer and channel 1000, proven in Phase 1B. Steam/EOS networking can't reach browsers, so it isn't used for matches. The TURN Worker must accept native clients. |
| **D15 Casino transport** | **Decided Oct 13:** Godot implements the existing WSS relay wire, with one shared browser/standalone casino population. **Casino only.** | Native origin/identity policy still to design |
| D07 Backend | Keep Auth, economy, casino and relay | Additive endpoints only where needed |
| D08 Identity | Keep UUIDs; designed anonymous handoff | Credential storage design |
| D09 Integrity hardening | Durable outboxes and casino pending IDs | Approve the parity differences |
| D10 Defects | Separate register. Fix DEF-01 staging and DEF-04 before Phase 5. **DEF-02 and DEF-03 accepted by the owner (Oct 13).** | Disposition of the non-integrity quirks |
| D11 Audio/assets | Keep content; validate rights and codecs | Rights gaps may force an exception |
| D12 Acceptance | Exact outcomes; measured presentation tolerances | Calibrate on captures |
| D13 Store integration | Behind adapters | Steam/etc. scope separately |
| D14 Release | Staged coexistence, client rollback | Browser retirement decided later |

---

## 15. Decisions

**Answered by the owner on October 13:**

| # | Question | Answer |
|---|---|---|
| 1 | Import exploit (DEF-02) and side-bet minting (DEF-03) | Ignore both; accepted as is |
| 2 | Target | v0.10.9 `4c26769` confirmed |
| 3 | Platforms | Windows; aiming for Steam and/or the Epic Games Store |
| 4 | Combat cross-play | Required, browser ↔ standalone |
| 5 | Casino relay | Yes, for the casino only |

**Still open:**
1. ~~Delete `tables-staging`~~: neutralised Oct 13 (inert v3 stub); deleting it later is optional.
2. The combat online model. The working assumption is the current player-hosted P2P (PeerJS/WebRTC), which cross-play effectively requires. Confirm after the Phase 1B probe.
3. Minimum Windows hardware, and Steam vs Epic vs both (each has its own review, SDK and identity integration).
4. Keep the backend and account UUIDs, with a designed anonymous-account handoff (and how a Steam/Epic identity links to it).
5. The integrity-hardening exceptions: durable pending ops, account-partitioned rewards, safe import.
6. Asset and music redistribution rights, and the Steam/Epic content and age-rating questionnaires (simulated gambling, randomized items).
7. Authorize the next verification phase: isolated runs, captures, local and staging tests.
8. Name the final parity approver.

The remaining uncertainty is concentrated in:
- font and music served-hash certification;
- live Auth configuration;
- physical-device behaviour;
- combat transport interoperability (the critical path, now that cross-play is required);
- the native relay origin policy;
- the anonymous and store-identity handoff;
- licensing;
- final tolerance calibration.
