# PALISADE: developer folder

Everything needed to rebuild, test and restore the game. The playable site is the repo's top
level (built from here); this folder is the source.

```
dev/
  src/palisade.html     the whole game (edit this, never the built index.html)
  build.py              builds the site into the repo root
  audio/                music, AAC (.m4a) and Opus (.ogg)
  vendor/               PeerJS 1.5.5 and the two fonts (bundled so builds work offline)
  test/                 browser tests + run_all.sh
  supabase/schema.sql   restore script for the server (tables, rules, functions, case data)
```

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

It serves the built site on localhost:8080, starts a PeerJS server on :9000, runs every test and
prints PASS or FAIL for each; logs and screenshots go to `dev/test/out/`. The account and reward
tests fake Supabase, so they don't touch real players.

## Publish

1. Build, then test.
2. Open GitHub Desktop: the changed files show up. Write a summary (for example "v0.8.5: ...").
3. **Commit to main**, then **Push origin**. GitHub Pages is live about a minute later.

## Rules that keep saves and online play safe

- Never rename the `palisade.*` browser storage keys; that wipes players' local saves.
- Change `PROTO` in src/palisade.html whenever the network messages change, so old and new
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

The between-raid track is `audio/between_raids.m4a` + `.ogg`. To replace it, encode both from a
WAV and update the loop length (in samples) in `MUSIC` inside src/palisade.html:

```
ffmpeg -i track.wav -c:a aac -b:a 160k -movflags +faststart between_raids.m4a
ffmpeg -i track.wav -c:a libopus -b:a 128k between_raids.ogg
```
