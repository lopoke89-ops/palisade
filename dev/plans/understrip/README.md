# THE UNDERSTRIP: M0 pre-production papers

The brief is [`../understrip-work-order.md`](../understrip-work-order.md). M0 is paper only: no game code changes until the director signs off everything below (section 13).

**Decisions:** all eight (D1–D8) answered November 4, 2026, with every recommendation taken. Passive healing is off in this mode (D9). Nine more points found while checking the brief against the code are settled in section 16.1 (D9–D17).

## The papers

| M0 deliverable (section 13) | Where | What it is |
|---|---|---|
| Mood boards (section 3) | [`mood-boards.md`](mood-boards.md) | One written board per skin (10) and region (3): silhouette, palette, parts, motion, headgear, the section 3 check. The other 20 cosmetics in one table |
| Room-kit sketches, region 1 | [`images/room-kit-r1.png`](images/room-kit-r1.png) (the picture), [`../../data/understrip/rooms-r1.json`](../../data/understrip/rooms-r1.json) (the data) | 18 pieces: 6 corridors and junctions, 5 rooms, a cache, the shortcut, breather, merchant, entrance, exit, antechamber and the Pit Boss's arena. Already the format the M1 generator reads |
| Boss move sheets | [`boss-move-sheets.md`](boss-move-sheets.md) | All four bosses, both stages: every move's telegraph shape, warning time, size, damage, cooldown and counter. Elites too |
| The loot table, in a spreadsheet | [`understrip-tables.xlsx`](understrip-tables.xlsx), from [`tables/*.csv`](tables/) | Weapons, tiers, mods, 20 perks, relics, consumables, healing, merchants, loot sources, enemies, bosses, the case and its 30 items, each item's odds, and the game's own numbers for comparison |
| Generator spec (due M1, drafted now) | [`../understrip-generator.md`](../understrip-generator.md) | The exact seeded algorithm both versions follow |

## Tools
- **The tables:**
  - The CSVs in `tables/` are the source; edit them in any spreadsheet.
  - `python3 dev/plans/understrip/build_tables.py` rebuilds the workbook.
  - The build refuses to run if: a weighted case tier is empty; an id or name is already in the cosmetics catalogue; a perk reuses a skill-tree name; gold is sold by anyone but the Collector; or the work order's counts (9 weapons, 20 perks, 30 case items) are off.
  - The DPS columns are calculated, not typed.
- **The room kit:**
  - `node dev/test/understrip_roomkit.js` checks every kit. It's in the suite as `understrip_roomkit` (tags `node understrip`); add `--print` to draw each piece as text.
  - `python3 dev/plans/understrip/draw_room_kit.py 1` redraws the picture.

## Things the director should know
1. **No passive healing (D9).** The other modes heal you 4 HP/s once you've been out of a fight for 4 s. That's off here, so the healing charges carry the mode, as the brief intends. The SECOND WIND skill does nothing in this mode, and the PLAY card will say so (M1).
2. **The case needs common items (D13).** When a case rolls a tier it has nothing in, the server gives a random item of any tier. So with no commons, the 40% common weight would have handed out legendaries and golds at random. Five of the non-skin items are common now. The odds with D7's weights:

   | Tier | Items | Each item | Winter, each item |
   |---|---|---|---|
   | Common | 5 | 8% | 9% |
   | Rare | 9 | 3.6% | 3.6% |
   | Epic | 9 | 2% | 1.8% |
   | Legendary | 5 | 1.6% | 0.9% |
   | Gold | 2 | 1% | 0.14% |

   A given legendary is about twice as likely as in the Winter Case, and a given gold about seven times. That's what D7's weights give 30 items. Lower `l` and `g` in `tables/case.csv` if that's more generous than wanted.
3. **Five items were renamed** because their ids or names were taken (D14): Dealer's Eyeshade, Neon Halo, Neon Tube, Saucer Bolt and Showgirl Plumes.
4. **The class gun stays.** It keeps its infinite ammo, as now. The second weapon has a reserve, refilled at shrines and by AMMO BOX. That's what "ammo" means at merchants and shrines in this mode.
5. **One M1 rendering risk (D17).** In 1–2 tile tunnels, walls nearer the camera would hide the player, because the iso view draws them on top. M1 draws near-side walls low. This is in the generator spec.
6. **Still blocking M3:** the `import_local_save` hole (work order 9.4) is still open in `dev/supabase/schema.sql`. It's a server change that needs your go-ahead to deploy.

## Sign-off
- [ ] Mood boards: the 10 skins (King of the Strip signed off on its own), the 3 regions, the other 20 items.
- [ ] Region 1 room kit.
- [ ] Boss move sheets.
- [ ] The tables (numbers are M4's starting point, not final).
- [ ] D9–D17 as settled in section 16.1.

When these are signed off, M1 (the region 1 vertical slice) starts.
