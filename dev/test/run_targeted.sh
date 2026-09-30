#!/bin/bash
# Run only the tests related to a changed area. Use run_all.sh for an explicit full sweep.
set -e
case "${1:-}" in
  cosmetics) tests='locker_fit cosmetics wardrobe3d cosmetic_network tracer_cycle tracer_network ultimate_cloud cosmetics_expansion cosmetics_migration headgear_fit' ;;
  locker) tests='locker_collections locker_fit milestones flagcase accounts taborder csp sp_cases sp_cases_migration' ;;
  presentation) tests='presentation presentation_posefit flagcase wardrobe3d locker_fit muzzle presentation_network cosmetic_network csp' ;;
  music) tests='music_routing' ;;
  combat) tests='solo bosses multiplayer muzzle rewards_lobby_shotgun touch_lock mod_synergy boss_milestones' ;;
  host) tests='hostcheck room_controls multiplayer rejoin rejoin_drop rejoin_migration' ;;
  smoke) tests='solo lobby reel_music csp fps_mode delgado ingame_settings hud_layout tips_toggle' ;;
  all) exec "$(dirname "$0")/run_all.sh" ;;
  *) echo 'Usage: ./run_targeted.sh {cosmetics|locker|presentation|music|combat|host|smoke|all}' >&2; exit 2 ;;
esac
TESTS="$tests" exec "$(dirname "$0")/run_all.sh"
