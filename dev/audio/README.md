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

`results` begins at exactly **164 seconds in the original 307.617979-second source**. Accurate decoded trimming removes the unused beginning from the release assets, so initial playback and loop start are zero in the trimmed file. Both encoded openings correlate with the original six-second cue segment above 0.996, with zero measured offset. AAC's encoder padding is excluded from the loop boundary.

Set `FFMPEG` to an installed binary, then run `python dev/audio/prepare_music.py`. Verify with `python dev/audio/verify_results_cue.py` using Python with NumPy. Rebuild with `python dev/build.py`. Source filenames are recorded in the importer and manifest; changing machines may require updating those source paths.

Tracks load lazily. The steady decoded cache holds one track, with one outgoing source during the short fade; ended sources are released. The longest decoded track is now the main menu's Pali Mix (v0.9.7.2), approximately **168 MiB** at a 48-kHz browser context (it was Everything She Wants at 142.6 MiB). This retains the existing one-track policy, but physical-phone memory and Safari playback remain release verification items. The media cache advances to `palisade-media-2` to evict the obsolete soundtrack, then continues using content-hashed URLs and lazy offline caching.
