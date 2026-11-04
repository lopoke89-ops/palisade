# THE UNDERSTRIP · M0 (pre-production) report, November 4, 2026

**Scope:** paper only, as section 13 sets M0. No game source, server or build output changed. The papers are indexed in [`dev/plans/understrip/README.md`](../../plans/understrip/README.md).

## What changed
- **The work order** (`dev/plans/understrip-work-order.md`, brought over from `bench/blackout-flow-speed`):
  - D1–D8 answered, with every recommendation taken.
  - Section 16.1 records D9–D17, found by checking the brief against the code.
  - The text corrected where they apply (6.3, 7.4, 9.3, 10.1).
- **New papers:** mood boards, boss move sheets, the tables (13 CSVs and the workbook built from them), and the generator spec draft.
- **Region 1 room kit:** `dev/data/understrip/rooms-r1.json` (18 pieces) and its picture.
- **New test:** `dev/test/understrip_roomkit.js`, listed in `suite.txt` as `understrip_roomkit` (`node understrip`).

## What was checked against the code
| Claim in the brief | Found | Result |
|---|---|---|
| Roll: 2 tiles, 0.55 s, 3 s cooldown, safe 0.1–0.4 s | `ROLL` in `09-actions.js:75` | ✔ |
| `canShop` allows buying away from the stake | `04-state-armory.js:89` (Black Out's `boNearHeld`) | ✔ |
| Evac pieces to reuse | `openEvac` / `evacTick` (`10c`), `startMapEvac` / `finishMapEvac` (`10d`) | ✔ |
| `UPG`, `RAR`, `CASES`, `CASINO` playlist, `SKILLS` `modes:[...]` | all present as described | ✔ |
| Stormcaller's half-health switch | `e.hp<e.max*.5` in `10-phases-bosses.js` | ✔ |
| `PROTO` `yard-30` | `21-online.js:7` | ✔ |
| "Heal pickups are off in this mode" | there are none; players regenerate out of a fight | ✖ → D9 |
| "Second Wind" perk | a skill-tree node already | ✖ → D10 |
| "The Medic class" | no such class; the Quartermaster has `medic:true` | ✖ → D11 |
| New files `18e-`, `18f-`, `20c-` | taken by Hybrid Theory | ✖ → D12 |
| A case with no common skins | an empty tier makes the server hand out any tier at random (`private.open_case_catalog`) | ✖ → D13 |
| 9.3's item names | five ids or names already in the catalogue | ✖ → D14 |
| Boss states for the new framework | 40–47 (Destroyer) and 101–103 (winter) taken | → D16 (60–89) |
| `import_local_save` hole (blocks M3) | still open in `dev/supabase/schema.sql:319` | open |

## Test results
- `node dev/test/understrip_roomkit.js`: **PASS** (1 kit, 18 pieces). The text drawing of every piece is in [`roomkit-r1-sketches.txt`](roomkit-r1-sketches.txt).
- **Negative checks.** The room checker caught every deliberately broken kit, run against copies:
  - a three-wide corridor;
  - floor on an edge;
  - half a doorway;
  - an unreachable island;
  - a shortcut that leaks with the door shut;
  - a breather with no shrine;
  - an unknown tile;
  - a kit missing its merchant.

  The table build refused a case with an empty common tier and an item reusing `trail:plasma` / "Neon".
- `node run_suite.js @understrip`: 1/1 passed.
- `python3 dev/plans/understrip/build_tables.py`: **OK**, 126 rows in 13 tables ([`build_tables.log`](build_tables.log)).
- **The generator spec's PRNG** matches the standard mulberry32 for 60,000 draws over six seeds.

## The numbers that matter for sign-off
- **Boss health** (one player, Normal, both stages): Pit Boss 1,200, Custodian 1,800, Gatekeeper 2,400, Visitor 3,500. Today's bosses are 675–950.
- **Second weapons** (burst DPS, every shot landing): 11–409, against the class guns' 67–168. The sawn-off's 409 is point-blank only and drops to 93 sustained.
- **The case:**
  - Per item: 8% common, 3.6% rare, 2% epic, 1.6% legendary, 1% gold.
  - A given legendary is about twice the Winter Case's odds, and a given gold about seven times.

## Next
The director's sign-off (the checklist in the papers' README), then M1: the region 1 vertical slice.
