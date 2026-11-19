#!/usr/bin/env python3
"""From Floor / From Ceiling tests (Python side): python3 -I tests/py_fill_test.py
The two Heights-tab toggles (CELLMAP_V2.md section 3b): a blue block floats (both off, as every
old map), stands on a pillar down to its ground (From Floor), reaches up to the map's top (From
Ceiling), or fills ground to top (both). Writes its map and answers into tests/_fill/ (a scratch
folder, ignored), which tests/lc_fill_test.txt compares with the xTalk library's answers."""
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

# a 5 x 3 floor: col 3 row 2 holds a blue block 90 hu over the floor (slab 91..101),
# col 5 row 2 is a tall block (150): the map's top
m = cm.new_map2(5, 3, name='fill_test')
for r in range(3):
    for c in range(5):
        m['floor'][r][c] = 1
m['blue'][1][2] = 90
m['floor'][1][4] = 150
path = os.path.join(OUT, 'fill_test.cellmap')
cm.write_map(m, path)

old = cm.read_map(path)
check('an old map has no toggles in its file', 'fromFloor' in open(path).read() or 'fromCeiling' in open(path).read(), False)
check('both off (old maps): the block floats, as before', cm.column(old, 1, 2), (1, None, None, 91, 101))
check('both off: walk under it, stand on it', cm.levels(old, 1, 2), [(1, 90), (101, cm.NO_ROOF)])
check('the map top: the tall block', cm.map_top(old), 150)

def toggled(floor, ceiling, **more):
    t = cm.read_map(path)
    if floor:
        t['meta']['fromFloor'] = 1
    if ceiling:
        t['meta']['fromCeiling'] = 1
    t['meta'].update(more)
    return t

f, c, b = toggled(1, 0), toggled(0, 1), toggled(1, 1)
check('From Floor: one solid pillar up to the block top', cm.column(f, 1, 2), (101, None, None, None, None))
check('From Floor: you stand only on top', cm.levels(f, 1, 2), [(101, cm.NO_ROOF)])
check('From Ceiling: the block reaches the map top', cm.column(c, 1, 2), (1, None, None, 91, 150))
check('From Ceiling: still room under it', cm.levels(c, 1, 2), [(1, 90), (150, cm.NO_ROOF)])
check('both: floor to top', cm.column(b, 1, 2), (150, None, None, None, None))
check('a map may name its own top', cm.column(toggled(0, 1, top=200), 1, 2), (1, None, None, 91, 200))
check('cells without blue are not touched', [cm.column(t, 0, 0) for t in (f, c, b)], [(1, None, None, None, None)] * 3)

# saved and loaded
cm.write_map(b, os.path.join(OUT, 'fill_both.cellmap'))
back = cm.read_map(os.path.join(OUT, 'fill_both.cellmap'))
check('saved: both toggles come back', (back['meta'].get('fromFloor'), back['meta'].get('fromCeiling')), (1, 1))
check('saved: the worked-out top is not written', '_top' in open(os.path.join(OUT, 'fill_both.cellmap')).read() or 'top\t' in open(os.path.join(OUT, 'fill_both.cellmap')).read(), False)
check('round trip text', cm.map_text(back), open(os.path.join(OUT, 'fill_both.cellmap'), encoding='utf-8').read())

# walking east along row 2 from col 1: under the floating block, but not through a pillar
tags = cm.tag_lookup()
def walk_east(t):
    x, z, y = cm.cell_x(t, 1), cm.cell_z(t, 2), cm.hu(t)
    for _ in range(40):
        x, z, y, eff = cm.walk(t, tags, None, x, z, y, 4, 0)
    return cm.cell_at(t, x, z)[0]
cols = [walk_east(t) for t in (old, f, c, b)]
check('walk east: under the floating blocks (off, From Ceiling), stopped by pillars', cols, [3, 2, 3, 2])

lines = []
for name, t in (('off', old), ('floor', f), ('ceiling', c), ('both', b)):
    segs = cm.level_segments(t, tags)
    lines.append('== %s %d' % (name, len(segs)))
    lines += segs
    lines.append('walk %s' % walk_east(t))
with open(os.path.join(OUT, '_py_fill_segments.txt'), 'w', encoding='utf-8', newline='\n') as fh:
    fh.write('\n'.join(lines) + '\n')
sky = [s for s in cm.level_segments(c, tags) if s.endswith(',sky')]
check('From Ceiling: the block\'s uprights reach 150', any(',150,' in s for s in sky))
check('From Floor: no sky lines, the pillar is drawn as wall', ([s for s in cm.level_segments(f, tags) if s.endswith(',sky')], any(',101,' in s and s.endswith(',wall') for s in cm.level_segments(f, tags))), ([], True))

print('ALL OK' if ok else 'SOME FAILED')
sys.exit(0 if ok else 1)
