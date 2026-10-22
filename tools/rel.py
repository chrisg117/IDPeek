#!/usr/bin/env python3
# The relationship section of a WDC1 .db2 (7.3.5): the id of the parent row for each record, by record index.
import struct


def parents(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'WDC1'
    (rc, fc, rs, sts, th, lh, mn, mx, loc, cts) = struct.unpack_from('<10I', d, 4)
    (tfc, bpo, lcc, omo, ils, fsis, cds, pds, rds) = struct.unpack_from('<9I', d, 48)
    if not rds:
        return {}
    rel = 84 + fc * 4 + rc * rs + sts + ils + cts + fsis + pds + cds
    n, lo, hi = struct.unpack_from('<3I', d, rel)
    out = {}
    for i in range(n):
        foreign, index = struct.unpack_from('<2I', d, rel + 12 + i * 8)
        out[index] = foreign
    return out


if __name__ == '__main__':
    import os, sys
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'stage1'))
    import wdc1
    for path in sys.argv[1:]:
        t = wdc1.read(path)
        p = parents(path)
        print('==', path, 'records', t['count'], 'with a parent', len(p))
        for i, x in enumerate(t['info']):
            print('   field', i, 'storage', x)
        for index in (0, 1, 2, t['count'] // 2, t['count'] - 1):
            rid, vals = t['records'][index]
            print('  ', rid, vals, 'parent', p.get(index))
