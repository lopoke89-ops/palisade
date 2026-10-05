# Soundtrack v0.9.6.2

Seven tracks are prepared in AAC 160 kbps (`.m4a`) and Opus 128 kbps (`.ogg`), stereo at 48 kHz. The full source files on H: are read only. [music-manifest.json](music-manifest.json) records their hashes, measured decoded sample counts, release hashes, and cue/loop boundaries.

| Release stem | Track / route | Loop seconds |
| --- | --- | ---: |
| main_menu | Pali Mix (v0.9.7.2, supplied by Big U) / every main-menu page, including Locker | 458.352000 |
| between_raids | Cold / preparation and between raids | 160.084083 |
| raid_attitude | Attitude / raids 1, 4, 7… | 198.765729 |
| raid_cool | Cool / raids 2, 5, 8… | 181.185313 |
| raid_express | Express / raids 3, 6, 9… | 115.513479 |
| final_blitz | Everything She Wants / Blitzkrieg Rush's Final Blitz and evacuation | 389.426667 |
| results | Sacrifices / every actual player results screen | 143.617979 |

| casino_1 … casino_11 | Ambience 1–11 (v0.10.1, Big U's `casino music` folder) / the casino only, as a shuffled playlist | 84–392 each (no loop) |

**The casino playlist (v0.10.1).** Only the casino plays these, and the casino plays nothing else. It is a true shuffle: all 11 tracks once each in a random order, then a fresh shuffle (the first track of a new round is never the one that just ended). The first track fades in as usual; after that, every track comes in over the last 5 seconds of the one before (an equal-power crossfade), and playlist tracks never loop. The next track decodes during the current one's last minute, so at most two are decoded at once (the largest pair is about 290 MiB for those few seconds; one track otherwise). Muting or hiding the tab resumes the same track where it stopped; leaving the casino and coming back moves on to the next track in the shuffle. Each player shuffles on their own device. Test: `dev/test/casino_music.js`. Re-encode just these with `ONLY=casino python dev/audio/prepare_music.py`. The `casino music` folder holds the 320 kbps masters and is not published (`_config.yml`).

`results` begins at exactly **164 seconds in the original 307.617979-second source**. Accurate decoded trimming removes the unused beginning from the release assets, so initial playback and loop start are zero in the trimmed file. Both encoded openings correlate with the original six-second cue segment above 0.996, with zero measured offset. AAC's encoder padding is excluded from the loop boundary.

Set `FFMPEG` to an installed binary, then run `python dev/audio/prepare_music.py`. Verify with `python dev/audio/verify_results_cue.py` using Python with NumPy. Rebuild with `python dev/build.py`. Source filenames are recorded in the importer and manifest; changing machines may require updating those source paths.

Tracks load lazily. The steady decoded cache holds one track, with one outgoing source during the short fade; ended sources are released. The longest decoded track is now the main menu's Pali Mix (v0.9.7.2), approximately **168 MiB** at a 48-kHz browser context (it was Everything She Wants at 142.6 MiB). This retains the existing one-track policy, but physical-phone memory and Safari playback remain release verification items. The media cache advances to `palisade-media-2` to evict the obsolete soundtrack, then continues using content-hashed URLs and lazy offline caching.
