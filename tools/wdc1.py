#!/usr/bin/env python3
# Minimal WDC1 (.db2, 7.3.5) reader: yields (id, [raw field values]) per record, where a field value is a list
# of unsigned 32-bit integers (one per array element). Handles plain, bitpacked, common and pallet fields.
import struct


def read(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'WDC1', d[:4]
    (rc, fc, rs, sts, th, lh, mn, mx, loc, cts) = struct.unpack_from('<10I', d, 4)
    flags, idi = struct.unpack_from('<2H', d, 44)
    (tfc, bpo, lcc, omo, ils, fsis, cds, pds, rds) = struct.unpack_from('<9I', d, 48)
    off = 84
    fstruct = [struct.unpack_from('<hH', d, off + i * 4) for i in range(fc)]
    rec0 = off + fc * 4
    assert not (flags & 1), 'offset map records are not handled'
    strtab = rec0 + rc * rs
    idlist = strtab + sts
    ids = struct.unpack_from('<%dI' % (ils // 4), d, idlist) if ils else None
    copy = idlist + ils
    fsi = copy + cts
    pallet = fsi + fsis
    common = pallet + pds
    info = [struct.unpack_from('<HHIIIII', d, fsi + i * 24) for i in range(fsis // 24)]

    # where each field's pallet and common data starts
    p_off, c_off = [], []
    p, c = pallet, common
    for (_, _, add, st, _, _, _) in info:
        p_off.append(p); c_off.append(c)
        if st in (3, 4):
            p += add
        elif st == 2:
            c += add
    commons = []
    for i, (_, _, add, st, v1, _, _) in enumerate(info):
        m = {}
        if st == 2:
            for k in range(add // 8):
                rid, val = struct.unpack_from('<II', d, c_off[i] + k * 8)
                m[rid] = val
        commons.append(m)

    def bits(rec, bit_off, size):
        v = int.from_bytes(d[rec + bit_off // 8: rec + (bit_off + size + 7) // 8 + 1], 'little')
        return (v >> (bit_off % 8)) & ((1 << size) - 1)

    out = []
    for r in range(rc):
        rec = rec0 + r * rs
        vals = []
        rid = ids[r] if ids else None
        if rid is None:
            # the id is a field of the record; common data is looked up by it, so it is needed first
            fo, fsz, add, st, v1, v2, v3 = info[idi]
            assert st in (0, 1), 'id field storage %d is not handled' % st
            rid = bits(rec, fo, fsz)
        for i, (fo, fsz, add, st, v1, v2, v3) in enumerate(info):
            if st == 0:
                # plain: element size comes from the field structure (32 - size bits), arrays are contiguous
                esz = 32 - fstruct[i][0] if i < len(fstruct) else 32
                n = max(1, fsz // esz)
                vals.append([bits(rec, fo + k * esz, esz) for k in range(n)])
            elif st == 1:
                vals.append([bits(rec, fo, fsz)])
            elif st == 2:
                vals.append([commons[i].get(rid, v1)])
            elif st == 3:
                idx = bits(rec, fo, fsz)
                vals.append([struct.unpack_from('<I', d, p_off[i] + idx * 4)[0]])
            elif st == 4:
                idx = bits(rec, fo, fsz)
                vals.append(list(struct.unpack_from('<%dI' % v3, d, p_off[i] + idx * 4 * v3)))
            else:
                vals.append([None])
        if rid is None:
            rid = vals[idi][0]
        out.append((rid, vals))

    def string(value):
        # string offsets count from the start of the string table
        o = strtab + value
        e = d.index(b'\0', o)
        return d[o:e].decode('utf8', 'replace')

    return {'records': out, 'info': info, 'fstruct': fstruct, 'flags': flags, 'string': string, 'count': rc}


def f32(u):
    return struct.unpack('<f', struct.pack('<I', u & 0xffffffff))[0]


if __name__ == '__main__':
    import sys
    t = read(sys.argv[1])
    print('records', t['count'], 'flags', hex(t['flags']))
    for i, x in enumerate(t['info']):
        print('field', i, 'struct', t['fstruct'][i] if i < len(t['fstruct']) else None, 'storage', x)
    for rid, vals in t['records'][:3]:
        print(rid, vals)
