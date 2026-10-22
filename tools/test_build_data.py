#!/usr/bin/env python3
# Checks build_data.py against chains already known from the priest work.
# usage: test_build_data.py <dbc dir>
import os, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_data

dbc = sys.argv[1]

we = build_data.load_worldeffects(dbc)
assert we[735] == (200316, 19), we.get(735)    # QFE 42, world/generic/pvp/warsong/nightelfctfflagplaceglow.m2
assert we[3079][0] == 199907, we.get(3079)     # QFE 162, .../particleemitters/aurablueshort.m2
assert all(fdid for fdid, _ in we.values())    # effects without a model are left out

sp = build_data.load_spells(dbc)
assert sp[205128] == [[53761, 65054]], sp.get(205128)   # vfx.py 205128: visual 53761, event kit (field 7) 65054
assert all(len(v) >= 2 for vs in sp.values() for v in vs)

out = tempfile.mkdtemp()
build_data.write_lua(sp, we, out)
text = open(os.path.join(out, "Data.lua")).read()
assert "[735]={200316,19}" in text
assert "s[205128]={{53761,65054}}" in text
toc = open(os.path.join(out, "IDPeek_Data.toc")).read()
assert "## LoadOnDemand: 1" in toc and "Data.lua" in toc
print("OK")
