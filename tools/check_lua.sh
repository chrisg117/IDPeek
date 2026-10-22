#!/bin/sh
# Syntax-checks every addon .lua and runs tools/test_lua.lua in a lua5.1 container on the host.
# usage (from the addon folder, on the PC): sh tools/check_lua.sh
set -e
ssh chris@172.30.1.185 'rm -rf /tmp/idpeek/addon && mkdir -p /tmp/idpeek/addon/tools'
scp -q *.lua chris@172.30.1.185:/tmp/idpeek/addon/
scp -q tools/test_lua.lua chris@172.30.1.185:/tmp/idpeek/addon/tools/
ssh chris@172.30.1.185 'docker run --rm -v /tmp/idpeek/addon:/a -w /a idpeek-lua sh -c "for f in *.lua; do luac5.1 -p \$f || exit 1; done; lua5.1 tools/test_lua.lua"'
