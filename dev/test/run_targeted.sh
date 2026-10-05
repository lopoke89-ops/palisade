#!/bin/bash
# Run only the tests for one area (the groups are tags in suite.txt). ./run_targeted.sh hud, or several: hud tables
[ -z "$1" ] && { echo "Usage: ./run_targeted.sh <area> [area...]   areas: $(grep -v '^#' "$(dirname "$0")/suite.txt" | awk '{for(i=2;i<=NF;i++)print $i}' | grep -vxE 'node|serial|extra' | sort -u | tr '\n' ' ')" >&2; exit 2; }
[ "$1" = all ] && exec "$(dirname "$0")/run_all.sh"
exec "$(dirname "$0")/run_all.sh" $(printf '@%s ' "$@")
