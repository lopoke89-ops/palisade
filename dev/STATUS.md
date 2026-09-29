# PALISADE project status

Updated September 29, 2026. This is the current status record for the clone. The older project handoff and v0.9.3 hardening prompt describe a superseded release order.

The Claude audit artifact linked in the handoff requires a Claude sign-in in the available browser session, so its Progress section could not be edited here. This local record holds the verified update until that artifact is accessible.

## Live and local

| Item | Current state |
|---|---|
| Live release | v0.9.3: milestone cosmetics, class rewards, more Halloween items, and the Flag Case |
| Live protocol | `yard-16` / `palisade-yard-16-` |
| Applied server migration | `palisade_v093_milestones_flags_halloween` (`20260928224258`) |
| Local/GitHub branch | `main`; reviewed at `566e30e` |
| Next planned subversion | **v0.9.3.1**, security and reliability hardening |

Controller support shipped in v0.9.2.1. The v0.9.3 cosmetics migration is applied and the live case catalog includes Flags. The two proposed new game modes have not shipped; the Nightmare modifier and a future preset definition do not constitute a separate game mode.

Four commits after the v0.9.3 release changed the case intro and reel source (`98bb522`, `4c8dd3d`, `a49df08`, `566e30e`). The committed and live `index.html` still contains the earlier v0.9.3 build. Their source was compared with the release source on September 29; see [case animation validation](CASE_PERFORMANCE_2026-09-29.md). The reel avoids repeated style reads and its measured CPU use was lower, but intro readings overlapped and Locker readings were higher in the candidate runs. A production rebuild, further profiling, and a real-phone comparison are still required before performance sign-off.

## Next release scope

The [v0.9.3.1 hardening plan](plans/v0.9.3.1-hardening.md) supersedes the old v0.9.3 hardening prompt. It keeps the existing PeerJS/WebRTC host architecture, Supabase rewards, and renderer. It adds the findings from the September 29 review: local-save import trust, guest/account skill identity, complete claim replay handling, and rejoin boss accounting. Room kick and lock will require a coordinated protocol change; the version and room prefix must move together.

No v0.9.3.1 game or server hardening is marked implemented here. Publishing and database changes remain subject to the project's release rules. Do not backfill milestone counters or alter existing live player data without Big U's approval.

## Verification

The current source passed eight focused browser checks on September 29: milestones, Flag Case, cosmetics, cases, accounts, reward screen, reel/music, and keyboard focus. This was not the full 26-test suite. The live page was checked against committed `index.html`; it matches after CRLF normalization. [Case animation measurements](CASE_PERFORMANCE_2026-09-29.md) are complete for the source comparison; the full release build and device validation remain open.

See the broader [September 29 project review](../../PALISADE_project_review_2026-09-29.md) for evidence, risks, and limitations.
