# PALISADE: developer folder

Everything needed to rebuild, test and restore the game. The playable site is the repo's top
level (built from here); this folder is the source.

```
dev/
  src/                  the game's source, in pieces (edit these, never the built index.html)
    page.html           the page: menus, HUD and overlay markup
    style.css           all the styles
    js/01-...22-*.js    the game script, in order (js/ORDER.txt says what each file holds)
  assemble.py           joins src/ back into one file (build.py uses it)
  build.py              builds the site into the repo root
  audio/                music, AAC (.m4a) and Opus (.ogg)
  vendor/               PeerJS 1.5.5 and the two fonts (bundled so builds work offline)
  test/                 browser tests + run_all.sh
  supabase/schema.sql   restore script for the server (tables, rules, functions, case data)
```

## Source layout

The game is one script split across `src/js/`, joined in file-name order. It all runs in one shared scope,
so a file can use anything defined in an earlier one (and functions from any file). Keep the order: a
`const` used at start-up must come from an earlier file. New files slot in by number (e.g. `13b-...js`).
`python3 dev/assemble.py out.html` writes the joined source if you want to read it in one piece.

## Build

Needs Python 3 and Pillow (`pip install pillow`, for the icons).

```
python dev/build.py
```

It writes index.html, sw.js, the icons, manifest, fonts, PeerJS and music into the repo root and
gives the offline cache a new version name, so players pick the update up on their next load.

## Test

Needs Node 18+ and Python 3.

```
cd dev/test
npm install
npx playwright install chromium
./run_all.sh
```

Profiling: `NOMIN=1 python3 dev/build.py` keeps debug.html unminified (readable function names), and
`node stress.js` measures the heavy cases (Endless raid 20, a 6-player boss raid, 6 players in Endless
raid 20, and memory over a 30-minute Endless run); `PROFILE=1` adds the busiest functions.
`bench.js` is the quick frame-time check; `PORT=8083 PAGE=index.html node bench.js old` measures another copy.

It serves the built site on localhost:8080, starts a PeerJS server on :9000, runs every test and
prints PASS or FAIL for each; logs and screenshots go to `dev/test/out/`. The account and reward
tests fake Supabase, so they don't touch real players.

## Publish

1. Build, then test.
2. Open GitHub Desktop: the changed files show up. Write a summary (for example "v0.8.6: ...").
3. **Commit to main**, then **Push origin**. GitHub Pages is live about a minute later.

## Rules that keep saves and online play safe

- Never rename the `palisade.*` browser storage keys; that wipes players' local saves.
- Change `PROTO` (src/js/21-online.js, with `ROOM_PREFIX`) whenever the network messages change, so old and new
  copies refuse to join each other instead of breaking.
- Versions: patch bumps (v0.8.5, v0.8.6...) unless a change is major. The version appears in the
  main menu footer.
- The Supabase key in the game is the public "publishable" key. The secret key never goes in
  this repo.

## Server (Supabase project puvjfhwxigxjpsvdwrwf)

`supabase/schema.sql` rebuilds the server side in an empty project (SQL editor, run once). It
does not include player data, the blocked-words list, or Auth settings: anonymous sign-ins must
be on, and email needs custom SMTP.

## Music

Two tracks, each as AAC (.m4a) and Opus (.ogg) in `audio/`: `between_raids` (co-op/Endless build
phases) and `locker` (the Locker page). To replace one, encode both formats from a WAV under the
same name and update its loop length (in samples) in `MUSIC` inside src/js/03-audio.js. A new
track = a new entry in `MUSIC`, its name in `MUSIC_FILES` in build.py, and a case in `musicWant()`.

```
ffmpeg -i track.wav -c:a aac -b:a 160k -movflags +faststart between_raids.m4a
ffmpeg -i track.wav -c:a libopus -b:a 128k between_raids.ogg
ffprobe -v error -select_streams a -count_packets -show_entries stream=duration_ts track.wav   # loop length
```

## Debug copy

The build also writes `debug.html` (not committed): the same game with the test hooks
(`?debug=1` exposes `window.__pal`) and the profiler. The tests use it; players get index.html,
which has neither. Minifying needs terser (`npm install` in dev/test installs it).
