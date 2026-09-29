# PALISADE project status

Updated September 29, 2026. This is the current status record for the clone. The older project handoff and v0.9.3 hardening prompt describe a superseded release order.

The Claude audit artifact linked in the handoff requires a Claude sign-in in the available browser session, so its Progress section could not be edited here. This local record holds the verified update until that artifact is accessible.

## Live and local

| Item | Current state |
|---|---|
| Live release | v0.9.3: milestone cosmetics, class rewards, more Halloween items, and the Flag Case |
| Live protocol | `yard-16` / `palisade-yard-16-` |
| Applied server migration | `palisade_v093_milestones_flags_halloween` (`20260928224258`) |
| Local/GitHub branch | `main`; last committed at `54282bb` |
| Local candidate | **v0.9.3.1**, built but uncommitted and unpublished |

Controller support shipped in v0.9.2.1. The v0.9.3 cosmetics migration is applied and the live case catalog includes Flags. The two proposed new game modes have not shipped; the Nightmare modifier and a future preset definition do not constitute a separate game mode.

Four commits after the v0.9.3 release changed the case intro and reel source (`98bb522`, `4c8dd3d`, `a49df08`, `566e30e`). The live page still contains the earlier v0.9.3 build; the local v0.9.3.1 candidate now includes those source fixes. Their source was compared with the release source on September 29; see [case animation validation](CASE_PERFORMANCE_2026-09-29.md). The reel avoids repeated style reads and its measured CPU use was lower, but intro readings overlapped and Locker readings were higher in the candidate runs. Further profiling and a real-phone comparison are still required before performance sign-off.

## Next release scope

The [current v0.9.3.1 implementation prompt](plans/v0.9.3.1-polish-music-safe-hardening.md) narrows this patch to targeted test selection, cosmetic fit and Locker framing, new menu and co-op raid music, and safe host-side guest input validation. The [broader hardening plan](plans/v0.9.3.1-hardening.md) remains a backlog reference. Account identity, import trust, reward-claim retry/rejoin behavior, room kick/lock, and any Supabase migration are **not** fixed by this candidate.

The local candidate rejects malformed/non-finite guest movement, aim, build, grenade, and ability values at the host boundary. It leaves the `yard-16` protocol, valid guest messages, rewards, accounts, and live server unchanged. Publishing and database changes remain subject to the project's release rules. Do not backfill milestone counters or alter existing live player data without Big U's approval.

## Verification

The v0.9.3.1 candidate builds successfully with the bundled Python/Pillow runtime and local Terser. Focused Chrome checks passed for cosmetic art, wardrobe variants, cosmetic network replay, Locker fit at phone and desktop viewport sizes, music routing/decoding, malformed host input, and an honest host/guest multiplayer run. The prior reel/music check also passed. These are selected checks, not the full 29-test suite. Screenshots in `dev/test/out/` show Galaxy, Pumpkin, Top Hat, and other brimmed hats in the Locker. The [corrected mobile performance rerun](CASE_PERFORMANCE_2026-09-29.md#corrected-mobile-rerun-for-the-v0931-candidate) supports the reel optimization but still shows higher Locker CPU; a physical-phone check remains open. Live-service validation is also open. The built files and new audio are local only.

See the broader [September 29 project review](../../PALISADE_project_review_2026-09-29.md) for evidence, risks, and limitations.
