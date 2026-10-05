#!/bin/bash
# Runs the PALISADE test suite (the list and tags are in suite.txt; the runner is run_suite.js).
#   1. npm install                  (once; installs Playwright, the PeerJS server, terser and PGlite)
#   2. ./run_all.sh --build         (builds the site, then runs every test in parallel)
# Pass tags or names to narrow it (./run_all.sh @hud nameplates), --failed to re-run last run's failures,
# --changed for tests whose file changed, --list to see the selection. TESTS="a b" ./run_all.sh still works.
# The accounts, rewards and Tables tests fake Supabase, so no internet is needed. CHROMIUM=/path picks a browser.
cd "$(dirname "$0")" && exec node run_suite.js "$@"
