PALISADE: phone version with online co-op
=========================================

LOCAL UPDATE: v0.9.6.2 / yard-22 adds the seven-track soundtrack and atomic five-case openings. The rebuilt candidate and focused checks are ready for review; see [completion evidence](dev/evidence/2026-10-01-music-case-batches/README.md).

PUBLISHED RELEASE: v0.9.6.1. Winter models, tracer refinements, Delgado Follow/Defend commands, Dead End, and 20-hit shields are live. Commit [526831b](https://github.com/lopoke89-ops/palisade/commit/526831bad0c4369a5058f9a5812e20413a1e9367) and the live HTML match. See [winter evidence](dev/evidence/2026-10-01-winter-upgrade/README.md) and the [311-entry four-angle catalog](dev/catalog/cosmetics/README.md).

PREVIOUS RELEASE: v0.9.6.0. Frostpeak adds three functional elevation tiers,
ramps/stairs and the Rime Colossus. Operation Whiteout connects all four maps
and ends with one five-minute personal evacuation rush. The collection adds
42 winter cosmetics, with milestones and a 14-shard Winter Case.
Accepted friends can invite each other to public/private host rooms.
Protocol yard-21. Both backend migrations are applied and verified.
See dev/evidence/2026-10-01-winter-whiteout/README.md for release evidence,
BALANCE.md for contracts/tuning, and CATALOG.md for all 42 items.

This folder is the whole game as a website. Put it online once and anyone
can play by opening the link. No app store, no download.

Why it needs a real website: the Claude preview link can't reach the
internet (so no multiplayer there) and can't be installed on a home screen.


PUT IT ONLINE (pick one; both are free)
---------------------------------------

Option A: Netlify Drop (about 2 minutes, no coding)
  1. Go to https://app.netlify.com/drop
  2. Drag this whole "Phone Web" folder onto the page.
  3. You get a link like https://something-random.netlify.app. That's the game.
  4. Make a free account when it asks, or the site is deleted after an hour.
     In Site settings you can rename it (e.g. palisade-bigu.netlify.app).
  To update later: in your site's "Deploys" tab, drag the folder in again.

Option B: GitHub Pages
  1. Make a new public repository on github.com (e.g. "palisade").
  2. "Add file" > "Upload files", drag in everything in this folder, commit.
  3. Settings > Pages > Source: "Deploy from a branch", branch "main", folder "/ (root)".
  4. After a minute the game is at https://YOURNAME.github.io/palisade/

The link has to be https (both options give you that). Offline play and
"install as an app" only work over https.


PUT IT ON AN IPHONE'S HOME SCREEN (the "pseudo install")
--------------------------------------------------------
  1. Open the game link in Safari (on iOS 16.4+ Chrome works too).
  2. Tap the Share button (square with an arrow pointing up).
  3. Scroll down, tap "Add to Home Screen", then "Add".
  The fence icon opens the game full-screen with no browser bars, like an
  app. After the first launch, solo also works with no signal. The main menu
  shows these steps to iPhone players who haven't installed it yet.

Android: Chrome shows an "INSTALL AS AN APP" button on the main menu
(or use the ⋮ menu > "Add to Home screen").


JOBS, BOSSES AND SALVAGE (v0.8.1)
---------------------------------
  - SOLDIER: carbine, builds 40% faster, takes more hits.
  - SNIPER: bolt-action rifle, one heavy round per pull, through wood.
  - GRENADIER: pump shotgun. 7 pellets in a tight, even spread; full
    damage out to 2.5 tiles, less further out. Six shells, loaded one at a time
    when the tube runs dry, after a second without firing, or with R.
    Three grenades a raid, bigger blasts.
  - QUARTERMASTER: walk over a downed teammate (or Delgado) and they're up
    instantly with 60% health. Carries 96 of each material, gathers
    faster, repairs cost half. SMG.
  - Bosses: every 5th raid in co-op (5, 10, 15, 20...) has a boss in it,
    in place of two riflemen, and the raid isn't over until it's down.
    Order: THE DEMOLISHER (slow rockets down a red line; every third
    volley is a fan of three; burning ground), THE BUTCHER (sword; red
    wedge = a cut is coming, red lane = a charge down it; faster below
    40%), THE STORMCALLER (lightning rifle; blue line tracks you, locks
    for the last moment; stuns and jumps to two people nearby; fires
    twice below 50%). Killing one pays the killer 40 salvage, 15 to
    everyone else. New bosses: add an entry to BOSSES and BOSS_ORDER in
    index.html.
  - Knocking down a wall that isn't yours pays salvage: wood 5, brick 8,
    metal 15. In co-op that's the old ruins in the yard; in Base Battle
    it's the other crew's walls and the ruins. Your own side's walls (any
    wall a player built, repaired or changed) never pay.
  - Online games need everyone on v0.8.1 or later: an older copy is told
    to reload.


MILESTONES, CLASS REWARDS, MORE HALLOWEEN, THE FLAG CASE (v0.9.3)
------------------------------------------------------------------
  - MILESTONES: every boss (Butcher, Demolisher, Stormcaller, Ferryman,
    Foreman) has four outfits built on its look, unlocked by beating it
    25 / 50 / 100 / 250 times in runs you were in. Every map (Yard,
    Riverbend, Quarry) has four outfits for 250 / 500 / 1000 / 2500 raids
    held there. The steps go Rare, Epic, Legendary (one moving effect) and
    Gold (the best effects in the game).
  - CLASS REWARDS: each class unlocks headgear, a tracer, a kill effect
    and a Gold outfit at 250 / 500 / 1000 / 2500 raids held as that class
    (the class you end a run as).
  - The Locker has a MILESTONES tab with every ladder and its count, and
    locked items show a progress bar. After a run, a card shows the
    milestone you're closest to. Counting starts with this version.
  - HALLOWEEN CASE: Sheet Ghost, Scarecrow, Frankenstein's Monster, Scary
    Clown, Hockey-Mask Slasher and Dracula, plus Candle Flicker, Poison
    Apple, Blood Trail and Hellfire tracers.
  - FLAG CASE: 32 flags, each as a lobby background and a tracer. A 25%
    chance for everyone after any win (co-op or PvP), or 10 shards.


CONTROLLERS (v0.9.2.1)
----------------------
  - Plug in or pair a controller (Xbox, PlayStation and most others) and
    press any button. Works in Chrome and Edge on PC, Chrome on Android
    and Safari on iPhone and iPad.
  - PLAYING: left stick moves, right stick aims (with the same gentle aim
    help phones get), RT fires. LT grenade, A build (hold to keep
    building), B your ability (rocket or stealth), or sprint if your job
    has no ability, X armory at your stake, Y wall/door, d-pad left and
    right change material, d-pad down turns the build kit on or off, View
    starts the raid (host), Menu pauses. Guns that fire once per shot fire
    once per trigger pull.
  - MENUS: the d-pad or left stick moves a yellow highlight, A picks, B
    goes back or closes. LB and RB flip through the lobby pages, LT and
    RT through tabs (locker, friends). The right stick scrolls long pages.
    A hint bar at the bottom shows this while you're in a menu.
  - CHANGE YOUR BUTTONS: Settings, CONTROLLER card. Pick an action, then
    press the button you want for it (a button already in use swaps over).
    RESET BUTTONS puts everything back. Reload is there too, off by
    default, since guns reload on their own. Your buttons are saved on
    this device.
  - The pause screen shows your current layout while a controller is
    connected, and every button hint in the game switches to controller
    buttons (PlayStation symbols on a PlayStation controller).
  - RUMBLE on hits and blasts, under the same Vibration setting phones use
    (Chrome and Edge; iPhones don't support controller rumble).
  - Touch the screen, move the mouse or press a key and the game switches
    back on its own. On a phone the touch sticks hide while you use the
    controller.
  - Typing (logging in, typed chat) still needs a keyboard or touch; the
    quick-chat buttons work with the controller.
  - Keyboard players: Tab now moves through every menu in order and stays
    inside the pause and armory windows.
  - One player per device. Mixing controller, keyboard and phone players
    in the same online game is fine.


MODIFIERS, THE SKILL TREE, CLASS ABILITIES (v0.9.2)
---------------------------------------------------
  - MODIFIERS: switch them on under MODIFIERS on the SOLO page, or in the
    room (the host picks; everyone sees them). Only the ones that work in
    the mode you're hosting are listed. Co-op: No Patch-Ups, On Your Own
    (no Delgado), Firestorm, Adrenaline, Last Stand, Elite Raid, Boss Rush,
    Weather, Nightmare, Berserk. Base Battle and Free-for-all: Adrenaline,
    Weather, Nightmare (night only), Glass Cannon, One Job, Grenade Frenzy,
    plus Scrap Shortage (Base Battle) and Sudden Death (Free-for-all).
    Harder co-op modifiers raise your rewards (up to +75%); Adrenaline
    lowers them a little. Best scores are kept per set of modifiers.
  - Boss Rush and Nightmare bosses in between the usual ones (raids 5, 10,
    15 still drop their case) pay 15-30 shards each.
  - SKILLS: a new page with one skill tree for every job. You earn 1 point
    for every 5 raids you hold and 1 for every boss that goes down (needs an
    account; a guest account works). Weapon, health and movement perks, plus
    upgrades for each job's ability. Reset the tree for 40 shards. In Base
    Battle and Free-for-all the perks count half and job nodes are off.
  - ABILITIES (co-op, key Q or the new button by the grenade): the Soldier
    fires rockets (5 a run, 2 back each build phase), the Sniper goes
    unseen for 12 seconds (raiders stop targeting you). The Grenadier's tree
    has more grenades and Molotovs; the Quartermaster keeps sprint.
  - Leaving a run and coming back no longer pays for the same raids twice:
    you're paid for the raids you were there for.
  - Phones: all six players now show on the lobby stage.


FRIENDS, PVP ON EVERY MAP, A NEW LOCKER (v0.9.1)
------------------------------------------------
  - FRIENDS: the button next to your name (top right). Find a player by
    username and send a request; they accept or decline. Requests and a
    mailbox have their own tabs, and a red dot shows what's new. Needs a
    saved account. Players you saved before are under RECENT.
  - PvP on every map: the host picks the map for Base Battle and
    Free-for-all too. Each map has a mirrored Base Battle layout and its own
    Free-for-all arena. PvP is always 16x16.
  - Change your job in the room before the start, and in Free-for-all from
    the pause menu or while you wait to respawn (it applies when you're
    back in).
  - XL boss raids bring two different bosses at once, each a little weaker.
    Riverbend's raiders are a bit tougher, the Quarry's a bit more; XL adds
    a little more. Oil drums no longer stop bullets.
  - The Locker, Settings and Account pages use the new lobby. Thumbnails fit
    their squares, cases open with a short intro (tap to skip), and the end
    screen shows your rewards as cards with progress to the next case.
  - New looks: a rounder Jack-o'-Lantern, and the Grenadier carries a pump
    shotgun and a belt of grenades. "Glitch Mask" is now "Glitch Head".


SMOOTHER NIGHTS AND DUSK (v0.8.8)
---------------------------------
  - Night raids draw about 30% faster on phones (12.5 to 8.9 ms a
    frame; slowest frames 15.5 to 11.2 ms). The soft pools of light
    around players, Delgado, the core and raiders, and the muzzle and
    explosion glows, are now stamped from pre-drawn circles instead of
    stretching a small one every frame.
  - Dusk raids draw about 60% faster (14.3 to 5.7 ms a frame): the warm
    evening colour was a full-screen blend mode that phones do slowly.
    It's now one plain tint, matched to the old look (within about
    1% of the old colours).
  - A 6-player boss raid went from 15.9 to 8.6 ms a frame. Big Endless
    crowds (20+ raiders, 6 players) from 9.9 to 8.4 ms. Memory stays
    flat over a 30-minute Endless run.
  - Behind the scenes: the game's source is now split into sections
    (see dev/README.md). The game plays exactly the same.
  - Nothing changes online: v0.8.7 and v0.8.8 players can play together.


BURSTS, REPAIRS AND A STRONGER DELL (v0.8.7)
--------------------------------------------
  - SOLDIER: the carbine fires bursts. A burst always finishes once
    it starts (one click is a full burst; hold to keep firing).
    Rounds per burst and the pause after it follow your DAMAGE level:
      level 0: 3 rounds, 0.40 s pause    level 3: 9 rounds, 0.25 s
      level 1: 5 rounds, 0.35 s          level 4: 9 rounds, 0.20 s
      level 2: 7 rounds, 0.30 s
    FIRE RATE tightens the spacing inside a burst (0.09 s at level 0).
  - SNIPER: in co-op a round every 0.7 s (was 1 s), still 47 damage,
    so it still drops a rifleman in one shot through raid 4 on Normal.
    Base Battle and Free-for-all keep 1.25 s. Hold the button to keep
    firing; a click during the bolt is still kept.
  - Move speed: sniper 10% faster, grenadier 10% slower, soldier and
    quartermaster unchanged.
  - QUARTERMASTER SPRINT (Shift, or the SPRINT button): 40% faster for
    2.5 s, no shooting while sprinting, then 6 s to recharge. Only the
    quartermaster can sprint.
  - REPAIR CORE (Armory, co-op and Endless): 25 salvage restores up to
    50 core health, never past full; the quartermaster pays 13. It's
    greyed out when the core is full, so nothing is charged. Not in
    Base Battle (the armory is open during the fight there).
  - DELL: 180 health (was 90) and a pump shotgun (5 pellets of 6,
    every 0.8 s, full damage to 2.5 tiles). New DELL row in the Armory:
    one upgrade shared by the whole crew, anyone can buy the next level
    (30 / 60 / 100 / 150 salvage), each adding 15% damage, 15% reach
    and 15% fire rate (level 4: +60% of each).
  - Leftover salvage becomes shards when a co-op or Endless run ends:
    20 salvage = 1 shard, whole shards only, at most 2 per raid held
    and 10 per run. Spent salvage doesn't count, and what converts is
    used up. Accounts: the server applies the same limits.
  - Aiming: bullets travel along the ground and hit around a raider's
    feet, but the mouse aimed as if everything stood at hip height, so
    a shot at someone's head could pass up to a tile beside them. Now,
    with the cursor anywhere on a raider (boots to helmet), or on an
    enemy player in PvP, the shot goes straight at them.
  - Online games need everyone on v0.8.7 or later.


LOCKER MUSIC, LEANER GAME (v0.8.6)
----------------------------------
  - Locker music: a new track plays on the LOCKER page (and through
    case spins), fades out when you leave, loops with no gap. Same
    MUSIC slider. Files: locker.m4a and locker.ogg, downloaded the
    first time you open the Locker and kept for offline. Only the track
    that can play right now stays in memory (a decoded minute of music
    is about 20 MB): the raid track is let go in the menus, the locker
    track during a run.
  - Night raids draw about 16% faster on phones (14.2 to 11.4-12 ms a
    frame) and the worst frames about 25% faster (18.6 to 13-15 ms).
    Lists of effects, enemies and rockets are tidied in place instead
    of rebuilt every frame, and the scene is sorted from one reused
    table, so there's less memory churn and fewer stutters.
  - Gradient and rainbow tracers are drawn from a small cached colour
    strip instead of a new gradient per bullet. They look the same.
  - Online: about 16% less data per guest in a busy fight (12.9 to
    10.8 KB/s). Names, outfits and jobs are sent only when they change,
    not 15 times a second, and enemy rows drop empty fields.
  - Sounds: at most 14 positional sounds start in any 0.12 s, sounds
    too far away to hear aren't played, and walls between you and a
    sound share one muffle filter per wall count. Big fights no longer
    pile up hundreds of audio nodes.
  - Solo players no longer download the online-play code (PeerJS) at
    startup; it loads when you open MULTIPLAYER or follow an invite
    link. The game script is minified (about 245 KB for index.html),
    and the debug hooks and profiler are no longer in the published
    page.
  - Signing in is quicker: the locker and profile load at the same
    time, and the locker isn't fetched twice right after a run is
    saved. Coming back to the tab re-checks the account only after
    2 minutes away.
  - The Open Games list only redraws when a game in it changes.
  - Server: two unused old case functions were removed.
  - Online games need everyone on v0.8.6 or later.


SMOOTHER ON PHONES, LIGHTER ONLINE (v0.8.5)
-------------------------------------------
  - Drawing a busy raid takes about a third of the time it did on
    phones (measured: 13.6 ms to 4 ms a frame by day, 14.8 to 6 at
    night). The scenery is stored at the screen's own sharpness and
    copied straight on, the empty parts of the front tree layer are
    skipped, each wall is drawn once and reused until it changes, and
    colours and outfits are worked out once instead of every frame.
  - Sitting in the menus uses about a sixth of the power it did: the
    game running behind the menu slows to 12 frames a second behind
    sub-pages and the case spin (30 behind the main menu on phones).
  - Online: about 40% less data per guest in a busy fight (20 KB/s to
    12 KB/s). Game state goes on a channel that never resends (a late
    copy is useless), while sounds, effects, bullets, toasts and wall
    changes go on the reliable one, so none of them can be lost with a
    late packet. Bullets are sent once when fired; walls send only the
    tiles that changed; repeated particles are sent once with a count.
  - Online games need everyone on v0.8.5 or later (older copies can't
    see or join v0.8.5 games, and the other way round).
  - See-through walls (when you stand behind them) fade evenly now.


CASE SPIN AND MUSIC (v0.8.4)
----------------------------
  - Case spin: every item in the reel shows its rarity (coloured label
    and strip). A long name used to stretch the tiles and push the
    strip out of view, mostly in the Afterglow case.
  - The spin ticks: a soft click and beep as each item passes the
    marker, pitched higher for rarer items. Case sounds (the tick, the
    reveal, the gold fanfare) also play now; they were muted by the
    demo game running behind the menu.
  - Music between raids: plays during co-op / Endless build phases
    (including the one before raid 1), fades in, fades out when the
    raid starts, loops with no gap. MUSIC slider in Settings (0 = off).
    Not in PvP. Files: between_raids.m4a (AAC, Safari/iPhone/Chrome)
    and between_raids.ogg (Opus, for browsers without AAC). Each is
    downloaded once, the first time it plays, and kept for offline.
    New track: replace both files (same names); MUSIC in index.html
    holds the loop length in samples.


OPEN GAMES, BOSS DROPS, SHOTGUN (v0.8.3)
---------------------------------------
  - OPEN GAMES: the Multiplayer page lists games people are hosting
    (name, mode, players, in lobby or in progress). Tap one to join.
    Full games are greyed out. Hosting lists your game unless you untick
    "List my game in Open Games"; a code still works either way. A game
    drops off the list within 45 seconds of the host leaving. Needs the
    game server (guest or account); joining by code doesn't.
  - Every boss killed in co-op or Endless gives everyone in the run +1
    Afterglow Case, added with the rest of the run's rewards.
  - No daily limit on cases any more.
  - Rewards now show what the server actually saved ("+1 supply case ·
    +1 afterglow case from bosses. Saved to your account."). If the
    server turns a result down you're told, instead of the case
    silently not arriving. Offline results are kept on the device and
    sent when you're back.
  - Anti-farming (server side): a result can't claim more play time than
    real time has passed on that account (up to about 6 hours banked),
    raids need a believable length, and drops are capped at 1 a second.
    A result that's too early isn't lost: the game keeps it and sends it
    again a few minutes later.
  - Leaving a co-op run early still counts the raids you held and the
    bosses you beat.
  - GRENADIER shotgun: 12 damage per pellet (84 if all 7 hit). Fires as
    fast as you can click (up to about 8 a second); holding the button
    fires every 0.5 s.
  - Online games need everyone on v0.8.3 or later.


CASES (v0.8.2)
--------------
  - SUPPLY CASE: co-op and Endless only (one every 3 raids held, plus
    wins). Common 60%, rare 27%, epic 10%, legendary 3%.
  - AFTERGLOW CASE: 49 new items (neon, cosmic, gradient, gold). Drops
    from every co-op boss, from Base Battle and Free-for-all (45% / 50% after a win, 20% after
    a loss) or costs 10 shards. Common 53%, rare 30%, epic 12%,
    legendary 4%, GOLD 1%. Gold: Gold Clown / Gold Police / Gold Metal
    Knight outfits, Gold Clown Hair, Gold Knight Helm, Gold Rainbow
    tracer, Gold Bubbles kill effect.
  - Shards (from duplicates: 1 / 3 / 8 / 20 / 40) now buy Afterglow
    cases only; Supply cases are earned in co-op.
  - Tracers and kill effects have their own sounds (quiet, layered on
    the gunshot at most every 0.22 s).
  - Cases are data: CASES in index.html (names, odds, shard price, drop
    table per mode) and the case_types table in Supabase, which is the
    one that counts for accounts. Adding a case = one row there, one
    entry in CASES, and items tagged with its id in both lists.


PLAYING ONLINE
--------------
  - One person taps MULTIPLAYER > HOST and gets a 4-letter code. The
    game also shows up under OPEN GAMES for anyone to tap and join.
  - Friends tap MULTIPLAYER, type the code, tap JOIN. Or the host taps
    SHARE INVITE LINK and friends open the link, which fills the code in.
  - Up to 6 players. Before hosting, pick a mode:
      CO-OP         everyone plus Delgado against the raiders.
      BASE BATTLE   two crews (WEST and EAST), a 45-second truce to
                    build, then knock down the other stake. Use SWITCH
                    SIDES in the lobby to pick a crew.
      FREE-FOR-ALL  everyone for themselves around concrete cover;
                    first to 15 drops or most after 5 minutes.
    PvP needs at least two players. Friends can drop into a game
    that's already running.
  - Works on computers too: WASD move, mouse aim and fire, Space build,
    E armory at your stake, G grenade, T chat, Esc pause. The bar at the
    bottom of the screen always shows the keys that do something right now.
  - Text chat works in the lobby and in the game. On a computer press T
    (or /), type, Enter to send. On a phone tap the speech bubble next to
    pause; it also has one-tap lines (NICE, HELP!, ON MY WAY...).
  - The host's phone runs the game. If the host locks their phone or
    leaves, the game ends for everyone.
  - Phones connect straight to each other. A free public service
    (PeerJS) introduces them and never sees the game itself. Home Wi-Fi
    almost always works. Some cellular networks block direct connections;
    if a join hangs, get on Wi-Fi.


ACCOUNTS (v0.8)
---------------
  - Accounts only run on https://lopoke89-ops.github.io/palisade/ (add
    ?cloud=1 to test another address). A copy opened anywhere else keeps
    the locker in the browser only, like before.
  - Every player gets a guest account quietly the first time the menu
    opens. Nothing to type. Any locker already saved in that browser is
    merged into it once.
  - MAIN MENU > ACCOUNT: pick a username, add an email to keep the locker
    on any device (we email a link; open it, then choose a password), sign
    in to an existing account, reset a forgotten password, sign out.
    Signing out goes back to the guest account that browser had.
  - With an account, the server owns the locker: cases are rolled there,
    and each finished run or match is sent there and checked before cases
    are handed out (max 15 cases a day from play). A run finished with no
    signal is kept and sent when the connection is back. Opening or
    crafting a case needs a connection.
  - Backend: Supabase project puvjfhwxigxjpsvdwrwf. The key in index.html
    is the public "publishable" key; it can only call the game's checked
    functions. Never put the secret key in this folder.
  - Before real players add emails: set up custom SMTP (for example,
    Resend) under Authentication > Emails. The built-in sender only
    mails your own Supabase team, a few times an hour.
  - Turning on CAPTCHA (Cloudflare Turnstile) needs the site key pasted
    into TURNSTILE_KEY in index.html at the same time. Otherwise guest
    accounts stop being created.


YOUR SAVE (LOCKER)
------------------
  - With an account (see above), the account holds the locker and this
    browser keeps a copy. Without one, everything below applies as-is.
  - The locker (cosmetics, cases, shards, stats), best runs and settings
    are saved in the browser for this site. Pushing a new version of the
    site does NOT touch them: the save keys never change between versions,
    and the offline copy (sw.js) only replaces its own cached files.
  - What can still wipe a save: clearing the browser's site data, a
    private/incognito window, or on iPhone Safari, not opening the site for
    7 days of Safari use (Apple's rule). Installing to the home screen
    avoids that last one. Moving the game to a different web address also
    starts fresh saves, because saves belong to the address.
  - Backup: SETTINGS > EXPORT SAVE gives a save code (copy it or download
    it as a .txt file). SETTINGS > IMPORT SAVE takes the code or file back
    and restores everything; it works on any device or browser. With an
    account, a code is merged into the account instead, once per account.
  - If the save gets damaged, the game restores the last good copy it
    kept and says so on the main menu.
  - Rule for future updates: never rename the palisade.* storage keys.


FILES
-----
  dev/                      the source, build script, tests and a server restore
                            script (see dev/README.md); not part of the game itself
  index.html                the game
  peerjs.min.js             online play (PeerJS 1.5.5, MIT license); loads when MULTIPLAYER opens or from an invite link
  between_raids.m4a/.ogg    music between raids (AAC and Opus)
  locker.m4a/.ogg           music on the Locker page
  *.woff2                   Big Shoulders Stencil Display and IBM Plex Mono (SIL Open Font License)
  manifest.webmanifest      app name, icon and full-screen setting for home screens
  sw.js                     saves a copy on the phone for offline solo play
  apple-touch-icon.png      the iPhone home-screen icon
  icon-*.png                icons for Android and browsers
