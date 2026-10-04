# v0.9.7.3 City Black Out polish: evidence

Branch `claude/lucid-curie-491na1`, protocol `yard-27` (client only). Work order: [blackout-polish-work-order.md](../../plans/blackout-polish-work-order.md).

## Screenshots (desktop 1366×820, phone portrait 390×844, phone landscape 844×390)

| Shot | Files |
|---|---|
| First attack, banner up (portrait: the mini-map fades under it) | `*-attack-banner.png` |
| Same moment, banner gone (mini-map top right) | `*-minimap.png` |
| Night roads, Power Station held / lost | `*-night-power-held.png`, `*-night-power-lost.png` |
| Ready stage before the final push | `*-ready.png` |
| A normal raid's banner (every mode) | `*-raid-banner.png` |

## Banners (`toast_queue.json`)

- Desktop banner: 640 px wide in the gap between the vitals and the phase box, at most 86 px tall with a two-line detail (was 672×139 in the middle of the screen).
- Title and detail centred on the panel within 2 px at every size, with 0, 1, 2 and 4 bosses up, in a normal raid and in Black Out. The off-centre text came from the banner's `phase` class also matching the HUD phase box's right-aligned grid rule.
- No overlap with the vitals, phase box, phase note, build kit or boss bars in any of the 24 cases. On portrait phones it overlaps the mini-map only while the map has faded out.
- Times: phase messages 4.5 s, minor 3 s; ×2 gives 9 s.

## Streetlamps (`blackout_map.json`)

| | v0.9.7.2 | v0.9.7.3 |
|---|---|---|
| Spacing | every 6 tiles | every 4 tiles |
| Lamps on the 64×64 city | 50 | 60 |
| Pool | 1.9 tiles at 60% | 3.5 tiles at 85%, plus an 18% warm glow and a bulb halo |
| Darkness left halfway between two lamps (share of the unlit night) | lamps never met | median 29%, worst 48% |

The work order said 3.2 tiles; at that size two lamps 4 tiles apart leave 55% at the midpoint, over the order's 50% bar, so the radius is 3.5.

## Performance (`blackout_perf.json`, headless, 60 raiders)

| | Quarry XL | City 64×64 | Ratio (gate 1.6×) |
|---|---|---|---|
| Desktop | 19.2 ms | 28.7 ms | 1.50× |
| Phone | 23.3 ms | 34.9 ms | 1.50× |

## Mini-map (`blackout_hud.json`)

| Size | Position (no bosses) | With bosses up |
|---|---|---|
| Desktop | x 1172–1342, y 213–298 (under the phase box, room kept for the phase note) | unchanged, the bars are elsewhere |
| Portrait | x 257–374, y 185–244 | below the bars, or at the left edge if the build kit is in the way |
| Landscape | x 542–670, y 12–76 (left of the phase box) | below the boss strip |

It stays put when the tip hides and when the first phase note appears. The kill feed sits beside it on its left.
