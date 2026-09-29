#!/bin/bash
# Run only the tests related to a changed area. Use run_all.sh for an explicit full sweep.
set -e
case "${1:-}" in
  cosmetics) tests='locker_fit cosmetics wardrobe3d cosmetic_network' ;;
  locker) tests='locker_collections locker_fit milestones flagcase accounts taborder csp' ;;
  music) tests='music_routing' ;;
  combat) tests='solo bosses multiplayer muzzle rewards_lobby_shotgun' ;;
  host) tests='hostcheck room_controls multiplayer' ;;
  smoke) tests='solo lobby reel_music csp' ;;
  all) exec "$(dirname "$0")/run_all.sh" ;;
  *) echo 'Usage: ./run_targeted.sh {cosmetics|locker|music|combat|host|smoke|all}' >&2; exit 2 ;;
esac
TESTS="$tests" exec "$(dirname "$0")/run_all.sh"
