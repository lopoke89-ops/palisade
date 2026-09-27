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


PLAYING ONLINE
--------------
  - One person taps MULTIPLAYER > HOST and gets a 4-letter code.
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
