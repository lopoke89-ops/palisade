# PALISADE project status

Updated September 29, 2026. This is the current status record for the clone. The older project handoff and v0.9.3 hardening prompt describe a superseded release order.

For a consolidated list of what remains from those documents, see the [current project blueprint](PROJECT_BLUEPRINT_2026-09-29.md).
Big U's latest cosmetic and hardening scope is recorded in the [next-work prompt](plans/next-cosmetics-and-hardening-prompt.md).

The Claude audit URL still requires sign-in in the available browser session. Big U supplied an exported copy at `D:\downloads\Untitled.md`, which was read on September 29. Its newest Progress entry is v0.9.3, so the published baseline remains v0.9.3.1; the local v0.9.3.2 candidate is recorded below. The external artifact itself was not edited here.

## Live and local

| Item | Current state |
|---|---|
| Live release | **v0.9.3.1**: targeted tests, cosmetic and Locker fit, menu/raid music, and host input checks |
| Live protocol | `yard-16` / `palisade-yard-16-` |
| Applied server migration | `palisade_v093_milestones_flags_halloween` (`20260928224258`) |
| GitHub branch | `main` at `cea4636` (`v0.9.3.1`), pushed September 29 |
| Local candidate | Uncommitted **v0.9.3.2** build with `yard-17` / `palisade-yard-17-`; not published |
| Published build | GitHub Pages displays **v0.9.3.1** in the game footer |

Controller support shipped in v0.9.2.1. The v0.9.3 cosmetics migration is applied and the live case catalog includes Flags. The two proposed new game modes have not shipped; the Nightmare modifier and a future preset definition do not constitute a separate game mode.

Four commits after the v0.9.3 release changed the case intro and reel source (`98bb522`, `4c8dd3d`, `a49df08`, `566e30e`). The v0.9.3.1 release includes those fixes. Their source was compared with the v0.9.3 release on September 29; see [case animation validation](CASE_PERFORMANCE_2026-09-29.md). The reel avoids repeated style reads and its measured CPU use was lower, but intro readings overlapped and Locker readings were higher in the comparison runs. Further profiling and a real-phone comparison are still required before performance sign-off.

## Local v0.9.3.2 candidate (unpublished)

The next-work prompt has been implemented locally where it is independent of reward and identity changes. Opaque masks and headpieces now hide the base facial features in both character painters, and Clown Hair is one rounded afro shape. The Locker captures include Galaxy, Clown Hair, and covered faces. Matching v0.9.3.1 before and v0.9.3.2 after images for Clown Hair and the Scary Clown skin are in `dev/test/out/`. Case-opening performance was left alone because Big U reports the lag fixed on desktop and mobile.

The host now validates the accepted guest message fields and meters movement by elapsed time, with a burst cap, class/perk/modifier/terrain speed allowance, and debug rejection counts. Host kick and room lock work for lobby and direct joins, with a single coordinated bump to `yard-17`. A kicked browser session is refused on rejoin to the same room. These are host controls, not a server-enforced ban against a modified client or fresh browser session.

The build emits a script-hash CSP as a page meta policy for normal and debug pages. Vendored PeerJS remains at 1.5.5 after upstream review; the test dependencies have no npm audit findings, and their package lock is included for reproducible installs. No package upgrade was justified. No server migration or live Supabase change is part of this candidate. Suspicious-operation logging was not added: the useful refusal events arise inside reward/import/skill RPC transactions, where an exception rolls back any event insert. Persisting those events would require changing those deferred RPC response contracts, so the log remains coupled to the later server-design work.

Focused cosmetic, Locker, host, multiplayer, CSP, account, music, solo, and lobby checks passed locally. A physical-phone check is still needed for cosmetic fit and movement tolerance under Wi-Fi/cellular lag, sprint, water, and storms. The published site still needs online, offline/PWA, and account smoke checks after release. No full-suite run was needed for this scoped change. Do not call this candidate released or the phone movement cap fully calibrated until those checks pass.

## v0.9.3.1 release scope

The [v0.9.3.1 implementation prompt](plans/v0.9.3.1-polish-music-safe-hardening.md) scoped this patch to targeted test selection, cosmetic fit and Locker framing, new menu and co-op raid music, and safe host-side guest input validation. The [broader hardening plan](plans/v0.9.3.1-hardening.md) remains a backlog reference. Account identity, import trust, reward-claim retry/rejoin behavior, room kick/lock, and any Supabase migration are **not** fixed by this release.

The release rejects malformed/non-finite guest movement, aim, build, grenade, and ability values at the host boundary. It leaves the `yard-16` protocol, valid guest messages, rewards, accounts, and live server unchanged. Database changes remain subject to the project's release rules. Do not backfill milestone counters or alter existing live player data without Big U's approval.

## Verification

The v0.9.3.1 build passed with the bundled Python/Pillow runtime and local Terser. Focused Chrome checks passed for cosmetic art, wardrobe variants, cosmetic network replay, Locker fit at phone and desktop viewport sizes, music routing/decoding, malformed host input, and an honest host/guest multiplayer run. The prior reel/music check also passed. These are selected checks, not the full 29-test suite. Screenshots in `dev/test/out/` show Galaxy, Pumpkin, Top Hat, and other brimmed hats in the Locker. The [corrected mobile performance rerun](CASE_PERFORMANCE_2026-09-29.md#corrected-mobile-rerun-for-the-v0931-candidate) supports the reel optimization but still shows higher Locker CPU; a physical-phone check remains open. GitHub Pages serves the v0.9.3.1 page; post-release multiplayer, audio, and account behavior have not been validated against live services.

See the broader [September 29 project review](../../PALISADE_project_review_2026-09-29.md) for evidence, risks, and limitations.
