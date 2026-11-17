#!/usr/bin/env python3
"""cellmap v3 tests (Python side): python3 -I tests/py_v3_test.py
Slopes, map packs, stacked maps (CELLMAP_V3.md), on maps/two_rooms. Writes tests/_py_v3_walk.txt,
which tests/lc_v3_test.txt compares with the xTalk library's answers."""
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

maps = os.path.join(HERE, '..', 'maps')
two = os.path.join(maps, 'two_rooms')
tags = cm.tag_lookup()

# old maps: every version 1 and 2 file still reads and writes back the same
old = [os.path.join(d, f) for d, _, fs in os.walk(maps) for f in sorted(fs) if f.endswith('.cellmap')]
same = [p for p in old if cm.map_text(cm.read_map(p)) == open(p, encoding='utf-8').read()]
check('every map in maps/ round trips (%d files)' % len(old), len(same), len(old))
check('a version 2 map stays version 2', cm.version(cm.read_map(os.path.join(two, 'two_rooms_cellar.cellmap'))), 2)

# slopes
loft = cm.read_map(os.path.join(two, 'two_rooms_loft.cellmap'))
check('the loft is version 3 with two sloped cells', (cm.version(loft), sorted(loft['slope'])), (3, [(1, 5), (2, 5)]))
check('slope of 6,2: nw ne se sw', cm.slope(loft, 1, 5), [0, 60, 60, 0])
check('a flat cell has no slope', cm.slope(loft, 1, 4), None)
x0, z0 = cm.cell_x(loft, 6), cm.cell_z(loft, 2)
check('rise: west edge 0, middle 30, east edge 60',
      [round(cm.rise_at(loft, 1, 5, x0 + d, z0), 3) for d in (-38, 0, 38)], [0.0, 30.0, 60.0])
check('60 a cell is not steep', cm.steep(loft, 1, 5), False)
m2 = cm.read_map(os.path.join(two, 'two_rooms_loft.cellmap'))
cm.set_slope(m2, 3, 3, [0, 0, 90, 90])
check('set_slope: 90 a cell is steep', cm.steep(m2, 3, 3), True)
check('set_slope writes a third line', cm.map_text(m2).split('[slope]\n')[1], '6,2\t0 60 60 0\n6,3\t0 60 60 0\n4,4\t0 0 90 90\n')
cm.set_slope(m2, 3, 3, None)
check('flattened again: the same text as the file', cm.map_text(m2) == open(os.path.join(two, 'two_rooms_loft.cellmap'), encoding='utf-8').read())
v2 = cm.read_map(os.path.join(maps, 'wizard_pool.cellmap'))
cm.set_slope(v2, 9, 11, [0, 0, 20, 20])
check('sloping a version 2 map makes it version 3', cm.version(v2), 3)
k = cm.hu(loft)
def go1(m, x, z, y, dx, dz, n):
    e = ''
    for _ in range(n):
        x, z, y, e = cm.walk(m, tags, None, x, z, y, dx, dz)
    return x, z, y, e
x, z, y, e = go1(loft, cm.cell_x(loft, 4), z0, 1 * k, 4, 0, 90)
check('one map: up the ramp onto the dais (61 hu)', (cm.cell_at(loft, x, z), round(y / k, 2)), ((8, 2), 61.0))
x, z, y, e = go1(m2 if cm.set_slope(m2, 3, 3, [0, 0, 90, 90]) else m2, cm.cell_x(m2, 4), cm.cell_z(m2, 3), 1 * k, 0, 4, 40)
check('a steep slope cannot be walked up', cm.cell_at(m2, x, z), (4, 3))
x, z, y, e = go1(m2, cm.cell_x(m2, 4), cm.cell_z(m2, 4) + 30, 200 * k, 0, -4, 3)
check('dropped onto it, it answers slide and lets you down', (e, round(y / k, 1) < 80), ('slide', True))

# the pack
pp = os.path.join(two, 'two_rooms.cellpack')
pack = cm.read_pack(pp)
check('pack text round trip', cm.pack_text(pack) == open(pp, encoding='utf-8').read())
check('pack: two maps in one place, no problems', ([(e['id'], e['place'], e['base']) for e in pack['maps']], pack['problems']),
      ([('cellar', 'main', 0), ('loft', 'main', 120)], []))
check('pack: doors of the ladder cell', [(d['type'], d['to']) for d in cm.pack_doors(pack, 'cellar', 2, 2)], [('ladder', 'loft:2,2')])
place, x, z, y = cm.pack_enter(pack, tags, None, None)
check('enter: the cellar\'s @ at 5,4 on the floor', (place, cm.cell_at(pack['maps'][0]['map'], x, z), round(y / k, 2)), ('main', (5, 4), 1.0))
check('the ladder leads to the loft floor (121 hu)', round(cm.pack_enter(pack, tags, None, 'loft:2,2')[3] / k, 2), 121.0)
check('under the loft the cellar has 119 hu of air: you stand on the cellar floor',
      cm.pack_stand_at(pack, 'main', tags, None, x, z, 1 * k), (1 * k, 'cellar'))
check('from the loft floor you stand on the loft', cm.pack_stand_at(pack, 'main', tags, None, x, z, 121 * k), (121 * k, 'loft'))

bad = os.path.join(HERE, '_bad.cellpack')
open(bad, 'w', newline='\n').write('[pack]\nname\tbad\n[maps]\na\t../wizard_pool.cellmap\nb\tnothing_here.cellmap\n[doors]\na:1,1\tdoor\tzzz:1,1\n')
check('a broken pack lists its problems: a file outside the folder, a missing file, a door to nowhere', len(cm.read_pack(bad)['problems']), 3)
os.remove(bad)

log = []
def go(x, z, y, dx, dz, n, name):
    r = None
    for _ in range(n):
        r = cm.pack_walk(pack, 'main', tags, None, x, z, y, dx, dz)
        x, z, y = r[:3]
    log.append('%s|%.2f|%.2f|%.2f|%s|%s|%d,%d' % ((name,) + (x, z, y / k) + r[3:]))
    return x, z, y, r
x, z, y, r = go(x, z, y, -4, 0, 60, 'west to the wall')
x, z, y, r = go(x, z, y, 0, 4, 60, 'south to the foot of the stairs')
check('at the foot of the stairs, still in the cellar', (r[4], r[5], r[6], round(y / k, 2)), ('cellar', 2, 6, 1.0))
x, z, y, r = go(x, z, y, 4, 0, 50, 'east: half way up the stairs')
check('half way: on a stair, in the hole of the loft', (r[3], r[4], round(y / k, 2) in (60.0, 90.0)), ('climb', 'cellar', True))
x, z, y, r = go(x, z, y, 4, 0, 80, 'east: out of the hole onto the loft')
check('up the stairs onto the loft: map loft, 121 hu', (r[4], r[5], r[6], round(y / k, 2)), ('loft', 8, 6, 121.0))
x, z, y, r = go(x, z, y, 0, -4, 60, 'north: the dais is too high from here')
check('the side of the dais (60 up) stops you', (r[6], round(y / k, 2)), (4, 121.0))
x, z, y, r = go(x, z, y, -4, 0, 70, 'west')
x, z, y, r = go(x, z, y, 0, -4, 60, 'north to row 2')
x, z, y, r = go(x, z, y, 4, 0, 30, 'east: on the ramp')
check('on the ramp: between the floor and the dais', (r[5], r[6], 121 < y / k < 181), (6, 2, True))
x, z, y, r = go(x, z, y, 4, 0, 60, 'east: up to the goal')
check('up the ramp to the goal on the dais: 120 + 61', (r[3], r[4], r[5], r[6], round(y / k, 2)), ('goal', 'loft', 8, 2, 181.0))
x, z, y, r = go(x, z, y, 0, 4, 45, 'south off the dais (a drop of 60)')
check('dropped to the loft floor', (r[6], round(y / k, 2)), (4, 121.0))
x, z, y, r = go(x, z, y, -4, 0, 42, 'west')
x, z, y, r = go(x, z, y, 0, 4, 60, 'south into the stair hole')
check('through the hole: back in the cellar, on the top stair', (r[3], r[4], r[5], r[6], round(y / k, 2)), ('climb', 'cellar', 6, 6, 120.0))
open(os.path.join(HERE, '_py_v3_walk.txt'), 'w', newline='\n').write('\n'.join(log) + '\n')
print('\n'.join(log))
print('ALL OK' if ok else 'SOMETHING FAILED')
sys.exit(0 if ok else 1)
