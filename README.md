PALISADE: phone version with online co-op
=========================================

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
  - QUARTERMASTER: walk over a downed teammate (or Dell) and they're up
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
      CO-OP         everyone plus Dell against the raiders.
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
  index.html                the game
  peerjs.min.js             online play (PeerJS 1.5.5, MIT license); loads in the background after the menu is up
  *.woff2                   Big Shoulders Stencil Display and IBM Plex Mono (SIL Open Font License)
  manifest.webmanifest      app name, icon and full-screen setting for home screens
  sw.js                     saves a copy on the phone for offline solo play
  apple-touch-icon.png      the iPhone home-screen icon
  icon-*.png                icons for Android and browsers
