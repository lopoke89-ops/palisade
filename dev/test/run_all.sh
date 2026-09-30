#!/bin/bash
# Runs every PALISADE browser test against a local copy of the built site.
#   1. python3 ../build.py          (build the site into the repo root)
#   2. npm install                  (once; installs Playwright, the PeerJS server and terser)
#   3. ./run_all.sh
# Starts a static server on :8080 (the repo root) and a PeerJS server on :9000, runs each test,
# and prints PASS/FAIL. The accounts and rewards tests fake Supabase, so no internet is needed.
# Set CHROMIUM=/path/to/chromium to use a specific browser (the tests read it).
cd "$(dirname "$0")"; mkdir -p out; OUT=$(pwd)/out
ROOT=$(cd ../.. && pwd)
curl -s -o /dev/null localhost:8080/ || (cd "$ROOT" && setsid nohup python3 -m http.server 8080 > "$OUT/http.log" 2>&1 < /dev/null &)
curl -s -o /dev/null localhost:9000/ || (setsid nohup node peer-server.js > out/peer.log 2>&1 < /dev/null &)
sleep 1.5
fail=0
for t in ${TESTS:-solo bosses multiplayer cases accounts rewards_lobby_shotgun reel_music music_routing v086 v087 muzzle cosmetics locker_fit locker_collections cosmetic_network social_lobby lobby v090 v090_net hostcheck room_controls csp wardrobe3d friends rewards_screen modifiers skilltree rejoin controller taborder milestones flagcase presentation presentation_posefit presentation_network tracer_cycle tracer_network ultimate_cloud cosmetics_expansion cosmetics_migration rejoin_migration rejoin_drop fps_mode delgado}; do
  out=$(timeout 300 node $t.js 2>&1); echo "$out" > out/$t.log
  if echo "$out" | grep -qiE "errors?:? *(none|\[\])|ERRS \[\]" && ! echo "$out" | grep -qiE "Error:|TypeError|timed out"; then echo "PASS  $t"; else echo "FAIL  $t  (see out/$t.log)"; fail=1; fi
done
exit $fail
