#!/bin/bash
# Builds the Windows game: export/palisade/Palisade.exe (the game, its data packed inside) and the WebRTC DLL beside it.
#   tools/export_windows.sh [path/to/godot-4.7.2]
# Needs Godot 4.7.2's export templates; if they're missing it downloads them once (about 1.3 GB) and keeps only the
# Windows ones. Uses the "Windows Desktop" preset in export_presets.cfg (x86_64, the pack embedded, no code signing).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
VER="4.7.2.stable"
case "$(uname -s)" in
  Darwin) TPL="$HOME/Library/Application Support/Godot/export_templates/$VER" ;;
  MINGW*|MSYS*|CYGWIN*) TPL="$APPDATA/Godot/export_templates/$VER" ;;
  *) TPL="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VER" ;;
esac
if [ ! -f "$TPL/windows_release_x86_64.exe" ]; then
  echo "Downloading the Godot 4.7.2 export templates (about 1.3 GB, once)…"
  tmp="$(mktemp -d)"
  curl -fL -o "$tmp/t.tpz" "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
  mkdir -p "$TPL"
  unzip -oq -j "$tmp/t.tpz" 'templates/windows_*x86_64*' 'templates/version.txt' -d "$TPL"
  rm -rf "$tmp"
fi
mkdir -p ../export/palisade
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Windows Desktop" ../export/palisade/Palisade.exe
ls -la ../export/palisade
echo "Done: export/palisade/Palisade.exe (ship the .dll next to it)."
