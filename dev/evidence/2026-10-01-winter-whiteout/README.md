# Winter expansion: v0.9.6.0

Implemented October 1, 2026 from the [winter work order](../../plans/winter-elevation-campaign-and-friend-invites-work-order.md). **Publication was authorized October 1.** [Release commit `92d3c16`](https://github.com/lopoke89-ops/palisade/commit/92d3c16608225f61e4d513b7c287a768834933ae) is pushed to `main`; [Pages deployment](https://github.com/lopoke89-ops/palisade/actions/runs/36845257315) succeeded. Live production footer, protocol, exact committed file hashes, campaign/Frostpeak starts, current service-worker cache and eight mobile Armory layouts are verified. Backend migrations for this expansion are applied and verified.

Release protocol: **`yard-21`**, room prefix `palisade-yard-21-`. Service worker: **`palisade-dc87756470`**. Generated production `index.html` and `sw.js` are ready. Debug hooks are absent from production; `debug.html` and transient test output remain ignored.

## Release notes

- **Frostpeak:** standard and XL snowy mountain defense maps, summit core, three actual height tiers, two uphill approaches with ramps/stairs, terrace-aware movement and combat, snow-covered pines, expedition equipment and a summit beacon. Available in solo/co-op 5, 10, Endless, Blitzkrieg Rush and campaign.
- **Rime Colossus:** original ice armor, reservoir and maul silhouette; huge marked Glacial Rupture; Venom Rush leaving poisoned frost that slows everyone crossing it; coordinated health phases and bounded hazards.
- **Operation Whiteout:** one continuous Yard â†’ Riverbend â†’ Quarry â†’ Frostpeak campaign. Three raids and a revamped boss per chapter, persistent kit/core damage, short chapter preparation, then one five-minute personal evacuation finale.
- **Winter collection:** exactly 10 skins, 10 matching headgear, 10 backgrounds (four animated), six tracers (two Gold) and six kill effects (two Gold). Eight milestone skins plus 34 Winter Case items. All hats also fit supported Sahur characters.
- **Friend invitations:** host accepted-friend invitations from the Friends list, including private rooms; in-app mailbox with Accept/Decline and deliberate Leave & Join confirmation; usable from the pause menu with touch/controller. Five-minute expiry, duplicate suppression, authenticated authority checks and room-incarnation binding.
- **Reliability:** height validation prevents forged cliff traversal. Late join and reconnect preserve chapter, actual height, kit and personal evacuation state. Reconnecting within the same preparation epoch cannot refill HP/grenades. Account switches and session changes invalidate pending invitation actions. Retry receipts prevent duplicate account rewards.

See the [balance sheet and simulation contracts](BALANCE.md) and [complete cosmetic catalog](CATALOG.md).

## Architecture and compatibility

The existing Canvas 2D renderer, shared-scope source assembly, PeerJS transport, Armory, account progression and Supabase social systems are extended in place. There are no added runtime dependencies or downloaded art assets. All new artwork is procedural; existing wardrobe workers and bounded caches remain the rendering path.

| Module | Responsibility |
| --- | --- |
| `06d-elevation.js` | Frostpeak layouts, height graph/collision/rays/range, frost fields, terrain art |
| `10d-winter-campaign.js` | Chapter transitions, continuity, four new boss definitions, clipped warning art |
| `16d-winter-data.js` | Stable IDs, descriptions, tiers and pairings for 42 cosmetics |
| `18a-winter-catalog.js` | Client registration, acquisition, milestone ladders and backgrounds |
| `18d-winter-scenes.js` | Shared cached winter backgrounds and bounded motion |
| `19d-friend-invites.js` | Authenticated room registration and accept/decline UI flow |
| `20b-winter-effects.js` | Shared snowflake painter and six kill effects |

Integration edits cover projection/input, pathfinding, boss attacks, ammo, chapter-aware HUD/results/records, selectors, Friends overlays, host validation, snapshots, reconnect and claims. [ORDER.txt](../../src/js/ORDER.txt) documents actual lexical assembly order. Old cosmetic network indices and storage keys retain their meanings; new IDs and enemy codes are appended. Protocol 21 isolates the changed movement, height and cosmetic packet shapes from older clients.

The authoritative checkout is `sahur-open-games`, branch `codex/sahur-open-games`, starting at `3d540554965a109f62955ae6ecb487785efc18c6`. Preexisting repository cleanup was already uncommitted. Its original status and binary diff were saved under ignored `dev/test/out/winter-preexisting-*` before expansion edits. Other project checkouts were not modified. The [focused expansion inventory](change-inventory.json) describes the local feature delta. Publication uses a separate Git worktree at that starting HEAD, applies only the winter changes, preserves the prior README history, and rebuilds production output. Preexisting cleanup is excluded from the release commit. The ignored local review patch remains in the source checkout; the release commit is the published diff.

## Backend state

Both migrations are applied to project `puvjfhwxigxjpsvdwrwf`:

1. [20261001081259_winter_whiteout.sql](../../supabase/migrations/20261001081259_winter_whiteout.sql): additive catalog/descriptions, Winter Case, campaign lobby constraint, server chapter/map/boss accounting and private reward receipts.
2. [20261001081316_friend_lobby_invites.sql](../../supabase/migrations/20261001081316_friend_lobby_invites.sql): private room sessions/invitations, authenticated registration/send/answer RPCs, notification and social-state integration.

The [before-change function snapshot](../../supabase/snapshots/20261001_before_winter_whiteout.json) preserves the live reward/social definitions used to construct these migrations. Historical `schema.sql` remains a baseline snapshot; it does not replace the migration chain.

[Read-only live verification](backend-verification.json) confirms 42 catalog items with descriptions, 34 case entries, correct rarity counts/cost/weights and the campaign lobby constraint. The five relevant account/social RPCs deny anonymous execution and use empty search paths. Private room, invitation and receipt tables have RLS enabled and deny direct authenticated access. Tests exercise their intended RPC access.

Security advisors retain the existing blocked-words policy, anonymous-policy and leaked-password findings. The new three private tables intentionally have RLS with no direct-access policies, and the three new authenticated definer RPCs add corresponding informational advisor entries. These are documented restrictions and intentional RPCs; this is not a claim of an empty or unchanged advisor report. Performance advisors include foreign-key/index findings and newly created invitation indexes with no observed usage yet. Full before/after findings are retained in the backend JSON.

### Invitation contract

| Situation | Behavior |
| --- | --- |
| Sender | Saved signed-in account, host of a current room, accepted friendship, unlocked room with fewer than six players |
| Public/private room | Both register a private authenticated host session; public discovery is a separate listing |
| Freshness | Host refreshes every 15 seconds; server requires a registration no older than 45 seconds |
| Expiry | Five minutes; duplicate pending sends return the same invitation without extending expiry |
| Limits | At most 10 sends/minute and 30/hour per sender |
| Accept/Decline | Recipient only, safe to retry; accept rechecks friendship, bans, expiry, room incarnation/code, slots, lock and protocol |
| Host departed/stale, full, locked or old client | Clear server/join error; no automatic room transfer |
| Reused code | Old invitation fails incarnation checks in the RPC and PeerJS hello |
| Current room/run | First tap shows confirmation; second Leave & Join explicitly exits and joins |
| Account/session changes during request | Ignore the old account response, or cancel joining if the room/run changed |
| Notifications | In-app polling and mailbox; no OS push or external messages |

The local UI test uses account RPC fixtures and a real PeerJS private host/guest join. Persisted invitation/security behavior is verified separately against disposable Postgres using the actual migrations. Live checks inspect definitions, grants and catalog; they do not send invitations to real players.

## Verification

Build command:

```powershell
$env:NOMIN = '1' # additionally emits ignored debug.html; index.html remains production/minified
python dev/build.py
```

Focused verification command:

```powershell
& dev/test/run_targeted.ps1 -Tests 'winter_elevation winter_combat winter_cosmetics winter_scene winter_network winter_reconnect winter_invites winter_migration winter_offline winter_performance'
```

**29 distinct tests passed** on the prepublication candidate across the recorded runs, including ten new expansion tests and affected existing regressions. [verification.json](verification.json) records exact test names/log timestamps, build hashes and output sizes. The selected regression suite is not a full replay of every historical test on the final build. After release isolation and rebuilding, **11 publication checks passed**: elevation, combat, cosmetics, six-client network, reconnect, invitations, migration, real production/offline, CSP, all 73 Armory layouts and controller. Exact release hashes, timestamps and supplementary logs/JSON are in [release-verification.json](release-verification.json) and `release-gate/`; the original candidate measurements remain intact.

| Area | Evidence |
| --- | --- |
| Elevation | [Traversal/projection JSON](winter_elevation.json): standard/XL uphill enemy routing, cliffs/connector sides, no-build connectors, four exact surface inversions, preserved map thumbnails, campaign carryover and reachable evacuation |
| Combat | [Combat JSON](winter_combat.json): uphill/downhill shots, terrain-blocked rays, 128 elevated muzzle checks across classes/headings, full warning duration/damage, actual dash frost, burn DPS, boss slow cap, 64-field cap, transition once-only and late boss credit |
| Six clients | [Network JSON](winter_network.json): six real PeerJS browsers on chapter 4, forged cliff move rejected, valid ramp accepted, late join, synchronized finale and different personal results |
| Reconnect | [Reconnect JSON](winter_reconnect.json): chapter transition recovery once, same-epoch ramp HP/grenades preserved, extracted state retained |
| Cosmetics | [Catalog/pose JSON](winter_cosmetics.json): exact counts, four animated backgrounds, Gold counts, 1,280 class/angle/downed poses including Sahur, description/acquisition coverage |
| Friends | [Invitation UI JSON](winter_invites.json): private host, decline/resend/real join, in-game mailbox, deliberate confirmation, account switch and changed-session guards |
| Server | [Migration JSON](winter_migration.json): 30 named checks plus rejection cases; migrations apply twice, real reward/unlock/case functions, retry/late/missed progression, private invitation authority, expiry/stale/full/lock/protocol/bans/rates/grants |
| Production/offline | [Offline JSON](winter_offline.json): real minified page, no debug hooks, real cached service worker, offline reload, campaign start, four ammo choices and Frostpeak start through touch UI |
| Armory | [Layout JSON](armory_layout.json): 73 layout cases, ten portrait/landscape sizes down to 320Ã—480 and 568Ã—320, both tabs, Sniper slots and 44-pixel minimum buttons; no scrolling |
| Shared behavior | Existing solo, multiplayer, room controls, old-protocol rejection, rejoin, bosses, Blitz mode/boss/network/milestones, ammo/online purchases, cosmetic networking, headgear fit, touch lock, muzzle, controller and CSP regressions |

Visual review covers [collection contact sheet](winter_collection.png), [standard battlefield](winter_frostpeak_std.png), [XL battlefield](winter_frostpeak_xl.png), [touch portrait](winter_frostpeak_mobile.png), [lobby invitation](winter_friend_invite.png) and [in-game mailbox](winter_in_game_invite.png).

## Performance and network measurements

[Raw comparison](winter_performance.json): Windows desktop Chrome **154.0.8037.92** with software Canvas (`--disable-gpu --disable-accelerated-2d-canvas`), 390Ã—844 viewport; baseline and candidate use the same browser/device/workload. Each condition simulates 1,200 updates; the first 180 are warm-up. Six simulated shooters, 48 durable raiders and four bosses, ammo/status effects, winter outfits and 64 active frost fields. The real six-browser transport test is separate.

| Measurement | Baseline | Candidate, same Yard workload | Frostpeak winter workload |
| --- | --- | --- | --- |
| Update median / p90 | 0.3 / 0.5 ms | 0.4 / 0.5 ms | 0.4 / 0.5 ms |
| Render median / p90 | 8.6 / 14.4 ms | 8.5 / 14.4 ms | 10.2 / 18.8 ms |
| Render p99 / maximum | 24.5 / 28.0 ms | 23.9 / 24.5 ms | 25.3 / 28.3 ms |
| Median update + render cost | 8.9 ms | 8.9 ms | 10.6 ms |
| Peak particles / frost fields | 600 / 0 | 600 / 0 | 568 / 64 |
| Snapshot p90 | 3,770 bytes | 3,788 bytes | 4,841 bytes |

The final sample adds **19.1% median combined cost**, within the initial 20% target. Per-target warnings and one shared frost raster are cached; the warning boundaries retain their height-specific geometry. Cache samples: 96 wardrobe frames / 1,932,592 bytes; one background / 1,316,640 bytes; four tracer stamps and one glow. Global bounds remain 24 MiB wardrobe, 48 MiB backgrounds, 64 tracer stamps, 32 glows, 600 general particles, 24 active finish effects and 64 frost fields.

At 15 state snapshots/second to five guests, the winter p90 sample implies **363,075 bytes/second host state payload** (about 355 KiB/s). This excludes reliable effect events, WebRTC overhead and retransmission. This is a payload estimate, not measured internet throughput. Snapshot size includes host state and hazards; caches and artwork are local.

The benchmark runs synchronously and records zero completed worker callbacks; it measures a conservative cache/fallback path rather than steady-state worker throughput. Its rendering samples include raster completion. It does not establish battery use, sustained physical-phone frame rate, Internet latency or cross-network NAT success. Random combat and OS scheduling introduce measurement variance; 19.1% is the recorded sample, not a guaranteed ceiling on every device.

## Build footprint

| Artifact | Prior HEAD v0.9.5.2 | Published release | Change |
| --- | --- | --- | --- |
| Production HTML | 628,790 bytes | 671,620 bytes | +42,830 bytes |
| HTML gzip comparison | 211,532 bytes | 228,787 bytes | +17,255 bytes |
| Service worker | 2,149 bytes | 2,149 bytes | +0 bytes |

These deltas compare committed/deployed artifacts against the starting Git HEAD, excluding preexisting cleanup. Windows local build hashes/sizes and the equivalent LF committed outputs are both recorded in `release-verification.json`. Git line-ending normalization accounts for their byte differences. The original candidate build measurements remain in `verification.json`; its saved pre-expansion assembled page is the performance baseline. No new shipped raster assets, fonts, audio or runtime packages are added; development previews and reports are excluded from Pages and the offline manifest.

## Live publication verification

The fresh Chrome touch session used actual production controls to start a Sniper campaign, verify chapter 1, and start Frostpeak in 5-raid mode. Both Armory tabs fit without scrolling at 320×480, 568×320, 390×844 and 844×390; all visible action buttons meet the 44-pixel minimum. The page exposed no debug hooks and reported no page errors or CSP violations. The active service-worker cache is `palisade-dc87756470`. Account requests were blocked during this smoke test to avoid creating test accounts or sending invitations to real players; account authority, private-room joining and reconnect evidence are recorded separately above.

Captures: [live campaign](live_campaign_mobile.png), [live Frostpeak](live_frostpeak_mobile.png), [320×480 upgrades](live_armUpTab_320x480.png) and [320×480 ammo](live_armAmmoTab_320x480.png).

## Remaining validation and publication

- Conduct sustained human solo/co-op campaign sessions before final difficulty tuning, especially chapter 3â†’4 economy, six-player boss pressure and the lifetime Gold thresholds.
- Measure a physical phone's heat, battery and frame-time behavior, and an actual six-player Internet finale. Desktop phone-sized/touch browser checks are identified above.
- Internet joining still uses the existing PeerJS/WebRTC transport and its connection-help flow; invitations do not remove NAT/relay constraints.
- Backend work is live and compatible with old account flows. This release publishes `index.html` and `sw.js` together; old peers need to reload for protocol 21. Publication and live results are recorded in [release-verification.json](release-verification.json).
- Preexisting repository-cleanup changes remain local and were excluded from the release. They require their own review and verification before publication.
