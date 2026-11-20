#!/usr/bin/env python3
"""From Floor / From Ceiling tests (Python side): python3 -I tests/py_fill_test.py
Colour bands and the two per-cell toggles (CELLMAP_V2.md section 3b): white 0-255, green blocks
float at 255 + green, blue blocks at 510 + blue (the value is the block's top). A cell's block
floats (both off, as every old map), stands on a pillar from the ground (From Floor), hangs from
the map's top (From Ceiling, down to its roof when it has one), or fills ground to top (both).
Writes its maps and answers into tests/_fill/ (a scratch folder, ignored), which
tests/lc_fill_test.txt compares with the xTalk library's answers."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'python'))
import cellmap as cm

ok = True
def check(name, got, want=True):
    global ok
    good = got == want
    ok = ok and good
    print(('ok   ' if good else 'FAIL ') + name + ('' if good else '   got %r want %r' % (got, want)))

OUT = os.path.join(HERE, '_fill')
os.makedirs(OUT, exist_ok=True)
N = None
T = cm.NO_ROOF

# a 6 x 3 floor; row 2: col 3 a blue block (blue 10: 500..520), col 4 green 10 under blue 10
# (245..265 and 500..520), col 5 a roof at 100 and green 10 over it, col 6 a tall block (150)
m = cm.new_map2(6, 3, name='fill_test')
for r in range(3):
    for c in range(6):
        m['floor'][r][c] = 1
m['blue'][1][2] = 10
m['green'][1][3] = 10
m['blue'][1][3] = 10
m['ceiling'][1][4] = 100
m['green'][1][4] = 10
m['floor'][1][5] = 150
path = os.path.join(OUT, 'fill_off.cellmap')
cm.write_map(m, path)

old = cm.read_map(path)
check('an old map has no [from] in its file', '[from]' in open(path).read(), False)
check('the default top: the top of the blue band', (cm.map_top(old), cm.TOP), (765, 765))
check('off: blue 10 floats at 500..520', cm.column(old, 1, 2), (1, N, N, 510, 520, N, N))
check('off: walk under it, stand on it', cm.levels(old, 1, 2), [(1, 509), (520, T)])
check('off: green and blue float one above the other', cm.column(old, 1, 3), (1, N, N, 255, 265, 510, 520))
check('off: three levels in that cell', cm.levels(old, 1, 3), [(1, 254), (265, 245), (520, T)])
check('off: a roof with a green block over it', cm.levels(old, 1, 4), [(1, 99), (100, 155), (265, T)])

def flagged(flags, name, **more):
    t = cm.read_map(path)
    for c in range(6):
        t['from'][1][c] = flags[c]
    t['meta'].update(more)
    t['meta']['name'] = name
    cm.write_map(t, os.path.join(OUT, name + '.cellmap'))
    return cm.read_map(os.path.join(OUT, name + '.cellmap'))

f = flagged([1] * 6, 'fill_floor')
c = flagged([2] * 6, 'fill_ceiling')
b = flagged([3] * 6, 'fill_both')
mix = flagged([0, 1, 1, 2, 0, 0], 'fill_mixed')
own = flagged([2] * 6, 'fill_top600', top=600)

check('From Floor: one solid pillar up to the block top', cm.column(f, 1, 2), (520, N, N, N, N, N, N))
check('From Floor: up to the highest block', cm.column(f, 1, 3), (520, N, N, N, N, N, N))
check('From Floor: the room under the roof is filled too', cm.column(f, 1, 4), (265, N, N, N, N, N, N))
check('From Floor: you stand only on top', cm.levels(f, 1, 2), [(520, T)])
check('From Ceiling: the block hangs from the map top', cm.column(c, 1, 2), (1, N, N, 510, 765, N, N))
check('From Ceiling: down to the lowest block', cm.column(c, 1, 3), (1, N, N, 255, 765, N, N))
check('From Ceiling: down to the roof when there is one', cm.column(c, 1, 4), (1, 100, 765, N, N, N, N))
check('From Ceiling: still room under it (its top is the map top)', cm.levels(c, 1, 2), [(1, 509), (765, T)])
check('both: floor to top', [cm.column(b, 1, k)[0] for k in (2, 3, 4)], [765, 765, 765])
check('a map may name its own top', cm.column(own, 1, 2), (1, N, N, 510, 600, N, N))
check('cells without blocks or roofs are not touched', [cm.column(t, 0, 0) for t in (f, c, b)], [(1, N, N, N, N, N, N)] * 3)
check('cell by cell: one map, three kinds', [cm.column(mix, 1, k) for k in (2, 3, 4)],
      [(520, N, N, N, N, N, N), (1, N, N, 255, 765, N, N), (1, 100, 100, 255, 265, N, N)])

# saved and loaded
txt = open(os.path.join(OUT, 'fill_mixed.cellmap'), encoding='utf-8').read()
check('saved: the [from] layer is written', '[from]' in txt and '  0   1   1   2   0   0' in txt)
check('saved: no whole-map toggles, no top unless named', ('fromFloor' in txt, 'top\t' in txt), (False, False))
check('round trip text', cm.map_text(mix), txt)

# walking east along row 2 from col 1: under floating blocks and roofs, not through pillars
tags = cm.tag_lookup()
def walk_east(t):
    x, z, y = cm.cell_x(t, 1), cm.cell_z(t, 2), cm.hu(t)
    for _ in range(100):
        x, z, y, eff = cm.walk(t, tags, None, x, z, y, 4, 0)
    return cm.cell_at(t, x, z)[0]
maps = (('off', old), ('floor', f), ('ceiling', c), ('both', b), ('mixed', mix), ('top600', own))
check('walk east: under blocks, stopped by pillars and the tall block', [walk_east(t) for _, t in maps], [5, 2, 5, 2, 2, 5])

lines = []
for name, t in maps:
    segs = cm.level_segments(t, tags)
    lines.append('== %s %d' % (name, len(segs)))
    lines += segs
    lines.append('walk %s' % walk_east(t))
with open(os.path.join(OUT, '_py_fill_segments.txt'), 'w', encoding='utf-8', newline='\n') as fh:
    fh.write('\n'.join(lines) + '\n')
sky = [s for s in cm.level_segments(c, tags) if s.endswith(',sky')]
check('From Ceiling: the block\'s uprights reach 765', any(',765,' in s for s in sky))
segs_f = cm.level_segments(f, tags)
check('From Floor: no sky lines; a blue pillar is wall, a green one green',
      ([s for s in segs_f if s.endswith(',sky')], any(',520,' in s and s.endswith(',wall') for s in segs_f),
       any(',520,' in s and s.endswith(',green') for s in segs_f)), ([], True, True))

print('ALL OK' if ok else 'SOME FAILED')
sys.exit(0 if ok else 1)
