# v0.9.8.2 work order: ANIMATED MENU BACKGROUNDS ON EVERY PAGE

| | |
|---|---|
| **Status** | Plan. Written October 4 from Big U's bug report. Decisions D1–D3 open at the bottom; nothing is built yet |
| **Build** | v0.9.8.2, client only. No server change, no protocol change |
| **Scope** | The main menu's background canvas (`#lobbyBg`) behind every menu page |
| **Risk** | Low for correctness, medium for performance: the reason these pages were made still was frame cost on phones |

## Ticket

| ID | Title | Severity | Area |
|---|---|---|---|
| PAL-0982-1 | Animated backgrounds freeze on the Locker, Tables, Settings and Skills pages | Medium: a paid cosmetic (Gold/animated backgrounds) doesn't do what it says on those pages | Menu / rendering |

## PAL-0982-1: Animated backgrounds freeze on some menu pages

**Reported (Big U):** the animated main-menu backgrounds don't move on the Locker, Tables, Settings and Skills pages.

**Repro:**
1. Equip an animated background (for example Hellgate, or any animated Hybrid Theory block city).
2. On PLAY it moves.
3. Open LOCKER, TABLES, SETTINGS or SKILLS.

- **Actual:** the background freezes on one frame.
- **Expected:** it keeps moving on every menu page.

**Root cause:**
- **Where:** `drawLobbyBg()` in `dev/src/js/18b-backgrounds.js` decides when a background is drawn as a still:
  ```js
  still = B.still!==undefined || reduceMotion() || !stageVisible() || $('menu').dataset.page==='locker'
  ```
- **Pages that animate:** `stageVisible()` (`19b-social-lobby.js`) is true only on `STAGE_PAGES = ['solo','classes','multi','lobby','locker']` (PLAY, INDEX, MULTIPLAYER, the room lobby, Locker). Every other page gets a still: Skills, Settings, Account and Tables.
- **The Locker:** forced to a still separately, with the comment "the Locker's item grid is busy enough".
- **Why it was done:** a v0.9.1 performance choice ("behind the Locker, Settings and Account panels it's a still"). Every animated frame makes the browser composite the whole screen again, which was most of the menu's cost on phones.
- **How Tables got caught:** Tables (v0.9.8) and Skills were added later and fell into the still case by default. Nobody chose a still for them.
- **The still frame itself:** drawn at time 4 s, so each animated background freezes on the same pose.

**Fix spec:**
- **Every menu page animates:** remove the page conditions (`!stageVisible()` and the Locker check) from the still decision. The only things that still give a still frame:
  - a background that is still by design (`B.still`);
  - the system "reduce motion" setting (unchanged; accessibility);
  - the case opening's blurred intro (already paused there, unchanged);
  - the game itself running (the menu is hidden, so nothing is drawn).
- **Frame rate per page (D1):** the busy pages run the background at a lower rate so their own UI stays smooth:
  - PLAY, INDEX (the classes page), MULTIPLAYER, lobby: as now, 30 fps on desktop, 15 on phones;
  - LOCKER, TABLES, SKILLS, SETTINGS, ACCOUNT: 20 fps on desktop, 12 on phones.
  - The resolution stays as now: 1.5× on desktop, 1× on phones.
- **Background tab:** no drawing at all while the browser tab is hidden (`document.hidden`), as the rest of the menu already does.
- **One place for the rule:** a small `bgRate(page)` table next to `LOBBY`, so the next new page gets an animated background without anyone having to remember it.

**Acceptance criteria:**
- [ ] With an animated background equipped, the background canvas changes between two frames 1 s apart on PLAY, INDEX, LOCKER, TABLES, SKILLS, SETTINGS and ACCOUNT, at desktop 1366×820, phone portrait 390×844 and phone landscape 844×390.
- [ ] With a still background equipped, or with "reduce motion" on, it doesn't change on any page.
- [ ] Menu frame cost on the Locker stays within 10% of today's on desktop and phone. The Locker's item grid and the case reel still scroll smoothly. Measured with the existing presentation performance harness.
- [ ] Nothing is drawn while the tab is hidden.

**Tests (only what this touches):**
- **New `menu_bg_motion`:** for each page and size, read two frames 1 s apart from `#lobbyBg` and check they differ (animated background) or match (still background, reduce motion). Screenshots go in `dev/evidence/v0.9.8.2/`.
- **Re-run `presentation_perf`** for the Locker frame-cost gate.
- **Re-run `tables_ui` and `taborder`.**

## Release plan

1. The fix and the new test.
2. Re-run `presentation_perf`, `tables_ui` and `taborder`. No full suite (Big U, October 4).
3. Screenshots at three sizes. PR and merge.

## Decisions for Big U

| # | Question | Proposal |
|---|---|---|
| D1 | Busy pages (Locker, Tables, Skills, Settings, Account) at a lower background frame rate (20 desktop / 12 phone), or the full rate everywhere? | Lower rate on the busy pages; it looks the same for slow drifting backgrounds and keeps the Locker smooth on phones |
| D2 | The Account page too (you didn't list it, but it freezes for the same reason)? | Yes, every menu page |
| D3 | Keep "reduce motion" (the phone/OS accessibility setting) showing a still? | Yes |
