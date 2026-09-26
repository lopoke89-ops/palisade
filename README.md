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
  - Up to 6 players plus Dell. The host taps RAISE THE FENCE to start.
    Friends can also drop into a game that's already running.
  - The host's phone runs the game. If the host locks their phone or
    leaves, the game ends for everyone.
  - Phones connect straight to each other. A free public service
    (PeerJS) introduces them and never sees the game itself. Home Wi-Fi
    almost always works. Some cellular networks block direct connections;
    if a join hangs, get on Wi-Fi.


FILES
-----
  index.html                the game
  peerjs.min.js             online play (PeerJS 1.5.5, MIT license); loads in the background after the menu is up
  *.woff2                   Big Shoulders Stencil Display and IBM Plex Mono (SIL Open Font License)
  manifest.webmanifest      app name, icon and full-screen setting for home screens
  sw.js                     saves a copy on the phone for offline solo play
  apple-touch-icon.png      the iPhone home-screen icon
  icon-*.png                icons for Android and browsers
