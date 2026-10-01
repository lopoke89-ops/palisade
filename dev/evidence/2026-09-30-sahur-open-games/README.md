# v0.9.5.1 — Sahur headgear and Open Games visibility

Source base: GitHub `main` at `a325765` (work order), September 30, 2026. The live footer returned `v0.9.5.0` before this release; the protocol remains `yard-19`. This release changes no packet fields or server code.

## Diagnosis and changes

The work order assumed Sahur's headwear compatibility was the main obstacle. Inspection showed a second obstacle: `paintWardrobeCharacter` put Sahur's painted face in an exclusive `if/else if` chain with all hats. The compatibility list now allows only the specified eight non-class hats, and the face draws before the normal headwear branch. Headwear geometry is lifted to the log crown only for Sahur. The visor and headband use smaller brow offsets; Sahur's visor uses a narrow backing so the eyes remain readable. The normal `o.horns` path draws Devil Horns, without Demon body features. The existing brim slice renderer handles Witch Hat. Sahur headwear thumbnails have extra margin.

The Open Games list was not missing from the DOM, and entering MULTIPLAYER still called `lobbyBrowse`/`refreshLobbies`. A mocked current-protocol room rendered, but its row started below the visible region at every requested viewport. Before the change, its initially visible height was **0 px** at 1440×900, 1280×720, 390×844 and 844×390. The existing `.partyControls` was scrollable, so the row appeared only after scrolling. The list now sits above the host form and the portrait phone puts controls before the stage. After the change the initial visible row heights were **55, 55, 55 and 69 px** respectively. The phone tab bar does not cover it. The cloud-down wording no longer claims there are zero rooms.

The browser test also verified the existing listing path with a mocked signed-in host: a public row was posted for a one-player room with `proto: yard-19`, and an active room redirects MULTIPLAYER to the room. The server schema describes a 45-second visible freshness window and hosts refresh every 15 seconds. This work did not change either behavior or query real player/account data.

## Verification

- `sahur_hats`: 8 aim angles × 3 walk phases × 8 hats (192 combinations), downed visibility checks, exact compatibility set, actual Locker equip/save for each hat, and thumbnail edge checks. `sahur_hats.png` shows game and Locker sizes; `sahur_hats_angles.png` shows all aim angles; `sahur_hats_downed.png` shows each hat on the downed log.
- `sahur_network` and `tracer_network`: remote party stage, guest gameplay, and a mid-match join see Sahur with normal Devil Horns.
- `open_games_visibility`: all four viewports, room and empty states, connecting, cloud unavailable, offline preview, guest browsing, full-room and already-hosting disabled joins, host publish and room redirect. Measurements are in `open_games_visibility.json`; screenshots are named by viewport.
- Existing regressions: `cosmetics_expansion`, `headgear_fit`, `cosmetics`, `wardrobe3d`, `locker_fit`, `presentation_posefit`, `lobby`.

Visual review of the contact sheets found the hats seated on the log at front, side and rear angles. The painted face remains readable; Halo clears the crown; Witch brim renders across the front. The remote lobby capture shows the guest's stage presentation. Physical phone review remains useful before publishing.
