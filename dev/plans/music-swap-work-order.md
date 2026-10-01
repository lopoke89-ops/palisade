# PALISADE: music swap and five-case opening work order

**Status:** Implemented locally as v0.9.6.2 / yard-22. Atomic case RPC migration `20261001225643_music_case_batches` is live. See the [completion report](../evidence/2026-10-01-music-case-batches/README.md) for tests, cue verification, performance, and remaining physical-device verification limits. Publishing the new game candidate remains separate.
**Source folders:** `H:\vapeor` and `H:\music\Drake - More Life (2017) [Mp3~320kbps]\Drake – More Life (2017)`

## Goal

Replace PALISADE's current menu, Locker, between-raid, and raid music with the supplied tracks. Use one shared menu track across all main-menu pages, one between-raid track, a repeating three-track raid rotation, a dedicated Blitzkrieg Rush finale song, and one end-of-match song for every outcome. Add an option to open five cases together using vertically stacked carousels while maintaining current case-opening performance.

## Track assignments

The following seven source audio files were verified on October 1, 2026. The first six are in `H:\vapeor`; Sacrifices is in `H:\music\Drake - More Life (2017) [Mp3~320kbps]\Drake – More Life (2017)`. The first five are WAV files; the finale and end-of-match sources are MP3s.

| Game state | Track | Source filename |
| --- | --- | --- |
| All main menus, including the Locker | **01 Heartbeat** | `luxury elite - blind date - 01 heartbeat.wav` |
| Between raids / build phase | **02 Cold** | `luxury elite - blind date - 02 cold.wav` |
| Raid rotation, first track | **04 Attitude** | `Luxury Elite - World Class - 04 Attitude.wav` |
| Raid rotation, second track | **12 Cool** | `Luxury Elite - World Class - 12 Cool.wav` |
| Raid rotation, third track | **09 Express** | `Luxury Elite - World Class - 09 Express.wav` |
| Blitzkrieg Rush finale / Final Blitz | **23 Everything She Wants** | `23 - Everything She Wants - Wham!.mp3` |
| End-of-match results screen, win or loss | **12 Sacrifices — Drake**, starting at **2:44** | `12 Sacrifices (feat. 2 Chainz & Young Thug).mp3` |

## Playback requirements

- **Menus:** Play and loop Heartbeat on every main-menu page. Opening the Locker or moving between menu pages must continue the same playback without restarting the song. Remove the separate Locker music route and its old release assets.
- **Between raids:** Play and loop Cold during the existing between-raid/build phases, including preparation before the first raid.
- **During raids:** Rotate through Attitude, Cool, and Express in that order, then repeat. Replace the old raid track completely.
- **Proposed interpretation of "toggle thru":** Select one track per raid: raid 1 uses Attitude, raid 2 uses Cool, raid 3 uses Express, raid 4 returns to Attitude. Start the selected track at the beginning of the raid and loop it if the raid outlasts the song. Reset the rotation for a new match. Pause, settings, tab visibility, or reconnect within the same raid must not advance the rotation. This is a proposed default; the requested track assignments above are fixed.
- **Blitzkrieg finale:** When Blitzkrieg Rush enters the Final Blitz, fade from the ordinary raid track to Everything She Wants. Give this finale route priority over the normal raid rotation. Start the song at the beginning of the finale, loop it if needed, and keep it playing through the evacuation portion. When the end-of-match results screen appears, transition to Sacrifices; returning directly to a main menu selects Heartbeat. Identify the finale by Blitzkrieg Rush mode and its actual finale state so shared finale code does not select this track in another mode. Solo, host, and guest clients must recognize the same phase; repeated snapshots must not restart the song.
- **End of match:** Play Sacrifices whenever the player's end-of-match results screen appears, regardless of win or loss. Apply this to every mode and result-screen variant, including solo, online co-op, PvP, and evacuation outcomes. Give the visible results screen priority over menu, between-raid, ordinary raid, and finale music. Fade from the prior track and start Sacrifices at **2:44 (164 seconds into the original song)** on each new results-screen entry. Play from that cue to the end, then loop back to 2:44 while the player remains on the screen. Results updates must not restart the song or reset its playback position. Returning to the main menu selects Heartbeat; a rematch selects the appropriate new-match music. Only actual player results screens trigger this route, so a background menu demo ending does not replace Heartbeat.
- Transition between menu, build, and raid music using the existing fades. Prevent unintended overlapping playback or stale tracks after rapid transitions, match exits, or restarts.
- Respect the existing music volume, mute, browser audio unlock, pause, and visibility behavior. Keep combat and UI sound effects intact.
- Apply the assignments to all modes that use these menu, build, and raid states, including solo and online co-op.

## Implementation work

1. Import the seven source audio files using the project's existing audio asset workflow. Keep the originals intact and prepare the existing AAC `.m4a` and Opus `.ogg` release formats, including conversion of both MP3 sources. Measure each source's actual duration and set accurate loop boundaries.
2. Update the music definitions and state routing in `dev/src/js/03-audio.js`. Route every main-menu page to Heartbeat, route build phases to Cold, add the three raid tracks and rotation state, give Everything She Wants priority during the Blitzkrieg Rush finale, and give Sacrifices highest priority while an actual player results screen is visible. Inspect result-screen transitions in `dev/src/js/10-phases-bosses.js`, the finale transition in `dev/src/js/10c-blitz.js`, and guest snapshot state when wiring the routes. The results route must work for PvP as well as raid modes. Ensure repeated routing updates cannot skip tracks or restart the finale/results song.
3. Update `dev/build.py` so the build packages all seven tracks in both release formats. Remove the old Locker entry and obsolete music assets from the release output once references have been replaced. Keep the existing content-hash cache behavior so installed clients receive the new music.
4. Retain lazy loading and the existing decoded-audio memory limit. Adding three raid tracks must not cause the entire soundtrack to remain decoded in memory.
   For Sacrifices, configure both the initial playback offset and loop start at 164 seconds, with loop end at the measured track end. Verify the cue in both release formats. If the release asset is trimmed instead, its first audible sample must correspond to 2:44 in the original source; preserve the full source file.
5. Update the existing music checks, especially `dev/test/music_routing.js`, which currently expects separate Locker music and the old menu/raid loop lengths. Add focused rotation, finale, and results-screen checks if existing coverage cannot verify those routes. Cover both wins and losses, PvP results, evacuation results, return to menu, and rematch. Use the project's targeted music/audio checks and affected transitions.

## Acceptance criteria

- Heartbeat is audible on every main-menu page, including the Locker, and continues when navigating between those pages.
- The old Locker track never plays and is absent from the new release's asset list.
- Cold plays before the first raid and during each between-raid/build phase.
- A new match plays Attitude, Cool, Express, then Attitude across its first four raids under the proposed rotation rule.
- Long raids loop their selected track cleanly. Returning to build or the menu selects the correct music; beginning a new match resets the rotation.
- Everything She Wants starts at the Final Blitz transition in Blitzkrieg Rush, continues through evacuation, and transitions to Sacrifices when the results screen appears. Ordinary raids retain the three-track rotation. Finale entry and same-finale reconnect work for solo, host, and guests without repeated restarts.
- Sacrifices starts at **2:44 / 164 seconds** on every new end-of-match results screen for both wins and losses, including PvP and evacuation outcomes. Playback runs from the cue to the track end and loops back to 2:44 while results remain visible. Verify the audible cue in both AAC and Opus builds. Result updates do not restart the song. Returning to the main menu selects Heartbeat; a rematch selects the appropriate new-match music. Background menu demo outcomes do not select Sacrifices.
- Mute and music volume work during every state. Solo and online co-op transitions, same-raid reconnect, and desktop/phone playback do not produce duplicate playback, skipped rotation entries, or silent stalls under normal loading conditions.
- Release assets load through both supported audio formats, and an existing installed client receives the replacements after an update.

## Open five cases at a time

### Requested behavior

- Add an **OPEN 5** action beside the existing single-case opening action for each supported case type. The batch opens five owned cases of the selected type. Enable it only when the player owns at least five of that type and no opening is already in progress. Show the quantity clearly before activation.
- Use one shared opening intro, then display **five horizontal case carousels stacked vertically**, like five rows of a slot machine. Align the rows to the same width and a common vertical center marker so each winning item lands in the same column.
- Spin all five rows together in one opening session. Each row resolves to its own awarded item. The reels must display the actual committed rewards.
- Use compact rows so all five reels and the primary controls fit on supported phone screens as well as desktop. Keep item art and rarity readable, support touch/mouse/controller input, and honor reduced-motion settings. A longer results summary may scroll.
- Present all five results together, with each item's name, rarity, new/duplicate status, and duplicate shard payout. Offer equip actions for eligible new items and one shared **DONE** action. Opening the batch must not automatically overwrite equipped items.
- Keep the single-case opening option available. Heartbeat continues during both opening flows because the Locker uses the shared menu music.

### Inventory and reward requirements

- Consume exactly five cases and award exactly five independently rolled results using the existing case pools, odds, ownership rules, and duplicate conversion values. Resolve rewards in order so an item first obtained earlier in the same batch counts as a duplicate if rolled again later.
- Handle account-backed and local saves through their existing ownership authority. Treat a five-case opening as one committed operation: insufficient inventory must leave all cases untouched. Lock competing open actions while the batch is pending, and prevent repeated clicks or a retried request from consuming the batch twice.
- Preserve committed rewards when the player skips or closes the animation. On interruption, reload, or an uncertain network response, reconcile the saved batch outcome before allowing a retry; do not reroll completed rewards or grant them twice.
- Refresh case counts, owned items, and shard totals together after the batch. Present any failure clearly and restore usable controls once the outcome is known.

### Implementation and performance requirements

1. Extend the case controls and opening flow in `dev/src/js/20-locker-ui.js`, with the supporting overlay markup and styling in `dev/src/page.html` and `dev/src/style.css`. Share the opening/reveal machinery between one-case and five-case sessions.
2. Use lightweight, cached item art and transform-based reel motion. Keep reel contents bounded to the tiles needed for the animation. Avoid five continuously rendered 3D previews, five copies of the intro effects, or per-frame layout/style reads. Coordinate any JavaScript animation work through a shared scheduler and limit tick/reveal audio so simultaneous rows do not multiply sound-generation load or loudness.
3. Release animation callbacks, timers, temporary reel elements, and graphics resources when the session ends or closes. Repeated batches must not accumulate memory or keep background animations running.
4. Record a baseline of the current single-case opening before implementation. Compare the updated one-case and five-case flows on the same devices and browser settings, including the phone-sized software-rendered scenario in `dev/test/caseperf.js`. Measure intro/reel CPU time, frame-time distribution, layout/style recalculations, input response, and peak/retained memory. Add batch coverage to that test and use `dev/test/cases.js` plus focused inventory/retry checks for correctness.
5. **Performance is a completion requirement:** the five-case animation must preserve the current opening flow's frame-time and responsiveness within measured run-to-run variation. The updated single-case flow must also preserve its baseline performance. Keep setup work bounded and retained memory stable across repeated batches. If five full reels exceed the baseline budget, simplify rendering, reuse art, or reduce offscreen work while retaining five visible stacked rows. Record before/after measurements and phone playback evidence.

### Five-case acceptance criteria

- With five or more cases of a selected type, OPEN 5 consumes exactly five and displays five stacked, aligned carousels in one session. With fewer than five, the action is disabled and consumes nothing.
- Each reel lands on its corresponding awarded result. All five items and any duplicate shards appear correctly in the saved inventory, including duplicates rolled within the same batch.
- Repeated clicks, interrupted animations, retries, and reloads cannot consume or grant the same batch twice. Local and account-backed openings preserve their rewards.
- Desktop and supported phone layouts keep all five reels readable, controls usable, and results accessible. Reduced-motion and single-case opening continue to work.
- The baseline comparison passes for both opening quantities, with no animation stutter, delayed input, multiplied tick-audio load, or increasing retained memory after repeated batches.

## Deliverables

Deliver the seven prepared tracks, updated music routing and build configuration, the five-case opening feature, a rebuilt release candidate, and a brief record of focused checks, playback verification, and case-opening performance measurements. This work order records the requested changes; implementation and publishing are separate tasks.
