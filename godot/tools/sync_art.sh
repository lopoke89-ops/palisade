#!/bin/bash
# Copies the runtime part of the 3D model library (lopoke89-ops/palisade-3d-model-library) into godot/palisade_art/:
# the metadata the game reads and the models it shows. Authoring files (sources, previews, tools, .blend) stay out.
#   godot/tools/sync_art.sh /path/to/palisade-3d-model-library      (then open the project once, or run --import)
# Records the library commit in palisade_art/LIBRARY.txt, so the art in the game is pinned to one revision.
set -euo pipefail
LIB="${1:?path to the palisade-3d-model-library checkout}"
SRC="$LIB/art/3d"
cd "$(dirname "$0")/.."
DST=palisade_art
[ -f "$SRC/catalog.json" ] || { echo "no art/3d/catalog.json under $LIB"; exit 1; }
rm -rf "$DST"
mkdir -p "$DST/animation" "$DST/models"
cp "$SRC/catalog.json" "$SRC/lobby_layouts.json" "$SRC/weapon_profiles.json" "$SRC/tracer_profiles.json" "$DST/"
cp "$SRC/animation/manifest.json" "$DST/animation/"
# what the game uses: the classes, skins, headgear (and its fitted variants), the lobby environments, the party ring,
# the weapons; and in play the raiders, the bosses, Delgado, the tracer rounds and the kill effects
for d in players skins headgear backgrounds utilities weapons enemies bosses allies tracers kill_effects; do
  cp -r "$SRC/models/$d" "$DST/models/"
done
{
  echo "lopoke89-ops/palisade-3d-model-library"
  git -C "$LIB" rev-parse HEAD
  git -C "$LIB" rev-parse --abbrev-ref HEAD
} > "$DST/LIBRARY.txt"
echo "synced $(find "$DST/models" -name '*.glb' | wc -l) models from $(head -c 7 <<<"$(sed -n 2p "$DST/LIBRARY.txt")") into godot/$DST ($(du -sh "$DST" | cut -f1))"
