#!/bin/sh
# Godot can't play the site's Opus/AAC files, so the music is converted to Ogg Vorbis, cut to each track's exact loop
# length (MUSIC[k].len in dev/src/js/03-audio.js), from the AAC copies in the repo root. Run from the repo root.
set -e
out=godot/music
mkdir -p "$out"
conv() { ffmpeg -loglevel error -y -i "$1.m4a" -t "$2" -c:a libvorbis -q:a 4 "$out/$1.ogg"; }
conv between_raids 160.08408333333333
conv raid_attitude 198.76572916666666
conv raid_cool 181.1853125
conv raid_express 115.51347916666667
conv results 143.61797916666666
