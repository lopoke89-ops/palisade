# Case animation validation — September 29, 2026

This compares the live v0.9.3 source at `b93face` with source at `566e30e`. `git diff b93face..566e30e` changes only `dev/src/js/20-locker-ui.js` and `dev/src/style.css`. Two temporary debug pages were assembled from the same source tree, substituting those two older files for the baseline. The pages ran locally in the same headless Chrome installation at a 390 × 844 viewport, 3× device scale, with GPU and accelerated 2D canvas disabled. These are software-drawing measurements on this PC, not real-phone measurements or the minified production bundle.

## Targeted case measurement

`dev/test/caseperf.js` opened a Supply Case in a local locker, measured Chrome task time during the intro and reel, counted computed-style reads of the reel, and checked that the result matched the selected reel item. Three old/new comparisons were run; the first two used the initial meter and the last used the same meter with the read counter and result check.

| Run | Baseline intro CPU ms/s | Candidate intro CPU ms/s | Baseline reel CPU ms/s | Candidate reel CPU ms/s |
|---|---:|---:|---:|---:|
| 1 | 476 | 508 | 296 | 276 |
| 2 | 525 | 498 | 280 | 230 |
| 3 | 492 | 514 | 288 | 255 |
| Mean | 498 | 507 | 288 | 254 |

In run 3, the baseline read the reel's computed style **203** times and the candidate **0** times. Both opened without JavaScript errors and showed the selected item as the result. The reel CPU mean was about **12% lower** in these runs. Intro CPU overlapped and was slightly higher on average, so these runs do **not** establish an intro improvement.

## Existing phone-sized benchmark

`dev/test/bench.js` was run three times per build with `SCENES=locker,caseintro`. It also measured day, night, and storm raid render time. Its CPU measurements were:

| Run | Baseline Locker ms/s | Candidate Locker ms/s | Baseline intro ms/s | Candidate intro ms/s |
|---|---:|---:|---:|---:|
| 1 | 189 | 210 | 420 | 364 |
| 2 | 207 | 234 | 402 | 443 |
| 3 | 222 | 232 | 421 | 427 |
| Mean | 206 | 225 | 414 | 411 |

The intro readings overlap considerably. Locker readings were consistently higher in these three candidate runs even though the changes are confined to the case animation code and its overlay CSS. That observation needs a longer, device-specific follow-up; it should not be dismissed or attributed to the fixes without profiling. Day/night/storm median frame costs were in the same broad ranges across both builds, with different enemy and wall counts in each run. These runs do not prove the full phone budget is met.

## Decision for the release candidate

The already-committed reel change removes the repeated style read and preserves the winning item. `reel_music.js` and the existing case/cosmetic checks previously passed against current assembled source. Keep the four source commits for the v0.9.3.1 candidate, but **do not mark performance signed off**. Before release, rebuild the actual deployable page, rerun `bench.js` and `caseperf.js` on that page against the v0.9.3 baseline, profile the Locker difference, and test on a real phone. Check the case intro, reel tick timing, reduced-motion path, six-player stage, and raid frame times.

No release files were built or deployed for this comparison. The temporary benchmark pages live under ignored `dev/test/out/` and can be recreated from `dev/test/make_review_pages.py` using the recorded Git commits.

## Corrected mobile rerun for the v0.9.3.1 candidate

The stored review-page generator did not reproduce a valid mobile comparison: it appended `dev/src/js/ORDER.txt` to the JavaScript and omitted the viewport tag. The generator now includes only `.js` files, separates them with newlines, and sets the same mobile viewport as the built page. The earlier figures above remain historical observations; use this corrected rerun for the reproducible mobile comparison.

With the same 390 × 844, 3× software-drawn Chrome setup, `caseperf.js` gave these matched source results (CPU ms/s):

| Run | v0.9.3 intro | Case-fix intro | v0.9.3 reel | Case-fix reel | Reel style reads, old → new |
|---|---:|---:|---:|---:|---:|
| 1 | 196 | 176 | 116 | 100 | 207 → 0 |
| 2 | 179 | 179 | 103 | 98 | 205 → 0 |
| 3 | 181 | 172 | 103 | 100 | 208 → 0 |
| Mean | 185 | 176 | 107 | 99 | — |

The actual built v0.9.3.1 debug page measured 176 intro and 98 reel CPU ms/s in one run, with zero repeated reel style reads, the selected item matching the result, and no page errors. This supports the reel optimization and shows no intro regression in these runs. It is still a PC-based emulation, not a physical phone result.

The phone-sized `bench.js` Locker scene measured 72 CPU ms/s for the corrected v0.9.3 baseline, 81 for the case-fix source page, and 82 for the built v0.9.3.1 candidate in one run each. Raid render medians in the same runs were broadly similar, but enemy and wall counts varied. The Locker increase remains unresolved; investigate it on a real phone before publishing. The candidate's music routing test confirmed that only one track remains decoded at a time.
