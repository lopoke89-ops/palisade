# PALISADE project status

Updated September 29, 2026. This is the current status record for the clone. The older project handoff and v0.9.3 hardening prompt describe a superseded release order.

For a consolidated list of what remains from those documents, see the [current project blueprint](PROJECT_BLUEPRINT_2026-09-29.md).
Big U's latest completed local scope is recorded in the [presentation prompt](plans/backgrounds-and-character-animation-prompt.md). The earlier [cosmetic and hardening prompt](plans/next-cosmetics-and-hardening-prompt.md) remains the record of v0.9.3.2 and its deferred work.

The Claude audit URL still requires sign-in in the available browser session. Big U supplied an exported copy at `D:\downloads\Untitled.md`, which was read on September 29. Its newest Progress entry is v0.9.3, so its release claims are superseded by the verified v0.9.3.3 release below. The external artifact itself was not edited here.

## Live and local

| Item | Current state |
|---|---|
| Live release | **v0.9.3.3**: Milestones-only cosmetics and collapsible Locker case collections |
| Live protocol | `yard-17` / `palisade-yard-17-` |
| Applied server migration | `palisade_v093_milestones_flags_halloween` (`20260928224258`) |
| GitHub branch | `main` at `2268c35` (`v0.9.3.3 Milestone cosmetics`), pushed by Big U September 29 |
| Local checkout | `2268c35` plus the uncommitted v0.9.3.4 presentation candidate |
| Published build | GitHub Pages displays **v0.9.3.3**; rechecked September 29 during this implementation |

Controller support shipped in v0.9.2.1. The v0.9.3 cosmetics migration is applied and the live case catalog includes Flags. The two proposed new game modes have not shipped; the Nightmare modifier and a future preset definition do not constitute a separate game mode.

Four commits after the v0.9.3 release changed the case intro and reel source (`98bb522`, `4c8dd3d`, `a49df08`, `566e30e`). The v0.9.3.1 release includes those fixes. Their source was compared with the v0.9.3 release on September 29; see [case animation validation](CASE_PERFORMANCE_2026-09-29.md). The reel avoids repeated style reads and its measured CPU use was lower, but intro readings overlapped and Locker readings were higher in the comparison runs. Further profiling and a real-phone comparison are still required before performance sign-off.

## Local v0.9.3.4 presentation candidate (unpublished)

All 32 Flag Case backgrounds now fill their canvases with responsive fields and proportional emblems. 24 scenic backgrounds receive cached, theme-specific finishing layers; Arcade retains its original pixel-art composition. The old sources and matched before captures are preserved in the [backup manifest](backups/2026-09-29-v0.9.3.3-presentation/MANIFEST.md), with a per-background restore path. No image downloads were introduced.

Character rendering now uses displacement-driven presentation gait, planted/lifted steps, bent knees, directional strafing/backpedalling and a settling transition. Tiny residual remote interpolation does not keep a walking pose alive. Lower-leg cosmetic details follow the articulated legs. Lobby/Locker idle breathing is subtle and disabled with reduced motion. Weapon and muzzle measurements share the same pose; gameplay values and the network protocol are unchanged. A self-contained renderer factory fixes worker serialization under minification, which previously fell back to synchronous painting.

Build and nine focused checks passed: `presentation`, `presentation_posefit`, `flagcase`, `wardrobe3d`, `locker_fit`, `muzzle`, `presentation_network`, `cosmetic_network`, and `csp`. The capture and A/B performance utilities also completed. This is not a full-suite run. See [the presentation report](PRESENTATION_2026-09-29.md) for saved images/clips, measurements, worker verification and physical-phone limits. No Supabase change is required. Big U still handles publication.

## v0.9.3.3 Locker release

Milestone cosmetics now appear only in MILESTONES. Ordinary categories show STANDARD & UNLOCKS followed by independent case-collection disclosures with owned/total counts. Collections begin collapsed, remember their state for the page session, and allocate tiles only when opened. Equip/cloud refresh updates mounted tiles in place, preserving focus and scroll. A case result's EQUIP action opens the relevant collection and focuses the item. Case OPEN/BUY controls remain in their separate panel. No protocol, server, or save-format change is included.

Build and eight focused checks passed: `locker_collections`, `milestones`, `flagcase`, `accounts`, `locker_fit`, `cosmetics`, `csp`, and `taborder`. Screenshots were inspected at 390×844, 844×390, and 1280×900. On the phone-sized PC benchmark, initial Skins canvases dropped from 72 to 4 and grid height from 7,827 to 660 CSS pixels; measured CPU work was lower in this small PC sample. See [Locker validation](LOCKER_UI_2026-09-29.md). Big U committed and pushed this release; GitHub `main` and the live v0.9.3.3 footer were verified. Physical-device testing and the older movement/account/PWA verification limits remain open.

## v0.9.3.2 release and remaining verification

The next-work prompt was implemented in v0.9.3.2 where it is independent of reward and identity changes. Opaque masks and headpieces now hide the base facial features in both character painters, and Clown Hair is one rounded afro shape. The Locker captures include Galaxy, Clown Hair, and covered faces. Matching v0.9.3.1 before and v0.9.3.2 after images for Clown Hair and the Scary Clown skin are in `dev/test/out/`. Case-opening performance was left alone because Big U reports the lag fixed on desktop and mobile.

The host now validates the accepted guest message fields and meters movement by elapsed time, with a burst cap, class/perk/modifier/terrain speed allowance, and debug rejection counts. Host kick and room lock work for lobby and direct joins, with a single coordinated bump to `yard-17`. A kicked browser session is refused on rejoin to the same room. These are host controls, not a server-enforced ban against a modified client or fresh browser session.

The build emits a script-hash CSP as a page meta policy for normal and debug pages. Vendored PeerJS remains at 1.5.5 after upstream review; the test dependencies have no npm audit findings, and their package lock is included for reproducible installs. No package upgrade was justified. No server migration or live Supabase change was part of this release. Suspicious-operation logging was not added: the useful refusal events arise inside reward/import/skill RPC transactions, where an exception rolls back any event insert. Persisting those events would require changing those deferred RPC response contracts, so the log remains coupled to the later server-design work.

Focused cosmetic, Locker, host, multiplayer, CSP, account, music, solo, and lobby checks passed locally. A physical-phone check is still needed for cosmetic fit and movement tolerance under Wi-Fi/cellular lag, sprint, water, and storms. The published site displays v0.9.3.2. A fresh Chrome live smoke passed host/guest room join, menu and raid audio asset fetches, manifest fetch, and an offline reload under the service worker. Account sign-in with a test account, installed-PWA behavior, PvP, and longer live play remain unchecked. No full-suite run was needed for this scoped change. Do not call the phone movement cap fully calibrated until physical-phone checks pass.

## v0.9.3.1 release scope

The [v0.9.3.1 implementation prompt](plans/v0.9.3.1-polish-music-safe-hardening.md) scoped this patch to targeted test selection, cosmetic fit and Locker framing, new menu and co-op raid music, and safe host-side guest input validation. The [broader hardening plan](plans/v0.9.3.1-hardening.md) remains a backlog reference. Account identity, import trust, reward-claim retry/rejoin behavior, room kick/lock, and any Supabase migration are **not** fixed by this release.

The release rejects malformed/non-finite guest movement, aim, build, grenade, and ability values at the host boundary. It leaves the `yard-16` protocol, valid guest messages, rewards, accounts, and live server unchanged. Database changes remain subject to the project's release rules. Do not backfill milestone counters or alter existing live player data without Big U's approval.

## Verification

The v0.9.3.1 build passed with the bundled Python/Pillow runtime and local Terser. Focused Chrome checks passed for cosmetic art, wardrobe variants, cosmetic network replay, Locker fit at phone and desktop viewport sizes, music routing/decoding, malformed host input, and an honest host/guest multiplayer run. The prior reel/music check also passed. These are selected checks, not the full 29-test suite. Screenshots in `dev/test/out/` show Galaxy, Pumpkin, Top Hat, and other brimmed hats in the Locker. The [corrected mobile performance rerun](CASE_PERFORMANCE_2026-09-29.md#corrected-mobile-rerun-for-the-v0931-candidate) supports the reel optimization but still shows higher Locker CPU; a physical-phone check remains open. GitHub Pages serves the v0.9.3.1 page; post-release multiplayer, audio, and account behavior have not been validated against live services.

See the broader [September 29 project review](../../PALISADE_project_review_2026-09-29.md) for evidence, risks, and limitations.
