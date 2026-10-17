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
conv main_menu 458.352
conv final_blitz 389.4266666666667
# the casino playlist: whole tracks, each crossfades into the next
conv casino_1 391.44
conv casino_2 84.0
conv casino_3 209.256
conv casino_4 233.832
conv casino_5 392.016
conv casino_6 336.6
conv casino_7 120.96
conv casino_8 192.0
conv casino_9 301.176
conv casino_10 321.48
conv casino_11 221.832
