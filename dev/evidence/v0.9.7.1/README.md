# v0.9.7.1 beta feedback pass: evidence

Branch `claude/lucid-curie-491na1`, protocol `yard-27`. Work order: [beta-feedback-work-order.md](../../plans/beta-feedback-work-order.md).

## City Black Out salvage, before and after (one player, every point held, no kills counted)

| Source | v0.9.7 | v0.9.7.1 |
|---|---|---|
| Starting purse | 0 | 40 |
| Round pay (attacks 1-8: 25, 30 … 60) | 0 | 340 |
| Final-push bonus | 0 | 60 |
| **Total before kills** | **0** | **440** |
| Kill bounties | ×1 (×1.25 by the Gas Station) | ×1.25 (×1.5625 by the Gas Station) |

Over the last 7 days, Black Out runs averaged 86 kills. That's about 390 salvage from kills at v0.9.7 and about 490 now. A typical run goes from roughly 390 to roughly 930 salvage, with more chances to spend it: any held point opens the armory during gaps and the ready stage.

`blackout_run` checks the exact amounts:
- the purse of 40;
- attack 2 pulled back pays 30;
- attack 3 lost pays 18 (half of 35, rounded up);
- the armory at a held point in a gap, but not during an attack;
- core repair only at Main Command.

## Zoom cost (desktop, headless, 60 raiders on the 64×64 city)

| | Average frame | Chunk memory |
|---|---|---|
| Quarry XL (reference) | 15.7 ms | 74 MB |
| City at 100% | 22.2 ms | 49 MB |
| City at 70% (widest) | 18.7 ms | 40 MB |

Zooming out draws more tiles, but each tile and figure is smaller, so the widest setting is cheaper here. Phones don't get zoom (Big U, F9).

## Screenshots

Desktop, phone portrait and phone landscape:
- `*-ready.png`: the READY UP stage;
- `*-message.png`: a phase message;
- `*-lobby.png`: the lobby with a guest ready;
- `desktop-zoom-70.png` and `desktop-zoom-140.png`: the zoom range;
- `phantom-hats.png`: the Phantom with several hats.
